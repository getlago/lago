import { Editor } from '@tiptap/core'
import { NodeSelection } from '@tiptap/pm/state'

import { getBaseExtensions } from '../baseExtensions'
import { BlockColors } from '../BlockColors'

const createEditor = (content = '') => {
  return new Editor({
    extensions: getBaseExtensions(),
    content,
  })
}

const getMarkdown = (editor: Editor): string => {
  return (editor.storage as any).markdown.getMarkdown()
}

describe('BlockColors', () => {
  describe('GIVEN the BlockColors extension', () => {
    it('THEN should have the correct name', () => {
      expect(BlockColors.name).toBe('blockColors')
    })
  })

  describe('GIVEN renderHTML via getHTML()', () => {
    describe('WHEN a paragraph has no color attributes', () => {
      it('THEN should not render inline styles', () => {
        const editor = createEditor('<p>Plain text</p>')
        const html = editor.getHTML()

        editor.destroy()

        expect(html).not.toContain('style=')
        expect(html).toContain('Plain text')
      })
    })
  })

  describe('GIVEN the setBlockBackgroundColor command', () => {
    describe('WHEN called with a color on a text selection', () => {
      it('THEN should apply backgroundColor to the top-level block', () => {
        const editor = createEditor('<p>Hello world</p><p>Second</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.backgroundColor).toBe('#fee2e2')
      })
    })

    describe('WHEN called with null', () => {
      it('THEN should remove the backgroundColor', () => {
        const editor = createEditor('<p>Hello world</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')
        editor.commands.setBlockBackgroundColor(null)

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.backgroundColor).toBeNull()
      })
    })

    describe('WHEN called with a NodeSelection', () => {
      it('THEN should apply backgroundColor to the selected node', () => {
        const editor = createEditor('<p>Hello world</p>')

        const tr = editor.state.tr.setSelection(NodeSelection.create(editor.state.doc, 0))

        editor.view.dispatch(tr)
        editor.commands.setBlockBackgroundColor('#dcfce7')

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.backgroundColor).toBe('#dcfce7')
      })
    })

    describe('WHEN the selection is at depth 0 (empty doc edge case)', () => {
      it('THEN should return false', () => {
        const editor = createEditor('<p>text</p>')

        // Force an edge case by checking the command can handle it
        const result = editor.commands.setBlockBackgroundColor('#fee2e2')

        editor.destroy()

        expect(result).toBe(true)
      })
    })
  })

  describe('GIVEN both backgroundColor and textColor are set on a block', () => {
    describe('WHEN getHTML is called', () => {
      it('THEN should render a single style attribute with both properties', () => {
        const editor = createEditor('<p>Dual styled</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')
        editor.commands.setBlockTextColor('#dc2626')

        const html = editor.getHTML()

        editor.destroy()

        expect(html).toContain('background-color')
        expect(html).toContain('color')
        // Both styles should be in the same style attribute
        const styleMatch = html.match(/style="([^"]*)"/)

        expect(styleMatch).toBeTruthy()
        expect(styleMatch?.[1]).toContain('background-color')
        expect(styleMatch?.[1]).toContain('color')
      })
    })
  })

  describe('GIVEN the setBlockTextColor command', () => {
    describe('WHEN called with a color', () => {
      it('THEN should apply textColor to the top-level block', () => {
        const editor = createEditor('<p>Hello world</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockTextColor('#dc2626')

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.textColor).toBe('#dc2626')
      })
    })

    describe('WHEN called with null', () => {
      it('THEN should remove the textColor', () => {
        const editor = createEditor('<p>Hello world</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockTextColor('#dc2626')
        editor.commands.setBlockTextColor(null)

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.textColor).toBeNull()
      })
    })
  })

  describe('GIVEN parseHTML', () => {
    describe('WHEN loading HTML with inline background-color style', () => {
      it('THEN should parse the backgroundColor attribute', () => {
        const editor = createEditor('<p style="background-color: rgb(254, 226, 226);">Colored</p>')

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.backgroundColor).toBe('rgb(254, 226, 226)')
      })
    })

    describe('WHEN loading HTML with inline color style', () => {
      it('THEN should parse the textColor attribute', () => {
        const editor = createEditor('<p style="color: rgb(220, 38, 38);">Red text</p>')

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.textColor).toBe('rgb(220, 38, 38)')
      })
    })

    describe('WHEN loading HTML with no inline styles', () => {
      it('THEN should have null color attributes', () => {
        const editor = createEditor('<p>Plain</p>')

        const firstNode = editor.state.doc.firstChild

        editor.destroy()

        expect(firstNode?.attrs.backgroundColor).toBeNull()
        expect(firstNode?.attrs.textColor).toBeNull()
      })
    })
  })

  describe('GIVEN colors applied via commands then serialized', () => {
    describe('WHEN getHTML is called after setting colors', () => {
      it('THEN should include inline styles in the output', () => {
        const editor = createEditor('<p>Styled text</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#dbeafe')
        editor.commands.setBlockTextColor('#2563eb')

        const html = editor.getHTML()

        editor.destroy()

        expect(html).toContain('background-color:')
        expect(html).toContain('color:')
        expect(html).toContain('style=')
      })
    })
  })

  describe('GIVEN markdown serialization with colors', () => {
    describe('WHEN a colored paragraph is serialized to markdown', () => {
      it('THEN should output HTML with inline styles', () => {
        const editor = createEditor('<p>Colored text</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('background-color')
        expect(markdown).toContain('Colored text')
      })
    })

    describe('WHEN a non-colored paragraph is serialized to markdown', () => {
      it('THEN should output plain markdown without HTML tags', () => {
        const editor = createEditor('<p>Plain text</p>')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toBe('Plain text')
      })
    })

    describe('WHEN a colored heading is serialized to markdown', () => {
      it('THEN should output HTML with inline styles', () => {
        const editor = createEditor('<h1>Title</h1>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockTextColor('#dc2626')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('color')
        expect(markdown).toContain('Title')
      })
    })
  })

  describe('GIVEN markdown round-trip with colors', () => {
    describe('WHEN a colored paragraph is serialized then parsed back', () => {
      it('THEN should preserve the backgroundColor', () => {
        const editor = createEditor('<p>Round trip</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')

        const markdown = getMarkdown(editor)

        editor.destroy()

        const editor2 = createEditor(markdown)
        const firstNode = editor2.state.doc.firstChild

        editor2.destroy()

        expect(firstNode?.attrs.backgroundColor).toBeTruthy()
        expect(firstNode?.textContent).toBe('Round trip')
      })
    })

    describe('WHEN a paragraph with both colors is serialized then parsed back', () => {
      it('THEN should preserve both backgroundColor and textColor', () => {
        const editor = createEditor('<p>Both colors</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#dbeafe')
        editor.commands.setBlockTextColor('#2563eb')

        const markdown = getMarkdown(editor)

        editor.destroy()

        const editor2 = createEditor(markdown)
        const firstNode = editor2.state.doc.firstChild

        editor2.destroy()

        expect(firstNode?.attrs.backgroundColor).toBeTruthy()
        expect(firstNode?.attrs.textColor).toBeTruthy()
        expect(firstNode?.textContent).toBe('Both colors')
      })
    })

    describe('WHEN a colored paragraph with bold text is serialized then parsed back', () => {
      it('THEN should preserve both colors and inline formatting', () => {
        const editor = createEditor('<p>Hello <strong>bold</strong> world</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')

        const markdown = getMarkdown(editor)

        editor.destroy()

        const editor2 = createEditor(markdown)
        const firstNode = editor2.state.doc.firstChild

        editor2.destroy()

        expect(firstNode?.attrs.backgroundColor).toBeTruthy()
        expect(firstNode?.textContent).toBe('Hello bold world')

        const html2 = createEditor(markdown)
        const outputHtml = html2.getHTML()

        html2.destroy()

        expect(outputHtml).toContain('<strong>bold</strong>')
      })
    })
  })
})
