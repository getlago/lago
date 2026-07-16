import { Extension } from '@tiptap/core'
import { NodeSelection, TextSelection } from '@tiptap/pm/state'

import { resolveTopLevelBlock } from './BlockUtils'
import { getDragHandleStorage } from './DragHandle'

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    blockMove: {
      moveBlockUp: () => ReturnType
      moveBlockDown: () => ReturnType
    }
  }
}

export const BlockMove = Extension.create({
  name: 'blockMove',

  addCommands() {
    return {
      moveBlockUp:
        () =>
        ({ state, dispatch, editor }) => {
          const block = resolveTopLevelBlock(state)

          if (!block) return false

          const { pos, node } = block
          const $pos = state.doc.resolve(pos)
          const index = $pos.index(0)

          if (index === 0) return false

          const prevNode = state.doc.child(index - 1)
          const prevPos = pos - prevNode.nodeSize

          if (dispatch) {
            const tr = state.tr.replaceWith(prevPos, pos + node.nodeSize, [
              node.copy(node.content),
              prevNode.copy(prevNode.content),
            ])

            // For tables, avoid NodeSelection (prosemirror-tables converts it to
            // CellSelection). Use TextSelection inside the table + storage instead.
            if (node.type.name === 'table') {
              const $inside = tr.doc.resolve(prevPos + 1)

              tr.setSelection(TextSelection.near($inside))
              getDragHandleStorage(editor).selectedBlock = { pos: prevPos }
            } else {
              tr.setSelection(NodeSelection.create(tr.doc, prevPos))
            }

            dispatch(tr)
          }

          return true
        },

      moveBlockDown:
        () =>
        ({ state, dispatch, editor }) => {
          const block = resolveTopLevelBlock(state)

          if (!block) return false

          const { pos, node } = block
          const $pos = state.doc.resolve(pos)
          const index = $pos.index(0)

          if (index >= state.doc.childCount - 1) return false

          const nextNode = state.doc.child(index + 1)
          const nextPos = pos + node.nodeSize

          if (dispatch) {
            const tr = state.tr.replaceWith(pos, nextPos + nextNode.nodeSize, [
              nextNode.copy(nextNode.content),
              node.copy(node.content),
            ])

            const newPos = pos + nextNode.nodeSize

            // For tables, avoid NodeSelection (prosemirror-tables converts it to
            // CellSelection). Use TextSelection inside the table + storage instead.
            if (node.type.name === 'table') {
              const $inside = tr.doc.resolve(newPos + 1)

              tr.setSelection(TextSelection.near($inside))
              getDragHandleStorage(editor).selectedBlock = { pos: newPos }
            } else {
              tr.setSelection(NodeSelection.create(tr.doc, newPos))
            }

            dispatch(tr)
          }

          return true
        },
    }
  },
})
