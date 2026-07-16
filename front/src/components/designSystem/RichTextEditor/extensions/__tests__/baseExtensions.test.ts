import { Editor } from '@tiptap/core'

import { getBaseExtensions } from '../baseExtensions'

const createEditor = (content = '') =>
  new Editor({
    extensions: getBaseExtensions(),
    content,
  })

const getMarkdown = (editor: Editor): string => (editor.storage as any).markdown.getMarkdown()

describe('getBaseExtensions', () => {
  describe('GIVEN no options are provided', () => {
    describe('WHEN getBaseExtensions is called', () => {
      it('THEN should return an array of extensions', () => {
        const extensions = getBaseExtensions()

        expect(Array.isArray(extensions)).toBe(true)
        expect(extensions.length).toBeGreaterThan(0)
      })

      it('THEN should include StarterKit with link and underline disabled', () => {
        const extensions = getBaseExtensions()
        const starterKit = extensions.find((ext) => 'name' in ext && ext.name === 'starterKit') as
          { name: string; options: Record<string, unknown> } | undefined

        expect(starterKit).toBeDefined()
        expect(starterKit?.options.link).toBe(false)
        expect(starterKit?.options.underline).toBe(false)
      })

      it.each([
        ['link'],
        ['underline'],
        ['superscript'],
        ['subscript'],
        ['highlight'],
        ['textAlign'],
        ['table'],
        ['tableRow'],
        ['tableCell'],
        ['tableHeader'],
        ['linkCard'],
        ['blockColors'],
        ['paragraph'],
        ['heading'],
        ['markdown'],
      ])('THEN should include the %s extension', (extensionName) => {
        const extensions = getBaseExtensions()
        const names = extensions.map((ext) => ('name' in ext ? ext.name : undefined))

        expect(names).toContain(extensionName)
      })

      it('THEN should configure Table with resizable false by default', () => {
        const extensions = getBaseExtensions()
        const table = extensions.find((ext) => 'name' in ext && ext.name === 'table') as
          { name: string; options: { resizable: boolean } } | undefined

        expect(table).toBeDefined()
        expect(table?.options.resizable).toBe(false)
      })

      it('THEN should configure Link with openOnClick false', () => {
        const extensions = getBaseExtensions()
        const link = extensions.find((ext) => 'name' in ext && ext.name === 'link') as
          { name: string; options: { openOnClick: boolean } } | undefined

        expect(link).toBeDefined()
        expect(link?.options.openOnClick).toBe(false)
      })
    })
  })

  describe('GIVEN tableResizable option is true', () => {
    describe('WHEN getBaseExtensions is called', () => {
      it('THEN should configure Table with resizable true', () => {
        const extensions = getBaseExtensions({ tableResizable: true })
        const table = extensions.find((ext) => 'name' in ext && ext.name === 'table') as
          { name: string; options: { resizable: boolean } } | undefined

        expect(table).toBeDefined()
        expect(table?.options.resizable).toBe(true)
      })
    })
  })

  describe('GIVEN tableResizable option is false', () => {
    describe('WHEN getBaseExtensions is called', () => {
      it('THEN should configure Table with resizable false', () => {
        const extensions = getBaseExtensions({ tableResizable: false })
        const table = extensions.find((ext) => 'name' in ext && ext.name === 'table') as
          { name: string; options: { resizable: boolean } } | undefined

        expect(table).toBeDefined()
        expect(table?.options.resizable).toBe(false)
      })
    })
  })

  describe('GIVEN the ColorAwareParagraph extension', () => {
    describe('WHEN a paragraph without colors is serialized to markdown', () => {
      it('THEN should produce plain markdown', () => {
        const editor = createEditor('<p>Hello world</p>')
        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toBe('Hello world')
      })
    })

    describe('WHEN a paragraph with backgroundColor is serialized to markdown', () => {
      it('THEN should produce HTML with inline styles', () => {
        const editor = createEditor('<p>Colored</p>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('background-color')
        expect(markdown).toContain('Colored')
      })
    })
  })

  describe('GIVEN the ColorAwareHeading extension', () => {
    describe('WHEN a heading without colors is serialized to markdown', () => {
      it('THEN should produce markdown heading syntax', () => {
        const editor = createEditor('<h1>Title</h1>')
        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toBe('# Title')
      })
    })

    describe('WHEN a heading with textColor is serialized to markdown', () => {
      it('THEN should produce HTML with inline styles', () => {
        const editor = createEditor('<h2>Subtitle</h2>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockTextColor('#dc2626')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('color')
        expect(markdown).toContain('Subtitle')
      })
    })

    describe('WHEN a h3 heading with backgroundColor is serialized to markdown', () => {
      it('THEN should produce HTML preserving the heading level', () => {
        const editor = createEditor('<h3>Section</h3>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#dbeafe')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('background-color')
        expect(markdown).toContain('Section')
        expect(markdown).toContain('h3')
      })
    })
  })

  describe('GIVEN the ColorAwareBulletList extension', () => {
    describe('WHEN a bullet list without colors is serialized to markdown', () => {
      it('THEN should produce plain markdown list', () => {
        const editor = createEditor('<ul><li>Item one</li><li>Item two</li></ul>')
        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('Item one')
        expect(markdown).toContain('Item two')
        expect(markdown).not.toContain('background-color')
      })
    })

    describe('WHEN a bullet list with backgroundColor is serialized to markdown', () => {
      it('THEN should produce HTML with inline styles', () => {
        const editor = createEditor('<ul><li>Colored item</li></ul>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockBackgroundColor('#fee2e2')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('background-color')
        expect(markdown).toContain('Colored item')
      })
    })
  })

  describe('GIVEN the ColorAwareOrderedList extension', () => {
    describe('WHEN an ordered list without colors is serialized to markdown', () => {
      it('THEN should produce plain markdown list', () => {
        const editor = createEditor('<ol><li>First</li><li>Second</li></ol>')
        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('First')
        expect(markdown).toContain('Second')
        expect(markdown).not.toContain('background-color')
      })
    })

    describe('WHEN an ordered list with textColor is serialized to markdown', () => {
      it('THEN should produce HTML with inline styles', () => {
        const editor = createEditor('<ol><li>Colored item</li></ol>')

        editor.commands.setTextSelection(1)
        editor.commands.setBlockTextColor('#dc2626')

        const markdown = getMarkdown(editor)

        editor.destroy()

        expect(markdown).toContain('color')
        expect(markdown).toContain('Colored item')
      })
    })
  })

  describe('GIVEN StarterKit is configured with paragraph and heading disabled', () => {
    describe('WHEN getBaseExtensions is called', () => {
      it('THEN should disable paragraph and heading in StarterKit', () => {
        const extensions = getBaseExtensions()
        const starterKit = extensions.find((ext) => 'name' in ext && ext.name === 'starterKit') as
          { name: string; options: Record<string, unknown> } | undefined

        expect(starterKit?.options.paragraph).toBe(false)
        expect(starterKit?.options.heading).toBe(false)
      })

      it('THEN should configure dropcursor with blue color', () => {
        const extensions = getBaseExtensions()
        const starterKit = extensions.find((ext) => 'name' in ext && ext.name === 'starterKit') as
          { name: string; options: Record<string, unknown> } | undefined

        expect(starterKit?.options.dropcursor).toEqual({ color: '#dbeafe', width: 4 })
      })
    })
  })

  describe('GIVEN the extension list does not contain duplicates', () => {
    describe('WHEN getBaseExtensions is called', () => {
      it('THEN should not have duplicate extension names', () => {
        const extensions = getBaseExtensions()
        const names = extensions
          .map((ext) => ('name' in ext ? ext.name : undefined))
          .filter(Boolean)

        const uniqueNames = new Set(names)

        expect(names.length).toBe(uniqueNames.size)
      })
    })
  })

  describe('GIVEN the Markdown extension', () => {
    const findMarkdown = () => getBaseExtensions().find((ext) => ext.name === 'markdown')

    it('THEN is configured to transform pasted plain text as markdown', () => {
      const markdown = findMarkdown()

      expect(markdown).toBeDefined()
      expect(markdown?.options.transformPastedText).toBe(true)
    })

    it('THEN still allows inline HTML (existing behavior preserved)', () => {
      const markdown = findMarkdown()

      expect(markdown?.options.html).toBe(true)
    })
  })
})
