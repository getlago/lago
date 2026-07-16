import type { Editor } from '@tiptap/core'
import { TextSelection } from '@tiptap/pm/state'
import { CellSelection } from '@tiptap/pm/tables'

const resolveCellPos = (editor: Editor, contentPos: number) => {
  // cellPos from posAtDOM points inside the cell content.
  // Walk up to find the cell node position for CellSelection.
  const $pos = editor.state.doc.resolve(contentPos)

  for (let depth = $pos.depth; depth > 0; depth--) {
    const node = $pos.node(depth)

    if (node.type.name === 'tableCell' || node.type.name === 'tableHeader') {
      return editor.state.doc.resolve($pos.before(depth))
    }
  }

  return $pos
}

export const selectRow = (editor: Editor, cellPos: number) => {
  const $cell = resolveCellPos(editor, cellPos)
  const selection = CellSelection.rowSelection($cell)
  const tr = editor.state.tr.setSelection(selection)

  editor.view.dispatch(tr)
  editor.view.focus()
}

export const selectColumn = (editor: Editor, cellPos: number) => {
  const $cell = resolveCellPos(editor, cellPos)
  const selection = CellSelection.colSelection($cell)
  const tr = editor.state.tr.setSelection(selection)

  editor.view.dispatch(tr)
  editor.view.focus()
}

export const focusCellAndRun = (
  editor: Editor,
  cellPos: number,
  command: (chain: ReturnType<Editor['chain']>) => void,
) => {
  // cellPos may point at the cell node boundary (not inside inline content).
  // Resolve to the nearest valid text position inside the cell.
  const $pos = editor.state.doc.resolve(cellPos)
  const validPos = TextSelection.near($pos).from

  // Batch focus + selection + command into a single transaction to avoid
  // "mismatched transaction" errors.
  const chain = editor.chain().focus().setTextSelection(validPos)

  command(chain)
  chain.run()
}
