import { mergeAttributes, Node } from '@tiptap/core'

import type { EntityData } from '../common/RichTextEditorContext'
import { wrapInBlockWrapper } from '../extensions/BlockWrapper'

export interface DiscountBlockAttributes {
  couponId: string
  localId: string
}

export const DiscountBlockSchema = Node.create({
  name: 'discountBlock',
  group: 'block',
  atom: true,

  addOptions() {
    return {
      entities: {} as Record<string, EntityData>,
    }
  },

  addAttributes() {
    return {
      couponId: {
        default: '',
        parseHTML: (element: HTMLElement) => element.dataset.couponId ?? '',
      },
      localId: {
        default: '',
        parseHTML: (element: HTMLElement) => element.dataset.localId ?? '',
      },
    }
  },

  addStorage() {
    return {
      markdown: {
        serialize(
          state: { write: (text: string) => void; closeBlock: (node: unknown) => void },
          node: { attrs: DiscountBlockAttributes },
        ) {
          const { couponId, localId } = node.attrs

          state.write(`<!-- entity:discount:${couponId}|${localId} -->`)
          state.closeBlock(node)
        },
        parse: {
          updateDOM(element: HTMLElement) {
            element.innerHTML = element.innerHTML.replaceAll(
              /<!--\s*entity:discount:([\s\S]*?)-->/g,
              (_match: string, raw: string) => {
                const [couponId, localId] = raw.trim().split('|')

                return `<div data-type="discount-block" data-coupon-id="${couponId}" data-local-id="${localId ?? ''}"></div>`
              },
            )
          },
        },
      },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="discount-block"]' }]
  },

  renderHTML({ HTMLAttributes }) {
    const couponId: string = HTMLAttributes.couponId ?? ''
    const localId: string = HTMLAttributes.localId ?? ''

    const wrapperAttrs = mergeAttributes(HTMLAttributes, {
      'data-type': 'discount-block',
      'data-coupon-id': couponId,
      'data-local-id': localId,
      class: 'pricing-block',
    })

    const resolvedEntities: Record<string, EntityData> = this.options.entities ?? {}
    const entity = resolvedEntities[localId] ?? resolvedEntities[couponId]
    const label = entity?.name ?? (couponId ? `Coupon: ${couponId}` : 'Select a coupon')

    return wrapInBlockWrapper('discountBlock', [
      'div',
      wrapperAttrs,
      ['span', { class: 'pricing-block__label' }, label],
    ])
  },
})
