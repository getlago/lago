import { ReactNodeViewRenderer } from '@tiptap/react'

import { DiscountBlockSchema } from './DiscountBlock.schema'

import { DiscountBlockView } from '../DiscountBlock/DiscountBlockView'

export type { DiscountBlockAttributes } from './DiscountBlock.schema'

export const DiscountBlock = DiscountBlockSchema.extend({
  addNodeView() {
    return ReactNodeViewRenderer(DiscountBlockView)
  },
})
