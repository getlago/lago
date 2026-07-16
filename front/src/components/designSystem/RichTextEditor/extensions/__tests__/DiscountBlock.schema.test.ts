import { Editor, getSchema } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'

import type { EntityData } from '~/components/designSystem/RichTextEditor/common/RichTextEditorContext'

import { type DiscountBlockAttributes, DiscountBlockSchema } from '../DiscountBlock.schema'

describe('DiscountBlockSchema', () => {
  describe('GIVEN the DiscountBlockSchema node is created', () => {
    it('exposes discountBlock node with couponId + localId attrs', () => {
      const schema = getSchema([StarterKit, DiscountBlockSchema])

      expect(schema.nodes.discountBlock).toBeDefined()
      const node = schema.nodes.discountBlock.createAndFill({
        couponId: 'cpn_1',
        localId: 'local-1',
      } as DiscountBlockAttributes)

      expect(node?.attrs.couponId).toBe('cpn_1')
      expect(node?.attrs.localId).toBe('local-1')
    })

    it('THEN should have the correct name', () => {
      expect(DiscountBlockSchema.name).toBe('discountBlock')
    })

    it('THEN should be a block group', () => {
      expect(DiscountBlockSchema.config.group).toBe('block')
    })

    it('THEN should be an atom node', () => {
      expect(DiscountBlockSchema.config.atom).toBe(true)
    })
  })

  describe('GIVEN the addAttributes config', () => {
    const getAttributes = () => {
      const addAttributes = DiscountBlockSchema.config.addAttributes as unknown as () => {
        couponId: { default: string; parseHTML: (element: HTMLElement) => string }
        localId: { default: string; parseHTML: (element: HTMLElement) => string }
      }

      return addAttributes()
    }

    it('THEN should have couponId attribute with empty string default', () => {
      const attrs = getAttributes()

      expect(attrs.couponId.default).toBe('')
    })

    it('THEN should have localId attribute with empty string default', () => {
      const attrs = getAttributes()

      expect(attrs.localId.default).toBe('')
    })

    describe('WHEN parseHTML is called with data-coupon-id attribute', () => {
      it('THEN should return the couponId value', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        element.setAttribute('data-coupon-id', 'cpn_abc')

        expect(attrs.couponId.parseHTML(element)).toBe('cpn_abc')
      })
    })

    describe('WHEN parseHTML is called without data-coupon-id attribute', () => {
      it('THEN should return empty string', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        expect(attrs.couponId.parseHTML(element)).toBe('')
      })
    })

    describe('WHEN parseHTML is called with data-local-id attribute', () => {
      it('THEN should return the localId value', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        element.setAttribute('data-local-id', 'local-xyz')

        expect(attrs.localId.parseHTML(element)).toBe('local-xyz')
      })
    })

    describe('WHEN parseHTML is called without data-local-id attribute', () => {
      it('THEN should return empty string', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        expect(attrs.localId.parseHTML(element)).toBe('')
      })
    })
  })

  describe('GIVEN the addStorage config', () => {
    const getStorage = () => {
      const addStorage = DiscountBlockSchema.config.addStorage as unknown as () => {
        markdown: {
          serialize: (
            state: { write: (text: string) => void; closeBlock: (node: unknown) => void },
            node: { attrs: DiscountBlockAttributes },
          ) => void
          parse: {
            updateDOM: (element: HTMLElement) => void
          }
        }
      }

      return addStorage()
    }

    describe('WHEN serialize is called with couponId and localId', () => {
      it('THEN should write the entity discount comment', () => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()
        const node = { attrs: { couponId: 'cpn_1', localId: 'local-1' } }

        storage.markdown.serialize({ write: mockWrite, closeBlock: mockCloseBlock }, node)

        expect(mockWrite).toHaveBeenCalledWith('<!-- entity:discount:cpn_1|local-1 -->')
        expect(mockCloseBlock).toHaveBeenCalledWith(node)
      })
    })

    describe('WHEN serialize is called with couponId and empty localId', () => {
      it('THEN should write the entity discount comment with empty localId part', () => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()
        const node = { attrs: { couponId: 'cpn_2', localId: '' } }

        storage.markdown.serialize({ write: mockWrite, closeBlock: mockCloseBlock }, node)

        expect(mockWrite).toHaveBeenCalledWith('<!-- entity:discount:cpn_2| -->')
        expect(mockCloseBlock).toHaveBeenCalledWith(node)
      })
    })

    describe('WHEN parse.updateDOM is called with entity discount comments', () => {
      it('THEN should replace comment with discount block div', () => {
        const storage = getStorage()
        const element = {
          innerHTML: 'Some text <!-- entity:discount:cpn_1|local-1 --> more text',
        } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toContain('data-type="discount-block"')
        expect(element.innerHTML).toContain('data-coupon-id="cpn_1"')
        expect(element.innerHTML).toContain('data-local-id="local-1"')
      })
    })

    describe('WHEN parse.updateDOM is called with empty localId', () => {
      it('THEN should replace comment with discount block div with empty data-local-id', () => {
        const storage = getStorage()
        const element = {
          innerHTML: '<!-- entity:discount:cpn_2| -->',
        } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toContain('data-type="discount-block"')
        expect(element.innerHTML).toContain('data-coupon-id="cpn_2"')
        expect(element.innerHTML).toContain('data-local-id=""')
      })
    })

    describe('WHEN parse.updateDOM is called with no discount comments', () => {
      it('THEN should not modify the innerHTML', () => {
        const storage = getStorage()
        const element = { innerHTML: 'No discount blocks here.' } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toBe('No discount blocks here.')
      })
    })

    describe('WHEN serialize then updateDOM (round-trip)', () => {
      it('THEN should reconstruct the original couponId and localId', () => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()
        const node = { attrs: { couponId: 'cpn_roundtrip', localId: 'local-rt' } }

        storage.markdown.serialize({ write: mockWrite, closeBlock: mockCloseBlock }, node)

        const comment = mockWrite.mock.calls[0][0] as string
        const element = { innerHTML: comment } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toContain('data-coupon-id="cpn_roundtrip"')
        expect(element.innerHTML).toContain('data-local-id="local-rt"')
      })
    })
  })

  describe('GIVEN the parseHTML config', () => {
    it('THEN should match div elements with data-type="discount-block"', () => {
      const parseHTML = DiscountBlockSchema.config.parseHTML as unknown as () => { tag: string }[]
      const rules = parseHTML()

      expect(rules).toEqual([{ tag: 'div[data-type="discount-block"]' }])
    })
  })

  describe('GIVEN the renderHTML via getHTML()', () => {
    const getHtmlForDiscountBlock = (
      couponId: string,
      localId: string,
      entities?: Record<string, EntityData>,
    ) => {
      const editor = new Editor({
        extensions: [StarterKit, DiscountBlockSchema.configure({ entities })],
        content: {
          type: 'doc',
          content: [{ type: 'discountBlock', attrs: { couponId, localId } }],
        },
      })
      const html = editor.getHTML()

      editor.destroy()

      return html
    }

    describe('WHEN called with couponId and no entities data', () => {
      it('THEN should render a div with fallback label', () => {
        const html = getHtmlForDiscountBlock('cpn_1', 'local-1')

        expect(html).toContain('data-type="discount-block"')
        expect(html).toContain('data-coupon-id="cpn_1"')
        expect(html).toContain('data-local-id="local-1"')
        expect(html).toContain('Coupon: cpn_1')
      })
    })

    describe('WHEN called with empty couponId', () => {
      it('THEN should render fallback "Select a coupon" label', () => {
        const html = getHtmlForDiscountBlock('', '')

        expect(html).toContain('Select a coupon')
      })
    })
  })
})
