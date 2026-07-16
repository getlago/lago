import { LinkCard } from '../LinkCard'

describe('LinkCard', () => {
  describe('GIVEN the LinkCard extension is created', () => {
    it('THEN should have the name "linkCard"', () => {
      expect(LinkCard.name).toBe('linkCard')
    })
  })

  describe('GIVEN the renderHTML function', () => {
    const getRenderHTML = () => {
      const extensionConfig = LinkCard.config

      const rawRenderHTML = extensionConfig.renderHTML as unknown as (props: {
        HTMLAttributes: Record<string, unknown>
      }) => unknown[]

      // Unwrap the block wrapper structure: spacer > block-wrapper > inner content
      return (props: { HTMLAttributes: Record<string, unknown> }) => {
        const wrapped = rawRenderHTML(props)
        const blockWrapper = wrapped[2] as unknown[]

        return blockWrapper[2] as unknown[]
      }
    }

    describe('WHEN called with a valid URL', () => {
      it('THEN should extract the hostname as domain', () => {
        const renderHTML = getRenderHTML()

        const result = renderHTML({
          HTMLAttributes: { href: 'https://www.example.com/path/to/page' },
        })

        const outerDiv = result as unknown[]
        const anchor = outerDiv[2] as unknown[]
        const domainSpan = anchor[2] as unknown[]

        expect(domainSpan[2]).toBe('www.example.com')
      })

      it('THEN should include the full URL in the url span', () => {
        const renderHTML = getRenderHTML()
        const href = 'https://www.example.com/path/to/page'

        const result = renderHTML({ HTMLAttributes: { href } })

        const outerDiv = result as unknown[]
        const anchor = outerDiv[2] as unknown[]
        const urlSpan = anchor[3] as unknown[]

        expect(urlSpan[2]).toBe(href)
      })

      it('THEN should produce the correct HTML structure', () => {
        const renderHTML = getRenderHTML()
        const href = 'https://example.com'

        const result = renderHTML({ HTMLAttributes: { href } })

        expect(result[0]).toBe('div')

        const attrs = result[1] as Record<string, string>

        expect(attrs['data-type']).toBe('link-card')
        expect(attrs.class).toBe('link-card')

        const anchor = result[2] as unknown[]

        expect(anchor[0]).toBe('a')

        const anchorAttrs = anchor[1] as Record<string, string>

        expect(anchorAttrs.href).toBe(href)
        expect(anchorAttrs.target).toBe('_blank')
        expect(anchorAttrs.rel).toBe('noopener noreferrer')
      })
    })

    describe('WHEN called with an invalid URL', () => {
      it('THEN should fallback to using the href string as domain', () => {
        const renderHTML = getRenderHTML()

        const result = renderHTML({ HTMLAttributes: { href: 'not-a-valid-url' } })

        const outerDiv = result as unknown[]
        const anchor = outerDiv[2] as unknown[]
        const domainSpan = anchor[2] as unknown[]

        expect(domainSpan[2]).toBe('not-a-valid-url')
      })
    })

    describe('WHEN called with null href', () => {
      it('THEN should safely convert to empty string', () => {
        const renderHTML = getRenderHTML()

        const result = renderHTML({ HTMLAttributes: { href: null } })

        const outerDiv = result as unknown[]
        const anchor = outerDiv[2] as unknown[]
        const anchorAttrs = anchor[1] as Record<string, string>

        expect(anchorAttrs.href).toBe('')
      })
    })

    describe('WHEN called with undefined href', () => {
      it('THEN should safely convert to empty string', () => {
        const renderHTML = getRenderHTML()

        const result = renderHTML({ HTMLAttributes: { href: undefined } })

        const outerDiv = result as unknown[]
        const anchor = outerDiv[2] as unknown[]
        const anchorAttrs = anchor[1] as Record<string, string>

        expect(anchorAttrs.href).toBe('')
      })
    })
  })

  describe('GIVEN the parseHTML function', () => {
    it('THEN should match div[data-type="link-card"]', () => {
      const extensionConfig = LinkCard.config
      const parseHTML = extensionConfig.parseHTML as () => Array<{ tag: string }>

      const rules = parseHTML()

      expect(rules).toEqual([{ tag: 'div[data-type="link-card"]' }])
    })
  })

  describe('GIVEN the addAttributes function', () => {
    it('THEN should define href with default null', () => {
      const extensionConfig = LinkCard.config
      const addAttributes = extensionConfig.addAttributes as () => Record<
        string,
        { default: unknown }
      >

      const attrs = addAttributes()

      expect(attrs.href).toEqual({ default: null })
    })
  })

  describe('GIVEN the addStorage function', () => {
    const getStorage = () => {
      const extensionConfig = LinkCard.config
      const addStorage = extensionConfig.addStorage as () => {
        markdown: {
          serialize: (
            state: { write: (text: string) => void; closeBlock: (node: unknown) => void },
            node: { attrs: { href: string } },
          ) => void
          parse: Record<string, unknown>
        }
      }

      return addStorage()
    }

    describe('WHEN serialize is called with a URL', () => {
      it('THEN should write a markdown link with href as both text and URL', () => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()
        const node = { attrs: { href: 'https://example.com' } }

        storage.markdown.serialize({ write: mockWrite, closeBlock: mockCloseBlock }, node)

        expect(mockWrite).toHaveBeenCalledWith('[https://example.com](https://example.com)')
        expect(mockCloseBlock).toHaveBeenCalledWith(node)
      })
    })

    describe('WHEN serialize is called with different URLs', () => {
      it.each([
        ['https://example.com/path', '[https://example.com/path](https://example.com/path)'],
        ['https://lago.dev', '[https://lago.dev](https://lago.dev)'],
        [
          'https://docs.example.com/api?q=test',
          '[https://docs.example.com/api?q=test](https://docs.example.com/api?q=test)',
        ],
      ])('THEN should serialize %s correctly', (href, expectedMarkdown) => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()

        storage.markdown.serialize(
          { write: mockWrite, closeBlock: mockCloseBlock },
          { attrs: { href } },
        )

        expect(mockWrite).toHaveBeenCalledWith(expectedMarkdown)
      })
    })

    describe('WHEN accessing the parse config', () => {
      it('THEN should return an object (empty parse rules)', () => {
        const storage = getStorage()

        expect(storage.markdown.parse).toBeDefined()
        expect(typeof storage.markdown.parse).toBe('object')
      })
    })
  })
})
