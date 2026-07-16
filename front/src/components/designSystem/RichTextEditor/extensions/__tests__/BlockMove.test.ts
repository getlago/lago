import { Editor } from '@tiptap/core'
import { NodeSelection } from '@tiptap/pm/state'
import StarterKit from '@tiptap/starter-kit'

import { BlockColors } from '../BlockColors'
import { BlockMove } from '../BlockMove'

const createEditor = (content = '<p>First</p><p>Second</p><p>Third</p>') =>
  new Editor({
    extensions: [StarterKit, BlockColors, BlockMove],
    content,
  })

const selectBlock = (editor: Editor, blockIndex: number) => {
  let pos = 0

  for (let i = 0; i < blockIndex; i++) {
    pos += editor.state.doc.child(i).nodeSize
  }

  const tr = editor.state.tr.setSelection(NodeSelection.create(editor.state.doc, pos))

  editor.view.dispatch(tr)
}

describe('BlockMove', () => {
  describe('GIVEN the BlockMove extension', () => {
    it('THEN should have the correct name', () => {
      expect(BlockMove.name).toBe('blockMove')
    })
  })

  describe('GIVEN the moveBlockUp command', () => {
    describe('WHEN the selected block is not the first block', () => {
      it('THEN should swap the block with the one above', () => {
        const editor = createEditor()

        selectBlock(editor, 1)
        editor.commands.moveBlockUp()

        const firstText = editor.state.doc.child(0).textContent
        const secondText = editor.state.doc.child(1).textContent

        editor.destroy()

        expect(firstText).toBe('Second')
        expect(secondText).toBe('First')
      })

      it('THEN should select the moved block at its new position', () => {
        const editor = createEditor()

        selectBlock(editor, 1)
        editor.commands.moveBlockUp()

        const { selection } = editor.state
        const selectedNode = editor.state.doc.nodeAt(selection.from)

        editor.destroy()

        expect(selectedNode?.textContent).toBe('Second')
      })
    })

    describe('WHEN the selected block is the first block', () => {
      it('THEN should return false and not change the document', () => {
        const editor = createEditor()

        selectBlock(editor, 0)
        const result = editor.commands.moveBlockUp()

        const firstText = editor.state.doc.child(0).textContent

        editor.destroy()

        expect(result).toBe(false)
        expect(firstText).toBe('First')
      })
    })

    describe('WHEN there is no block selection', () => {
      it('THEN should still resolve the top-level block from cursor position', () => {
        const editor = createEditor()

        // Place text cursor inside the second paragraph
        const firstNodeSize = editor.state.doc.child(0).nodeSize

        editor.commands.setTextSelection(firstNodeSize + 1)
        editor.commands.moveBlockUp()

        const firstText = editor.state.doc.child(0).textContent

        editor.destroy()

        expect(firstText).toBe('Second')
      })
    })
  })

  describe('GIVEN the moveBlockDown command', () => {
    describe('WHEN the selected block is not the last block', () => {
      it('THEN should swap the block with the one below', () => {
        const editor = createEditor()

        selectBlock(editor, 0)
        editor.commands.moveBlockDown()

        const firstText = editor.state.doc.child(0).textContent
        const secondText = editor.state.doc.child(1).textContent

        editor.destroy()

        expect(firstText).toBe('Second')
        expect(secondText).toBe('First')
      })

      it('THEN should select the moved block at its new position', () => {
        const editor = createEditor()

        selectBlock(editor, 0)
        editor.commands.moveBlockDown()

        const { selection } = editor.state
        const selectedNode = editor.state.doc.nodeAt(selection.from)

        editor.destroy()

        expect(selectedNode?.textContent).toBe('First')
      })
    })

    describe('WHEN the selected block is the last block', () => {
      it('THEN should return false and not change the document', () => {
        const editor = createEditor()

        selectBlock(editor, 2)
        const result = editor.commands.moveBlockDown()

        const lastText = editor.state.doc.child(2).textContent

        editor.destroy()

        expect(result).toBe(false)
        expect(lastText).toBe('Third')
      })
    })

    describe('WHEN moving a block multiple times', () => {
      it('THEN should correctly move the block to the end', () => {
        const editor = createEditor()

        selectBlock(editor, 0)
        editor.commands.moveBlockDown()
        editor.commands.moveBlockDown()

        const lastText = editor.state.doc.child(2).textContent

        editor.destroy()

        expect(lastText).toBe('First')
      })
    })
  })
})
