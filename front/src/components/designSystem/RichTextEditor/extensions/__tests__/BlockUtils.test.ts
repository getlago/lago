import { Editor } from '@tiptap/core'
import { NodeSelection } from '@tiptap/pm/state'
import StarterKit from '@tiptap/starter-kit'

import { BlockColors } from '../BlockColors'
import { resolveTopLevelBlock } from '../BlockUtils'

const createEditor = (content = '<p>First</p><p>Second</p>') =>
  new Editor({
    extensions: [StarterKit, BlockColors],
    content,
  })

describe('resolveTopLevelBlock', () => {
  describe('GIVEN a text cursor selection', () => {
    describe('WHEN the cursor is inside a top-level block', () => {
      it('THEN should return the top-level block pos and node', () => {
        const editor = createEditor('<p>Hello</p>')

        editor.commands.setTextSelection(1)

        const result = resolveTopLevelBlock(editor.state)

        editor.destroy()

        expect(result).not.toBeNull()
        expect(result?.node.type.name).toBe('paragraph')
        expect(result?.pos).toBe(0)
      })
    })

    describe('WHEN the cursor is inside a nested block', () => {
      it('THEN should return the top-level ancestor block', () => {
        const editor = createEditor('<ul><li>Item</li></ul>')

        editor.commands.setTextSelection(3)

        const result = resolveTopLevelBlock(editor.state)

        editor.destroy()

        expect(result).not.toBeNull()
        expect(result?.node.type.name).toBe('bulletList')
      })
    })
  })

  describe('GIVEN a NodeSelection', () => {
    describe('WHEN a block node is selected', () => {
      it('THEN should return the selected node pos and node', () => {
        const editor = createEditor('<p>First</p><p>Second</p>')

        const tr = editor.state.tr.setSelection(NodeSelection.create(editor.state.doc, 0))

        editor.view.dispatch(tr)

        const result = resolveTopLevelBlock(editor.state)

        editor.destroy()

        expect(result).not.toBeNull()
        expect(result?.node.type.name).toBe('paragraph')
        expect(result?.node.textContent).toBe('First')
        expect(result?.pos).toBe(0)
      })
    })
  })

  describe('GIVEN an empty document', () => {
    describe('WHEN the cursor is in the empty paragraph', () => {
      it('THEN should return the empty paragraph block', () => {
        const editor = createEditor('')

        editor.commands.setTextSelection(1)

        const result = resolveTopLevelBlock(editor.state)

        editor.destroy()

        expect(result).not.toBeNull()
        expect(result?.node.type.name).toBe('paragraph')
      })
    })
  })
})
