import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'

import type { EntityData } from '~/components/designSystem/RichTextEditor/common/RichTextEditorContext'

import { PricingBlock } from '../PricingBlock'
import { getPricingBlockPreviewData, PricingBlockSchema } from '../PricingBlock.schema'

jest.mock('../../PricingBlock/PricingBlockView', () => ({
  PricingBlockView: () => null,
}))

describe('PricingBlock', () => {
  describe('GIVEN the PricingBlock extension is created', () => {
    it('THEN should have the correct name', () => {
      expect(PricingBlock.name).toBe('pricingBlock')
    })

    it('THEN should be a block group', () => {
      expect(PricingBlock.config.group).toBe('block')
    })

    it('THEN should be an atom node', () => {
      expect(PricingBlock.config.atom).toBe(true)
    })
  })

  describe('GIVEN the addNodeView method', () => {
    it('THEN should return a node view renderer', () => {
      const addNodeView = PricingBlock.config.addNodeView as (() => unknown) | undefined

      expect(addNodeView).toBeDefined()

      const result = addNodeView?.call({})

      expect(result).toBeDefined()
    })
  })

  describe('GIVEN the addAttributes config', () => {
    const getAttributes = () => {
      const addAttributes = PricingBlock.config.addAttributes as unknown as () => {
        pricingType: { default: string; parseHTML: (element: HTMLElement) => string }
        entityIds: { default: string[]; parseHTML: (element: HTMLElement) => string[] }
      }

      return addAttributes()
    }

    it('THEN should have pricingType attribute with "plan" default', () => {
      const attrs = getAttributes()

      expect(attrs.pricingType.default).toBe('plan')
    })

    it('THEN should have entityIds attribute with empty array default', () => {
      const attrs = getAttributes()

      expect(attrs.entityIds.default).toEqual([])
    })

    describe('WHEN parseHTML is called with data-pricing-type attribute', () => {
      it('THEN should return the pricing type value', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        element.setAttribute('data-pricing-type', 'addOns')

        expect(attrs.pricingType.parseHTML(element)).toBe('addOns')
      })
    })

    describe('WHEN parseHTML is called without data-pricing-type attribute', () => {
      it('THEN should return "plan"', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        expect(attrs.pricingType.parseHTML(element)).toBe('plan')
      })
    })

    describe('WHEN parseHTML is called with data-entity-ids attribute (single ID)', () => {
      it('THEN should return an array with one ID', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        element.setAttribute('data-entity-ids', 'plan-123')

        expect(attrs.entityIds.parseHTML(element)).toEqual(['plan-123'])
      })
    })

    describe('WHEN parseHTML is called with data-entity-ids attribute (multiple IDs)', () => {
      it('THEN should return an array with multiple IDs', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        element.setAttribute('data-entity-ids', 'addon-1,addon-2,addon-3')

        expect(attrs.entityIds.parseHTML(element)).toEqual(['addon-1', 'addon-2', 'addon-3'])
      })
    })

    describe('WHEN parseHTML is called without data-entity-ids attribute', () => {
      it('THEN should return empty array', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        expect(attrs.entityIds.parseHTML(element)).toEqual([])
      })
    })

    describe('WHEN parseHTML is called with empty data-entity-ids attribute', () => {
      it('THEN should return empty array', () => {
        const attrs = getAttributes()
        const element = document.createElement('div')

        element.setAttribute('data-entity-ids', '')

        expect(attrs.entityIds.parseHTML(element)).toEqual([])
      })
    })
  })

  describe('GIVEN the addStorage config', () => {
    const getStorage = () => {
      const addStorage = PricingBlock.config.addStorage as unknown as () => {
        markdown: {
          serialize: (
            state: { write: (text: string) => void; closeBlock: (node: unknown) => void },
            node: { attrs: { pricingType: string; entityIds: string[] } },
          ) => void
          parse: {
            updateDOM: (element: HTMLElement) => void
          }
        }
      }

      return addStorage()
    }

    describe('WHEN serialize is called with pricingType "plan" and a single entityId', () => {
      it('THEN should write the entity comment for plan', () => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()
        const node = { attrs: { pricingType: 'plan', entityIds: ['plan-123'] } }

        storage.markdown.serialize({ write: mockWrite, closeBlock: mockCloseBlock }, node)

        expect(mockWrite).toHaveBeenCalledWith('<!-- entity:pricing:plan:plan-123 -->')
        expect(mockCloseBlock).toHaveBeenCalledWith(node)
      })
    })

    describe('WHEN serialize is called with pricingType "addOns" and multiple entityIds', () => {
      it('THEN should write the entity comment with comma-separated IDs', () => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()
        const node = {
          attrs: { pricingType: 'addOns', entityIds: ['addon-1', 'addon-2', 'addon-3'] },
        }

        storage.markdown.serialize({ write: mockWrite, closeBlock: mockCloseBlock }, node)

        expect(mockWrite).toHaveBeenCalledWith(
          '<!-- entity:pricing:addOns:addon-1,addon-2,addon-3 -->',
        )
        expect(mockCloseBlock).toHaveBeenCalledWith(node)
      })
    })

    describe('WHEN serialize is called with empty entityIds', () => {
      it('THEN should write the entity comment with empty ids', () => {
        const storage = getStorage()
        const mockWrite = jest.fn()
        const mockCloseBlock = jest.fn()
        const node = { attrs: { pricingType: 'plan', entityIds: [] } }

        storage.markdown.serialize({ write: mockWrite, closeBlock: mockCloseBlock }, node)

        expect(mockWrite).toHaveBeenCalledWith('<!-- entity:pricing:plan: -->')
        expect(mockCloseBlock).toHaveBeenCalledWith(node)
      })
    })

    describe('WHEN parse.updateDOM is called with entity pricing plan comments', () => {
      it('THEN should replace comments with pricing block div elements', () => {
        const storage = getStorage()
        const element = {
          innerHTML: 'Some text <!-- entity:pricing:plan:plan-123 --> more text',
        } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toContain('data-type="pricing-block"')
        expect(element.innerHTML).toContain('data-pricing-type="plan"')
        expect(element.innerHTML).toContain('data-entity-ids="plan-123"')
      })
    })

    describe('WHEN parse.updateDOM is called with entity pricing addOns comments', () => {
      it('THEN should replace comments with pricing block div for addOns', () => {
        const storage = getStorage()
        const element = {
          innerHTML: '<!-- entity:pricing:addOns:addon-1,addon-2 -->',
        } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toContain('data-type="pricing-block"')
        expect(element.innerHTML).toContain('data-pricing-type="addOns"')
        expect(element.innerHTML).toContain('data-entity-ids="addon-1,addon-2"')
      })
    })

    describe('WHEN parse.updateDOM is called with empty entity ids comment', () => {
      it('THEN should replace with a pricing block div with empty ids', () => {
        const storage = getStorage()
        const element = {
          innerHTML: '<!-- entity:pricing:plan: -->',
        } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toContain('data-type="pricing-block"')
        expect(element.innerHTML).toContain('data-pricing-type="plan"')
        expect(element.innerHTML).toContain('data-entity-ids=""')
      })
    })

    describe('WHEN parse.updateDOM is called with no pricing comments', () => {
      it('THEN should not modify the innerHTML', () => {
        const storage = getStorage()
        const element = { innerHTML: 'No pricing blocks here.' } as HTMLElement

        storage.markdown.parse.updateDOM(element)

        expect(element.innerHTML).toBe('No pricing blocks here.')
      })
    })
  })

  describe('GIVEN the parseHTML config', () => {
    it('THEN should match div elements with data-type="pricing-block"', () => {
      const parseHTML = PricingBlock.config.parseHTML as unknown as () => { tag: string }[]
      const rules = parseHTML()

      expect(rules).toEqual([{ tag: 'div[data-type="pricing-block"]' }])
    })
  })

  describe('GIVEN the renderHTML via getHTML()', () => {
    const getHtmlForPricingBlock = (
      pricingType: string,
      entityIds: string[],
      entities?: Record<string, EntityData>,
    ) => {
      const editor = new Editor({
        extensions: [StarterKit, PricingBlockSchema.configure({ entities })],
        content: {
          type: 'doc',
          content: [{ type: 'pricingBlock', attrs: { pricingType, entityIds } }],
        },
      })
      const html = editor.getHTML()

      editor.destroy()

      return html
    }

    describe('WHEN called with pricingType "plan" and a single entityId, no entities data', () => {
      it('THEN should render a div with fallback label', () => {
        const html = getHtmlForPricingBlock('plan', ['plan-123'])

        expect(html).toContain('data-type="pricing-block"')
        expect(html).toContain('data-pricing-type="plan"')
        expect(html).toContain('Plan: plan-123')
      })
    })

    describe('WHEN called with pricingType "plan" and entities data', () => {
      it('THEN should render a resolved table', () => {
        const html = getHtmlForPricingBlock('plan', ['plan-123'], {
          'plan-123': {
            entityId: 'plan-123',
            entityType: 'plan',
            name: 'Pro Plan',
            code: 'pro_plan',
          },
        })

        expect(html).toContain('Plan name')
        expect(html).toContain('Plan code')
        expect(html).toContain('Pro Plan')
        expect(html).toContain('pro_plan')
      })
    })

    describe('WHEN called with pricingType "addOns" and multiple entityIds, no entities data', () => {
      it('THEN should render a div with fallback label', () => {
        const html = getHtmlForPricingBlock('addOns', ['addon-1', 'addon-2'])

        expect(html).toContain('data-type="pricing-block"')
        expect(html).toContain('data-pricing-type="addOns"')
        expect(html).toContain('Add-ons: addon-1, addon-2')
      })
    })

    describe('WHEN called with pricingType "addOns" and entities data', () => {
      it('THEN should render a resolved table with multiple rows', () => {
        const html = getHtmlForPricingBlock('addOns', ['addon-1', 'addon-2'], {
          'addon-1': {
            entityId: 'addon-1',
            entityType: 'plan',
            name: 'Storage Add-on',
            code: 'storage',
          },
          'addon-2': {
            entityId: 'addon-2',
            entityType: 'plan',
            name: 'Support Add-on',
            code: 'support',
          },
        })

        expect(html).toContain('Add-on name')
        expect(html).toContain('Add-on code')
        expect(html).toContain('Storage Add-on')
        expect(html).toContain('storage')
        expect(html).toContain('Support Add-on')
        expect(html).toContain('support')
      })
    })

    describe('WHEN called with empty entityIds', () => {
      it('THEN should render fallback text for plan', () => {
        const html = getHtmlForPricingBlock('plan', [])

        expect(html).toContain('Select a plan')
      })
    })

    describe('WHEN called with empty entityIds for addOns', () => {
      it('THEN should render fallback text for add-ons', () => {
        const html = getHtmlForPricingBlock('addOns', [])

        expect(html).toContain('Select add-ons')
      })
    })
  })

  describe('GIVEN the getPricingBlockPreviewData helper', () => {
    describe('WHEN pricingType is "plan"', () => {
      it('THEN should return plan name/code when entity data is available', () => {
        const result = getPricingBlockPreviewData('plan', ['plan-123'], {
          'plan-123': { name: 'Pro Plan', code: 'pro_plan' },
        })

        expect(result).toEqual({
          nameHeader: 'Plan name',
          codeHeader: 'Plan code',
          rows: [{ nameValue: 'Pro Plan', codeValue: 'pro_plan' }],
        })
      })

      it('THEN should fallback to entity ID when no entity data', () => {
        const result = getPricingBlockPreviewData('plan', ['plan-123'])

        expect(result).toEqual({
          nameHeader: 'Plan ID',
          codeHeader: 'Plan ID',
          rows: [{ nameValue: 'plan-123', codeValue: 'plan-123' }],
        })
      })

      it('THEN should fallback to entity ID for missing name/code', () => {
        const result = getPricingBlockPreviewData('plan', ['plan-123'], {
          'plan-123': { name: undefined, code: undefined },
        })

        expect(result).toEqual({
          nameHeader: 'Plan ID',
          codeHeader: 'Plan ID',
          rows: [{ nameValue: 'plan-123', codeValue: 'plan-123' }],
        })
      })
    })

    describe('WHEN pricingType is "addOns"', () => {
      it('THEN should return add-on name/code when entity data is available', () => {
        const result = getPricingBlockPreviewData('addOns', ['addon-1', 'addon-2'], {
          'addon-1': { name: 'Storage', code: 'storage' },
          'addon-2': { name: 'Support', code: 'support' },
        })

        expect(result).toEqual({
          nameHeader: 'Add-on name',
          codeHeader: 'Add-on code',
          rows: [
            { nameValue: 'Storage', codeValue: 'storage' },
            { nameValue: 'Support', codeValue: 'support' },
          ],
        })
      })

      it('THEN should fallback to entity IDs when no entity data', () => {
        const result = getPricingBlockPreviewData('addOns', ['addon-1', 'addon-2'])

        expect(result).toEqual({
          nameHeader: 'Add-on ID',
          codeHeader: 'Add-on ID',
          rows: [
            { nameValue: 'addon-1', codeValue: 'addon-1' },
            { nameValue: 'addon-2', codeValue: 'addon-2' },
          ],
        })
      })
    })

    describe('WHEN entityIds is empty', () => {
      it('THEN should return empty rows for plan', () => {
        const result = getPricingBlockPreviewData('plan', [])

        expect(result).toEqual({
          nameHeader: 'Plan name',
          codeHeader: 'Plan code',
          rows: [],
        })
      })

      it('THEN should return empty rows for addOns', () => {
        const result = getPricingBlockPreviewData('addOns', [])

        expect(result).toEqual({
          nameHeader: 'Add-on name',
          codeHeader: 'Add-on code',
          rows: [],
        })
      })
    })
  })
})
