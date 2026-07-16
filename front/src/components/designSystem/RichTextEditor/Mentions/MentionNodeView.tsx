import { NodeViewProps, NodeViewWrapper } from '@tiptap/react'

import { useRichTextEditorContext } from '../common/RichTextEditorContext'

export const MENTION_NODE_VIEW_TEST_ID = 'mention-node-view'

export const MentionNodeView = ({ node }: NodeViewProps) => {
  const { mode, mentionValues } = useRichTextEditorContext()
  const id = String(node.attrs.id ?? '')
  const label = String(node.attrs.label ?? id)
  const resolvedValue = mentionValues[id]

  // In preview/PDF (read-only), substitute the resolved value — including an
  // empty or null value, which renders nothing so empty variables disappear
  // instead of showing their @label. Resolution is keyed on the variable being
  // present in mentionValues: an absent id (unknown variable) still falls back
  // to @label. While authoring (edit mode) we always keep the @label token so
  // the variable stays visible/editable. This mirrors the schema renderHTML,
  // and is the rendering path that actually reaches preview and the PDF
  // (serialized from the live NodeView DOM, not getHTML()).
  const isResolved = mode === 'preview' && Object.hasOwn(mentionValues, id)

  if (isResolved) {
    return (
      <NodeViewWrapper
        as="span"
        className="variable-mention variable-mention--resolved"
        data-test={MENTION_NODE_VIEW_TEST_ID}
      >
        {resolvedValue}
      </NodeViewWrapper>
    )
  }

  return (
    <NodeViewWrapper as="span" className="variable-mention" data-test={MENTION_NODE_VIEW_TEST_ID}>
      @{label}
    </NodeViewWrapper>
  )
}
