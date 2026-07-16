import { NodeViewProps, NodeViewWrapper } from '@tiptap/react'

import { resolveImageSrc } from './resolveImageSrc'

import { useRichTextEditorContext } from '../common/RichTextEditorContext'

export const QUOTE_IMAGE_NODE_VIEW_TEST_ID = 'quote-image-node-view'

/**
 * Renders a resolved <img> for a blob id / legacy URL, or nothing for an
 * unresolved id. Reproduces the standard spacer/block-wrapper DOM so the drag
 * handle keeps working. Reads the live `images` map from context so an image
 * uploaded during this editing session resolves without recreating the editor.
 */
export const QuoteImageNodeView = ({ node }: NodeViewProps) => {
  const { images } = useRichTextEditorContext()
  const resolved = resolveImageSrc(String(node.attrs.src ?? ''), images)

  return (
    <NodeViewWrapper as="div" className="spacer" data-type="image">
      <div className="block-wrapper" data-test={QUOTE_IMAGE_NODE_VIEW_TEST_ID}>
        {resolved && <img src={resolved} alt={String(node.attrs.alt ?? '')} />}
      </div>
    </NodeViewWrapper>
  )
}
