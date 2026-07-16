import { NodeViewProps, NodeViewWrapper } from '@tiptap/react'
import { Icon } from 'lago-design-system'

import { Button } from '~/components/designSystem/Button'

import type { EditorTemplate } from './types'

export const TEMPLATE_SELECTOR_VIEW_TEST_ID = 'template-selector-view'
export const TEMPLATE_SELECTOR_ITEM_TEST_ID = 'template-selector-item'

export const TemplateSelectorView = ({ editor, node }: NodeViewProps) => {
  const templates: EditorTemplate[] = node.attrs.templates ?? []

  const handleSelect = (template: EditorTemplate) => {
    editor.chain().focus().setContent(template.content).run()
  }

  return (
    <NodeViewWrapper>
      <div className="template-list" data-test={TEMPLATE_SELECTOR_VIEW_TEST_ID}>
        {templates.map((template) => (
          <Button
            key={template.id}
            className="template-item gap-2"
            data-test={`${TEMPLATE_SELECTOR_ITEM_TEST_ID}-${template.id}`}
            variant="quaternary"
            align="left"
            onClick={() => handleSelect(template)}
          >
            <Icon name="document" size="small" />
            <span className="template-item__name">{template.name}</span>
          </Button>
        ))}
      </div>
    </NodeViewWrapper>
  )
}
