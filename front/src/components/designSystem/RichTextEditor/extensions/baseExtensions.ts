import type { Extensions } from '@tiptap/core'
import Blockquote from '@tiptap/extension-blockquote'
import BulletList from '@tiptap/extension-bullet-list'
import CodeBlock from '@tiptap/extension-code-block'
import Color from '@tiptap/extension-color'
import Heading from '@tiptap/extension-heading'
import Highlight from '@tiptap/extension-highlight'
import Link from '@tiptap/extension-link'
import OrderedList from '@tiptap/extension-ordered-list'
import Paragraph from '@tiptap/extension-paragraph'
import Subscript from '@tiptap/extension-subscript'
import Superscript from '@tiptap/extension-superscript'
import { Table } from '@tiptap/extension-table'
import TableCell from '@tiptap/extension-table-cell'
import TableHeader from '@tiptap/extension-table-header'
import TableRow from '@tiptap/extension-table-row'
import TextAlign from '@tiptap/extension-text-align'
import { TextStyle } from '@tiptap/extension-text-style'
import Underline from '@tiptap/extension-underline'
import type { DOMOutputSpec, Node as PmNode } from '@tiptap/pm/model'
import StarterKit from '@tiptap/starter-kit'
import { Markdown } from 'tiptap-markdown'

import { BlockColors, createColorAwareSerialize } from './BlockColors'
import { BlockMove } from './BlockMove'
import { wrapInBlockWrapper } from './BlockWrapper'
import { LinkCard } from './LinkCard'
import { ColorAwareTableView } from './TableCommands'

// -- Color-aware markdown serialization ---------------------------------------
// When a block has backgroundColor or textColor, it is emitted as HTML so the
// colors survive the markdown round-trip.

const ColorAwareParagraph = Paragraph.extend({
  addStorage() {
    return {
      markdown: {
        serialize: createColorAwareSerialize(function (state, node) {
          state.renderInline(node)
          state.closeBlock(node)
        }),
        parse: {},
      },
    }
  },
})

const ColorAwareHeading = Heading.extend({
  addStorage() {
    return {
      markdown: {
        serialize: createColorAwareSerialize(function (state, node) {
          state.write(`${state.repeat('#', (node as PmNode).attrs.level as number)} `)
          state.renderInline(node)
          state.closeBlock(node)
        }),
        parse: {},
      },
    }
  },
})

const ColorAwareBulletList = BulletList.extend({
  addStorage() {
    return {
      markdown: {
        serialize: createColorAwareSerialize(function (state, node) {
          state.renderList(node, '  ', () => '- ')
        }),
        parse: {},
      },
    }
  },
})

const ColorAwareOrderedList = OrderedList.extend({
  addStorage() {
    return {
      markdown: {
        serialize: createColorAwareSerialize(function (_state, node, parent, index) {
          const state = _state
          const start = (node.attrs.start as number) || 1
          const maxW = String(start + node.childCount - 1).length
          const space = state.repeat(' ', maxW + 2)

          let adjacentIndex = 0

          for (; index - adjacentIndex > 0; adjacentIndex++) {
            if (parent.child(index - adjacentIndex - 1).type.name !== node.type.name) {
              break
            }
          }

          const separator = adjacentIndex % 2 ? ') ' : '. '

          state.renderList(node, space, (i: number) => {
            const nStr = String(start + i)

            return `${state.repeat(' ', maxW - nStr.length)}${nStr}${separator}`
          })
        }),
        parse: {},
      },
    }
  },
})

// -- Helpers ------------------------------------------------------------------

/**
 * Applies backgroundColor/textColor inline styles directly to a DOMOutputSpec
 * element (e.g. `<ul>` or `<ol>`). This is needed for lists because TipTap's
 * addGlobalAttributes merges styles onto the outermost wrapper (`<div class="spacer">`),
 * which places the background behind the spacer padding — outside the list markers.
 */
const applyBlockColorAttrs = (
  spec: DOMOutputSpec,
  attrs: Record<string, unknown>,
): DOMOutputSpec => {
  const { backgroundColor, textColor } = attrs

  if (!backgroundColor && !textColor) return spec

  const parts: string[] = []

  if (typeof backgroundColor === 'string') parts.push(`background-color: ${backgroundColor}`)
  if (typeof textColor === 'string') parts.push(`color: ${textColor}`)

  const style = `${parts.join('; ')};`

  if (!Array.isArray(spec)) return spec

  const [tag, ...rest] = spec

  if (rest.length > 0 && typeof rest[0] === 'object' && !Array.isArray(rest[0])) {
    const existingAttrs = rest[0] as Record<string, unknown>

    return [tag, { ...existingAttrs, style }, ...rest.slice(1)] as unknown as DOMOutputSpec
  }

  return [tag, { style }, ...rest] as unknown as DOMOutputSpec
}

// -- Block wrappers -----------------------------------------------------------
// Every top-level block is wrapped in <div class="spacer"><div class="block-wrapper">
// to provide consistent spacing, selection targets, and future extensibility.
const WrappedParagraph = ColorAwareParagraph.extend({
  renderHTML(props) {
    const inner = this.parent ? this.parent(props) : (['p', 0] satisfies DOMOutputSpec)

    return wrapInBlockWrapper('paragraph', inner)
  },
})

const WrappedHeading = ColorAwareHeading.extend({
  renderHTML(props) {
    const inner = this.parent ? this.parent(props) : (['h1', 0] satisfies DOMOutputSpec)
    const level = (props.node.attrs.level as number) || 1

    return wrapInBlockWrapper(`heading-${level}`, inner)
  },
})

const WrappedBulletList = ColorAwareBulletList.extend({
  renderHTML(props) {
    const inner = this.parent ? this.parent(props) : (['ul', 0] satisfies DOMOutputSpec)

    return wrapInBlockWrapper('bulletList', applyBlockColorAttrs(inner, props.node.attrs))
  },
})

const WrappedOrderedList = ColorAwareOrderedList.extend({
  renderHTML(props) {
    const inner = this.parent ? this.parent(props) : (['ol', 0] satisfies DOMOutputSpec)

    return wrapInBlockWrapper('orderedList', applyBlockColorAttrs(inner, props.node.attrs))
  },
})

const WrappedBlockquote = Blockquote.extend({
  renderHTML(props) {
    const inner = this.parent ? this.parent(props) : (['blockquote', 0] satisfies DOMOutputSpec)

    return wrapInBlockWrapper('blockquote', inner)
  },
})

const WrappedCodeBlock = CodeBlock.extend({
  renderHTML(props) {
    const inner = this.parent ? this.parent(props) : (['pre', ['code', 0]] satisfies DOMOutputSpec)

    return wrapInBlockWrapper('codeBlock', inner)
  },
})

// -- Extension list -----------------------------------------------------------

interface BaseExtensionsOptions {
  tableResizable?: boolean
}

/**
 * Extensions shared between the interactive editor and headless consumers.
 *
 * Does NOT include Mention or PricingBlock — those require different configurations
 * (node views, suggestion) depending on the consumer. Each consumer adds them separately
 * using MentionSchema/PricingBlockSchema from their respective .schema.ts files.
 */
export const getBaseExtensions = (options?: BaseExtensionsOptions): Extensions => [
  StarterKit.configure({
    link: false,
    underline: false,
    dropcursor: { color: '#dbeafe', width: 4 }, // blue-100
    paragraph: false,
    heading: false,
    bulletList: false,
    orderedList: false,
    blockquote: false,
    codeBlock: false,
  }),
  WrappedParagraph,
  WrappedHeading,
  WrappedBulletList,
  WrappedOrderedList,
  WrappedBlockquote,
  WrappedCodeBlock,
  Link.configure({ openOnClick: false }),
  Underline,
  Superscript,
  Subscript,
  TextStyle,
  Color,
  Highlight.configure({ multicolor: true }),
  TextAlign.configure({ types: ['heading', 'paragraph'] }),
  Table.configure({
    resizable: options?.tableResizable ?? false,
    View: ColorAwareTableView,
  }),
  TableRow,
  TableCell,
  TableHeader,
  LinkCard,
  BlockColors,
  BlockMove,
  Markdown.configure({ html: true, transformPastedText: true }),
]
