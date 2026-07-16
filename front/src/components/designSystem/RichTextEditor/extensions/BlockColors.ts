import { type Editor, Extension } from '@tiptap/core'
import { DOMSerializer, type Node as PmNode } from '@tiptap/pm/model'

import { resolveTopLevelBlock } from './BlockUtils'

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    blockColors: {
      setBlockBackgroundColor: (color: string | null) => ReturnType
      setBlockTextColor: (color: string | null) => ReturnType
    }
  }
}

const BLOCK_TYPES = [
  'paragraph',
  'heading',
  'bulletList',
  'orderedList',
  'codeBlock',
  'table',
  'image',
  'pricingBlock',
  'linkCard',
  'blockquote',
]

// -- Markdown serialization helpers for color-aware blocks ---------------------

interface MarkdownSerializerState {
  write: (s: string) => void
  closeBlock: (n: unknown) => void
  renderInline: (node: PmNode) => void
  renderList: (node: PmNode, delim: string, firstDelim: (index: number) => string) => void
  repeat: (s: string, n: number) => string
}

type SerializeFn = (
  this: { editor: Editor },
  state: MarkdownSerializerState,
  node: PmNode,
  parent: PmNode,
  index: number,
) => void

/**
 * Wraps a default markdown serializer so that blocks with `backgroundColor` or
 * `textColor` are emitted as full HTML (via DOMSerializer), while plain blocks
 * fall through to the original markdown output.
 */
export const createColorAwareSerialize = (defaultSerialize: SerializeFn): SerializeFn =>
  function (this: { editor: Editor }, state, node, parent, index) {
    if (node.attrs.backgroundColor || node.attrs.textColor) {
      const domSerializer = DOMSerializer.fromSchema(this.editor.schema)
      const dom = domSerializer.serializeNode(node) as HTMLElement

      state.write(dom.outerHTML)
      state.closeBlock(node)
    } else {
      defaultSerialize.call(this, state, node, parent, index)
    }
  }

// -- Extension ----------------------------------------------------------------

export const BlockColors = Extension.create({
  name: 'blockColors',

  addGlobalAttributes() {
    return [
      {
        types: BLOCK_TYPES,
        attributes: {
          backgroundColor: {
            default: null,
            parseHTML: (element) => element.style.backgroundColor || null,
            renderHTML: (attributes) => {
              if (!attributes.backgroundColor && !attributes.textColor) return {}

              const parts: string[] = []

              if (attributes.backgroundColor) {
                parts.push(`background-color: ${attributes.backgroundColor}`)
              }

              if (attributes.textColor) {
                parts.push(`color: ${attributes.textColor}`)
              }

              return parts.length > 0 ? { style: `${parts.join('; ')};` } : {}
            },
          },
          textColor: {
            default: null,
            parseHTML: (element) => element.style.color || null,
            // Style rendering is handled by backgroundColor's renderHTML to
            // produce a single merged style string, avoiding TipTap attribute
            // merge conflicts.
            renderHTML: () => ({}),
          },
        },
      },
    ]
  },

  addCommands() {
    return {
      setBlockBackgroundColor:
        (color) =>
        ({ state, dispatch }) => {
          const block = resolveTopLevelBlock(state)

          if (!block) return false

          if (dispatch) {
            const attrs = { ...block.node.attrs, backgroundColor: color }

            dispatch(state.tr.setNodeMarkup(block.pos, undefined, attrs))
          }

          return true
        },

      setBlockTextColor:
        (color) =>
        ({ state, dispatch }) => {
          const block = resolveTopLevelBlock(state)

          if (!block) return false

          if (dispatch) {
            const attrs = { ...block.node.attrs, textColor: color }

            dispatch(state.tr.setNodeMarkup(block.pos, undefined, attrs))
          }

          return true
        },
    }
  },
})
