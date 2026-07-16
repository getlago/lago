import { mergeAttributes } from '@tiptap/core'
import Image, { type ImageOptions } from '@tiptap/extension-image'
import type { DOMOutputSpec } from '@tiptap/pm/model'

import { wrapInBlockWrapper } from './BlockWrapper'
import { resolveImageSrc } from './resolveImageSrc'

export interface QuoteImageOptions extends ImageOptions {
  images: Record<string, string>
}

/**
 * Custom image node. Keeps the built-in TipTap `image` name + default markdown
 * round-trip (content stores `![](src)` where src is a blob id or legacy URL).
 * `renderHTML` resolves `src` via the `images` option (headless/getHTML parity);
 * the live editor + preview + PDF resolve via the React NodeView (see QuoteImageNodeView),
 * which reads the images map from context so freshly uploaded images resolve immediately.
 */
export const QuoteImageSchema = Image.extend<QuoteImageOptions>({
  addOptions() {
    return {
      ...(this as unknown as { parent: () => ImageOptions }).parent(),
      images: {} as Record<string, string>,
    }
  },

  renderHTML({ node, HTMLAttributes }) {
    const images = (this.options as { images?: Record<string, string> }).images ?? {}
    const resolved = resolveImageSrc(node.attrs.src as string | null, images)

    const inner: DOMOutputSpec = resolved
      ? ['img', mergeAttributes(HTMLAttributes, { src: resolved })]
      : ['span', { 'data-quote-image-unresolved': 'true' }]

    return wrapInBlockWrapper('image', inner)
  },
})
