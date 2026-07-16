import type { EditorTemplate } from '../../TemplateSelector/types'
import { TemplateSelectorExtension } from '../TemplateSelectorExtension'

jest.mock('../../TemplateSelector/TemplateSelectorView', () => ({
  TemplateSelectorView: () => null,
}))

const mockTemplates: EditorTemplate[] = [
  {
    id: 'tpl-1',
    name: 'Template 1',
    description: 'First template',
    content: '# Template 1',
  },
]

// Helper to extract the appendTransaction function from the plugin
const getAppendTransaction = (templates: EditorTemplate[] = []) => {
  const addPlugins = TemplateSelectorExtension.config.addProseMirrorPlugins as unknown as () => {
    spec: { appendTransaction: (...args: unknown[]) => unknown }
  }[]

  // Call with the proper `this` context
  const plugins = addPlugins.call({
    name: 'templateSelector',
    options: { templates },
  })

  return plugins[0].spec.appendTransaction as (
    transactions: { docChanged: boolean }[],
    oldState: unknown,
    newState: unknown,
  ) => unknown
}

// Helper to create a mock EditorState
const createMockState = ({
  nodes = [] as { type: { name: string }; isText: boolean; pos: number; nodeSize?: number }[],
  textContent = '',
  hasTemplateSelectorNodeType = true,
}: {
  nodes?: { type: { name: string }; isText: boolean; pos: number; nodeSize?: number }[]
  textContent?: string
  hasTemplateSelectorNodeType?: boolean
} = {}) => {
  const mockDelete = jest.fn().mockReturnThis()
  const mockInsert = jest.fn().mockReturnThis()
  const mockCreate = jest.fn().mockReturnValue({ type: 'templateSelectorNode' })

  const state = {
    doc: {
      descendants: (
        cb: (node: { type: { name: string }; isText: boolean }, pos: number) => boolean | void,
      ) => {
        for (const n of nodes) {
          const result = cb(n, n.pos)

          if (result === false) break
        }
      },
      nodeAt: (pos: number) => {
        const found = nodes.find((n) => n.pos === pos)

        return found ? { nodeSize: found.nodeSize ?? 1 } : null
      },
      textContent,
      content: { size: 10 },
    },
    tr: {
      delete: mockDelete,
      insert: mockInsert,
    },
    schema: {
      nodes: hasTemplateSelectorNodeType ? { templateSelector: { create: mockCreate } } : {},
    },
  }

  return { state, mockDelete, mockInsert, mockCreate }
}

describe('TemplateSelectorExtension', () => {
  describe('GIVEN the extension is created', () => {
    it('THEN should have the correct name', () => {
      expect(TemplateSelectorExtension.name).toBe('templateSelector')
    })

    it('THEN should be a block group', () => {
      expect(TemplateSelectorExtension.config.group).toBe('block')
    })

    it('THEN should be an atom node', () => {
      expect(TemplateSelectorExtension.config.atom).toBe(true)
    })

    it('THEN should not be selectable', () => {
      expect(TemplateSelectorExtension.config.selectable).toBe(false)
    })

    it('THEN should not be draggable', () => {
      expect(TemplateSelectorExtension.config.draggable).toBe(false)
    })
  })

  describe('GIVEN the addOptions config', () => {
    it('THEN should have empty templates array as default', () => {
      const addOptions = TemplateSelectorExtension.config.addOptions as unknown as () => {
        templates: unknown[]
      }
      const options = addOptions()

      expect(options.templates).toEqual([])
    })
  })

  describe('GIVEN the addAttributes config', () => {
    const getAttributes = () => {
      const addAttributes = TemplateSelectorExtension.config.addAttributes as unknown as () => {
        templates: {
          default: unknown[]
          renderHTML: () => Record<string, unknown>
          parseHTML: () => unknown[]
        }
      }

      return addAttributes()
    }

    it('THEN should have templates attribute with empty array default', () => {
      const attrs = getAttributes()

      expect(attrs.templates.default).toEqual([])
    })

    describe('WHEN renderHTML is called', () => {
      it('THEN should return an empty object', () => {
        const attrs = getAttributes()

        expect(attrs.templates.renderHTML()).toEqual({})
      })
    })

    describe('WHEN parseHTML is called', () => {
      it('THEN should return an empty array', () => {
        const attrs = getAttributes()

        expect(attrs.templates.parseHTML()).toEqual([])
      })
    })
  })

  describe('GIVEN the parseHTML config', () => {
    it('THEN should match div elements with data-type="template-selector"', () => {
      const parseHTML = TemplateSelectorExtension.config.parseHTML as unknown as () => {
        tag: string
      }[]
      const rules = parseHTML()

      expect(rules).toEqual([{ tag: 'div[data-type="template-selector"]' }])
    })
  })

  describe('GIVEN the renderHTML config', () => {
    it('THEN should render a div with template-selector data-type', () => {
      const renderHTML = TemplateSelectorExtension.config.renderHTML as unknown as () => unknown[]
      const result = renderHTML()

      expect(result[0]).toBe('div')
      expect(result[1]).toEqual({ 'data-type': 'template-selector', style: 'display:none' })
    })
  })

  describe('GIVEN the ProseMirror plugin appendTransaction', () => {
    describe('WHEN no transactions have doc changes', () => {
      it('THEN should return null', () => {
        const appendTransaction = getAppendTransaction(mockTemplates)
        const { state } = createMockState()

        const result = appendTransaction([{ docChanged: false }], null, state)

        expect(result).toBeNull()
      })
    })

    describe('WHEN a template selector node exists and there is other text content', () => {
      it('THEN should delete the template selector node', () => {
        const appendTransaction = getAppendTransaction(mockTemplates)

        const templateNode = {
          type: { name: 'templateSelector' },
          isText: false,
          pos: 5,
          nodeSize: 2,
        }
        const textNode = {
          type: { name: 'text' },
          isText: true,
          pos: 0,
        }

        // descendants is called twice: first to find template, then to check for other content
        let callCount = 0
        const { state, mockDelete } = createMockState()

        state.doc.descendants = (
          cb: (node: { type: { name: string }; isText: boolean }, pos: number) => boolean | void,
        ) => {
          callCount++
          if (callCount === 1) {
            // First call: find templateSelector
            cb(textNode, textNode.pos)
            cb(templateNode, templateNode.pos)
          } else {
            // Second call: check for other content (skip template pos, find text)
            cb(textNode, textNode.pos)
          }
        }

        state.doc.nodeAt = () => ({ nodeSize: 2 })

        const result = appendTransaction([{ docChanged: true }], null, state)

        expect(mockDelete).toHaveBeenCalledWith(5, 7)
        expect(result).toBe(state.tr)
      })
    })

    describe('WHEN a template selector node exists but there is no other text content', () => {
      it('THEN should return null and keep the template selector', () => {
        const appendTransaction = getAppendTransaction(mockTemplates)

        let callCount = 0
        const { state } = createMockState()

        state.doc.descendants = (
          cb: (node: { type: { name: string }; isText: boolean }, pos: number) => boolean | void,
        ) => {
          callCount++
          if (callCount === 1) {
            // First call: find templateSelector
            cb({ type: { name: 'templateSelector' }, isText: false }, 5)
          } else {
            // Second call: only non-text nodes besides template
            cb({ type: { name: 'paragraph' }, isText: false }, 0)
          }
        }

        const result = appendTransaction([{ docChanged: true }], null, state)

        expect(result).toBeNull()
      })
    })

    describe('WHEN no template selector exists and editor is empty with templates configured', () => {
      it('THEN should insert a template selector node', () => {
        const appendTransaction = getAppendTransaction(mockTemplates)
        const { state, mockInsert, mockCreate } = createMockState({
          nodes: [{ type: { name: 'paragraph' }, isText: false, pos: 0 }],
          textContent: '',
        })

        const result = appendTransaction([{ docChanged: true }], null, state)

        expect(mockCreate).toHaveBeenCalledWith({ templates: mockTemplates })
        expect(mockInsert).toHaveBeenCalledWith(10, { type: 'templateSelectorNode' })
        expect(result).toBe(state.tr)
      })
    })

    describe('WHEN no template selector exists and editor has text content', () => {
      it('THEN should return null', () => {
        const appendTransaction = getAppendTransaction(mockTemplates)
        const { state } = createMockState({
          nodes: [{ type: { name: 'text' }, isText: true, pos: 0 }],
          textContent: 'Some typed text',
        })

        const result = appendTransaction([{ docChanged: true }], null, state)

        expect(result).toBeNull()
      })
    })

    describe('WHEN no template selector exists, editor is empty, but no templates are configured', () => {
      it('THEN should return null', () => {
        const appendTransaction = getAppendTransaction([])
        const { state } = createMockState({
          nodes: [{ type: { name: 'paragraph' }, isText: false, pos: 0 }],
          textContent: '',
        })

        const result = appendTransaction([{ docChanged: true }], null, state)

        expect(result).toBeNull()
      })
    })

    describe('WHEN no template selector exists, editor is empty, but node type is not in schema', () => {
      it('THEN should return null', () => {
        const appendTransaction = getAppendTransaction(mockTemplates)
        const { state } = createMockState({
          nodes: [{ type: { name: 'paragraph' }, isText: false, pos: 0 }],
          textContent: '',
          hasTemplateSelectorNodeType: false,
        })

        const result = appendTransaction([{ docChanged: true }], null, state)

        expect(result).toBeNull()
      })
    })

    describe('WHEN template selector exists, has other content, but nodeAt returns null', () => {
      it('THEN should return null', () => {
        const appendTransaction = getAppendTransaction(mockTemplates)

        let callCount = 0
        const { state } = createMockState()

        state.doc.descendants = (
          cb: (node: { type: { name: string }; isText: boolean }, pos: number) => boolean | void,
        ) => {
          callCount++
          if (callCount === 1) {
            cb({ type: { name: 'templateSelector' }, isText: false }, 5)
          } else {
            cb({ type: { name: 'text' }, isText: true }, 0)
          }
        }

        // nodeAt returns null for this edge case
        state.doc.nodeAt = () => null

        const result = appendTransaction([{ docChanged: true }], null, state)

        // hasOtherContent is true, but nodeAt returns null so no deletion happens
        // The function falls through and returns undefined (which is falsy)
        expect(result).toBeFalsy()
      })
    })
  })
})
