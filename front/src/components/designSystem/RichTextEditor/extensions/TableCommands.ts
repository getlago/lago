import { Extension } from '@tiptap/core'
import type { Node as PmNode, ResolvedPos } from '@tiptap/pm/model'
import {
  type EditorState,
  Plugin,
  PluginKey,
  TextSelection,
  type Transaction,
} from '@tiptap/pm/state'
import { CellSelection, TableView } from '@tiptap/pm/tables'
import { Decoration, DecorationSet } from '@tiptap/pm/view'

import { getDragHandleStorage } from './DragHandle'

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    tableCommands: {
      moveRowUp: () => ReturnType
      moveRowDown: () => ReturnType
      moveColumnLeft: () => ReturnType
      moveColumnRight: () => ReturnType
      setRowBackgroundColor: (color: string | null) => ReturnType
      setRowTextColor: (color: string | null) => ReturnType
      setColumnBackgroundColor: (color: string | null) => ReturnType
      setColumnTextColor: (color: string | null) => ReturnType
    }
  }
}

// -- Color-aware TableView ----------------------------------------------------

/**
 * Extends the default TableView to apply backgroundColor/textColor from the
 * table node's attributes onto the `<table>` DOM element.
 */
class ColorAwareTableView extends TableView {
  update(node: PmNode) {
    const result = super.update(node)

    if (!result) return false

    const bg = node.attrs.backgroundColor as string | null
    const tc = node.attrs.textColor as string | null

    this.table.style.backgroundColor = bg ?? ''
    this.table.style.color = tc ?? ''

    return true
  }
}

// -- Helpers ------------------------------------------------------------------

/**
 * Resolves the table, row index, and column index from the current selection.
 * Returns null if the selection is not inside a table.
 */
const resolveRowAndCol = (
  $pos: ResolvedPos,
  tableDepth: number,
): { rowIndex: number; colIndex: number; rowPos: number } | null => {
  let rowIndex = -1
  let colIndex = -1
  let rowPos = -1

  for (let d = tableDepth + 1; d <= $pos.depth; d++) {
    const ancestor = $pos.node(d)

    if (ancestor.type.name === 'tableRow') {
      rowIndex = $pos.index(tableDepth)
      rowPos = $pos.before(d)
    }
    if (ancestor.type.name === 'tableCell' || ancestor.type.name === 'tableHeader') {
      colIndex = $pos.index(d - 1)
    }
  }

  if (rowIndex >= 0 && colIndex >= 0) {
    return { rowIndex, colIndex, rowPos }
  }

  return null
}

const resolveTableContext = (
  state: EditorState,
): {
  tablePos: number
  tableNode: PmNode
  rowIndex: number
  colIndex: number
  rowPos: number
} | null => {
  const $pos = state.selection.$from

  for (let depth = $pos.depth; depth > 0; depth--) {
    const node = $pos.node(depth)

    if (node.type.name === 'table') {
      const result = resolveRowAndCol($pos, depth)

      if (!result) return null

      return { tablePos: $pos.before(depth), tableNode: node, ...result }
    }
  }

  return null
}

const swapRows = (tableNode: PmNode, indexA: number, indexB: number): PmNode => {
  const rows: PmNode[] = []

  tableNode.forEach((row) => rows.push(row))

  const temp = rows[indexA]

  rows[indexA] = rows[indexB]
  rows[indexB] = temp

  return tableNode.type.create(tableNode.attrs, rows)
}

const swapColumns = (tableNode: PmNode, indexA: number, indexB: number): PmNode => {
  const newRows: PmNode[] = []

  tableNode.forEach((row) => {
    const cells: PmNode[] = []

    row.forEach((cell) => cells.push(cell))

    const temp = cells[indexA]

    cells[indexA] = cells[indexB]
    cells[indexB] = temp

    newRows.push(row.type.create(row.attrs, cells))
  })

  return tableNode.type.create(tableNode.attrs, newRows)
}

/**
 * After replacing a table, resolve a TextSelection into the cell at the given
 * row/column so the cursor follows the moved row or column.
 */
const selectCellAfterSwap = (
  tr: Transaction,
  tablePos: number,
  rowIndex: number,
  colIndex: number,
): Transaction => {
  const newTable = tr.doc.nodeAt(tablePos)

  if (!newTable) return tr

  let targetPos = tablePos + 1 // skip into the table

  for (let r = 0; r < newTable.childCount; r++) {
    const row = newTable.child(r)

    if (r === rowIndex) {
      let cellOffset = 0

      for (let c = 0; c < row.childCount; c++) {
        if (c === colIndex) {
          // +1 to enter the cell content
          const cellContentPos = targetPos + cellOffset + 1
          const $pos = tr.doc.resolve(cellContentPos)

          return tr.setSelection(TextSelection.near($pos))
        }
        cellOffset += row.child(c).nodeSize
      }
    }
    targetPos += row.nodeSize
  }

  return tr
}

/**
 * Set an attribute on every cell in a given row.
 * Operates on the ProseMirror document positions so it works for both
 * tableCell and tableHeader nodes.
 */
const setCellAttrInRow = (
  tr: Transaction,
  tablePos: number,
  tableNode: PmNode,
  rowIndex: number,
  attrName: string,
  value: unknown,
): Transaction => {
  const row = tableNode.child(rowIndex)

  // Calculate the absolute position of the row's first child
  let rowStart = tablePos + 1 // +1 for table opening

  for (let i = 0; i < rowIndex; i++) {
    rowStart += tableNode.child(i).nodeSize
  }

  rowStart += 1 // +1 for tableRow opening

  let cellOffset = 0

  for (let c = 0; c < row.childCount; c++) {
    const cell = row.child(c)
    const cellPos = rowStart + cellOffset
    const attrs = { ...cell.attrs, [attrName]: value }

    tr = tr.setNodeMarkup(cellPos, undefined, attrs)
    cellOffset += cell.nodeSize
  }

  return tr
}

/**
 * Set an attribute on every cell in a given column.
 */
const setCellAttrInColumn = (
  tr: Transaction,
  tablePos: number,
  tableNode: PmNode,
  colIndex: number,
  attrName: string,
  value: unknown,
): Transaction => {
  let rowStart = tablePos + 1 // +1 for table opening

  for (let r = 0; r < tableNode.childCount; r++) {
    const row = tableNode.child(r)

    if (colIndex < row.childCount) {
      let cellOffset = 1 // +1 for tableRow opening

      for (let c = 0; c < colIndex; c++) {
        cellOffset += row.child(c).nodeSize
      }

      const cell = row.child(colIndex)
      const cellPos = rowStart + cellOffset
      const attrs = { ...cell.attrs, [attrName]: value }

      tr = tr.setNodeMarkup(cellPos, undefined, attrs)
    }

    rowStart += row.nodeSize
  }

  return tr
}

// -- Extension ----------------------------------------------------------------

const focusedCellPluginKey = new PluginKey('focusedCell')

/**
 * Builds decorations for:
 * - focusedCell: the cell containing the cursor
 * - colSelected / colSelected--first / colSelected--last: column selection borders
 */
function buildCellDecorations(state: EditorState, isTableBlockSelected: boolean): DecorationSet {
  const { selection } = state
  const decorations: Decoration[] = []

  // Column selection: add positional classes so CSS can merge vertical borders
  if (selection instanceof CellSelection && selection.isColSelection()) {
    const cells: { pos: number; size: number }[] = []

    selection.forEachCell((node, pos) => {
      cells.push({ pos, size: node.nodeSize })
    })

    cells.forEach((cell, i) => {
      const classes = ['colSelected']

      if (i === 0) classes.push('colSelected--first')
      if (i === cells.length - 1) classes.push('colSelected--last')

      decorations.push(
        Decoration.node(cell.pos, cell.pos + cell.size, { class: classes.join(' ') }),
      )
    })

    return DecorationSet.create(state.doc, decorations)
  }

  // Skip focused cell when any CellSelection is active or table is block-selected
  if (selection instanceof CellSelection || isTableBlockSelected) {
    return DecorationSet.empty
  }

  // Focused cell: cursor inside a cell (not a CellSelection)
  const $pos = selection.$from

  for (let depth = $pos.depth; depth > 0; depth--) {
    const node = $pos.node(depth)

    if (node.type.name === 'tableCell' || node.type.name === 'tableHeader') {
      const pos = $pos.before(depth)

      decorations.push(Decoration.node(pos, pos + node.nodeSize, { class: 'focusedCell' }))
      break
    }
  }

  return decorations.length > 0 ? DecorationSet.create(state.doc, decorations) : DecorationSet.empty
}

export const TableCommands = Extension.create({
  name: 'tableCommands',

  addProseMirrorPlugins() {
    const editorRef = this.editor

    return [
      new Plugin({
        key: focusedCellPluginKey,
        state: {
          init(_, state) {
            return buildCellDecorations(state, false)
          },
          apply(tr, oldSet, _oldState, newState) {
            if (tr.selectionSet || tr.docChanged) {
              const isBlockSelected = !!getDragHandleStorage(editorRef).selectedBlock

              return buildCellDecorations(newState, isBlockSelected)
            }

            return oldSet
          },
        },
        props: {
          decorations(state) {
            return focusedCellPluginKey.getState(state)
          },
        },
      }),
    ]
  },

  addGlobalAttributes() {
    return [
      {
        types: ['tableCell', 'tableHeader'],
        attributes: {
          backgroundColor: {
            default: null,
            parseHTML: (element) => element.style.backgroundColor || null,
            renderHTML: (attributes) => {
              if (!attributes.backgroundColor && !attributes.textColor) return {}

              const parts: string[] = []

              if (attributes.backgroundColor) {
                parts.push(`background-color: ${attributes.backgroundColor}`)
              }

              if (attributes.textColor) {
                parts.push(`color: ${attributes.textColor}`)
              }

              return parts.length > 0 ? { style: `${parts.join('; ')};` } : {}
            },
          },
          textColor: {
            default: null,
            parseHTML: (element) => element.style.color || null,
            renderHTML: () => ({}),
          },
        },
      },
    ]
  },

  addCommands() {
    return {
      moveRowUp:
        () =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx || ctx.rowIndex === 0) return false

          if (dispatch) {
            const newTable = swapRows(ctx.tableNode, ctx.rowIndex, ctx.rowIndex - 1)
            let tr = state.tr.replaceWith(
              ctx.tablePos,
              ctx.tablePos + ctx.tableNode.nodeSize,
              newTable,
            )

            tr = selectCellAfterSwap(tr, ctx.tablePos, ctx.rowIndex - 1, ctx.colIndex)
            dispatch(tr)
          }

          return true
        },

      moveRowDown:
        () =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx || ctx.rowIndex >= ctx.tableNode.childCount - 1) return false

          if (dispatch) {
            const newTable = swapRows(ctx.tableNode, ctx.rowIndex, ctx.rowIndex + 1)
            let tr = state.tr.replaceWith(
              ctx.tablePos,
              ctx.tablePos + ctx.tableNode.nodeSize,
              newTable,
            )

            tr = selectCellAfterSwap(tr, ctx.tablePos, ctx.rowIndex + 1, ctx.colIndex)
            dispatch(tr)
          }

          return true
        },

      moveColumnLeft:
        () =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx || ctx.colIndex === 0) return false

          if (dispatch) {
            const newTable = swapColumns(ctx.tableNode, ctx.colIndex, ctx.colIndex - 1)
            let tr = state.tr.replaceWith(
              ctx.tablePos,
              ctx.tablePos + ctx.tableNode.nodeSize,
              newTable,
            )

            tr = selectCellAfterSwap(tr, ctx.tablePos, ctx.rowIndex, ctx.colIndex - 1)
            dispatch(tr)
          }

          return true
        },

      moveColumnRight:
        () =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx) return false

          const firstRow = ctx.tableNode.firstChild

          if (!firstRow || ctx.colIndex >= firstRow.childCount - 1) return false

          if (dispatch) {
            const newTable = swapColumns(ctx.tableNode, ctx.colIndex, ctx.colIndex + 1)
            let tr = state.tr.replaceWith(
              ctx.tablePos,
              ctx.tablePos + ctx.tableNode.nodeSize,
              newTable,
            )

            tr = selectCellAfterSwap(tr, ctx.tablePos, ctx.rowIndex, ctx.colIndex + 1)
            dispatch(tr)
          }

          return true
        },

      setRowBackgroundColor:
        (color) =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx) return false

          if (dispatch) {
            const tr = setCellAttrInRow(
              state.tr,
              ctx.tablePos,
              ctx.tableNode,
              ctx.rowIndex,
              'backgroundColor',
              color,
            )

            dispatch(tr)
          }

          return true
        },

      setRowTextColor:
        (color) =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx) return false

          if (dispatch) {
            const tr = setCellAttrInRow(
              state.tr,
              ctx.tablePos,
              ctx.tableNode,
              ctx.rowIndex,
              'textColor',
              color,
            )

            dispatch(tr)
          }

          return true
        },

      setColumnBackgroundColor:
        (color) =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx) return false

          if (dispatch) {
            const tr = setCellAttrInColumn(
              state.tr,
              ctx.tablePos,
              ctx.tableNode,
              ctx.colIndex,
              'backgroundColor',
              color,
            )

            dispatch(tr)
          }

          return true
        },

      setColumnTextColor:
        (color) =>
        ({ state, dispatch }) => {
          const ctx = resolveTableContext(state)

          if (!ctx) return false

          if (dispatch) {
            const tr = setCellAttrInColumn(
              state.tr,
              ctx.tablePos,
              ctx.tableNode,
              ctx.colIndex,
              'textColor',
              color,
            )

            dispatch(tr)
          }

          return true
        },
    }
  },
})

export { ColorAwareTableView }
