import { mergeAttributes, Node } from '@tiptap/core'

import { wrapInBlockWrapper } from './BlockWrapper'

export const LinkCard = Node.create({
  name: 'linkCard',
  group: 'block',
  atom: true,

  addAttributes() {
    return {
      href: { default: null },
    }
  },

  addStorage() {
    return {
      markdown: {
        serialize(
          state: { write: (text: string) => void; closeBlock: (node: unknown) => void },
          node: { attrs: { href: string } },
        ) {
          state.write(`[${node.attrs.href}](${node.attrs.href})`)
          state.closeBlock(node)
        },
        parse: {
          // Link cards are serialized as regular markdown links,
          // and will be parsed back as standard links
        },
      },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="link-card"]' }]
  },

  renderHTML({ HTMLAttributes }) {
    const href = String(HTMLAttributes.href ?? '')
    let domain = ''

    try {
      domain = new URL(href).hostname
    } catch {
      domain = href
    }

    return wrapInBlockWrapper('linkCard', [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'link-card',
        class: 'link-card',
      }),
      [
        'a',
        {
          href,
          target: '_blank',
          rel: 'noopener noreferrer',
          class: 'link-card__anchor',
        },
        ['span', { class: 'link-card__domain' }, domain],
        ['span', { class: 'link-card__url' }, href],
      ],
    ])
  },
})
