import { Node } from '@tiptap/core'
import type { Node as PmNode } from '@tiptap/pm/model'
import { type EditorState, Plugin, PluginKey, type Transaction } from '@tiptap/pm/state'
import { ReactNodeViewRenderer } from '@tiptap/react'

import { TemplateSelectorView } from '../TemplateSelector/TemplateSelectorView'
import type { EditorTemplate } from '../TemplateSelector/types'

const templateSelectorPluginKey = new PluginKey('templateSelectorAutoRemove')

export const TemplateSelectorExtension = Node.create({
  name: 'templateSelector',
  group: 'block',
  atom: true,
  selectable: false,
  draggable: false,

  addOptions() {
    return {
      templates: [] as EditorTemplate[],
    }
  },

  addAttributes() {
    return {
      templates: {
        default: [],
        renderHTML: () => ({}),
        parseHTML: () => [],
      },
    }
  },

  addNodeView() {
    return ReactNodeViewRenderer(TemplateSelectorView)
  },

  parseHTML() {
    return [{ tag: 'div[data-type="template-selector"]' }]
  },

  renderHTML() {
    return ['div', { 'data-type': 'template-selector', style: 'display:none' }]
  },

  addProseMirrorPlugins() {
    const nodeName = this.name
    const templates = this.options.templates

    return [
      new Plugin({
        key: templateSelectorPluginKey,
        appendTransaction(
          transactions: readonly Transaction[],
          _oldState: EditorState,
          newState: EditorState,
        ) {
          const hasDocChanged = transactions.some((tr: Transaction) => tr.docChanged)

          if (!hasDocChanged) return null

          let templatePos: number | null = null

          newState.doc.descendants((node: PmNode, pos: number) => {
            if (node.type.name === nodeName) {
              templatePos = pos
              return false
            }
          })

          // Template selector exists — check if we need to remove it
          if (templatePos !== null) {
            let hasOtherContent = false

            newState.doc.descendants((node: PmNode, pos: number) => {
              if (pos === templatePos) return false
              if (node.isText) {
                hasOtherContent = true
                return false
              }
            })

            if (hasOtherContent) {
              const tr = newState.tr
              const node = newState.doc.nodeAt(templatePos)

              if (node) {
                tr.delete(templatePos, templatePos + node.nodeSize)
                return tr
              }
            }

            return null
          }

          // No template selector — check if editor is empty and re-insert
          if (templates.length === 0) return null

          // Check if the doc has no text content at all
          if (newState.doc.textContent.length > 0) return null

          const templateNodeType = newState.schema.nodes[nodeName]

          if (!templateNodeType) return null

          const templateNode = templateNodeType.create({ templates })
          const tr = newState.tr

          // Insert template selector node at the end of the document
          tr.insert(newState.doc.content.size, templateNode)
          return tr
        },
      }),
    ]
  },
})
