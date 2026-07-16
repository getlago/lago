import { Extension } from '@tiptap/core'
import { NodeSelection } from '@tiptap/pm/state'
import { Editor, Range, ReactRenderer } from '@tiptap/react'
import Suggestion, { SuggestionKeyDownProps, SuggestionProps } from '@tiptap/suggestion'
import tippy, { type Instance as TippyInstance } from 'tippy.js'

import type { OnDiscountCommand, OnPricingCommand } from '../common/RichTextEditorContext'
import { SlashMenu, type SlashMenuRef } from '../SlashMenu/SlashMenu'

export interface SlashCommandItem {
  title: string
  description: string
  command: (editor: Editor) => void
  disabled?: boolean
}

interface SlashCommandDefinition {
  titleKey: string
  descriptionKey: string
  command: (editor: Editor) => void
}

export const slashCommandDefinitions: SlashCommandDefinition[] = [
  {
    titleKey: 'text_1774281559656dn2u208gh80',
    descriptionKey: 'text_1774281559656pla0xamsvmf',
    command: (editor) => editor.chain().focus().toggleHeading({ level: 1 }).run(),
  },
  {
    titleKey: 'text_1774281559657ec0exeaqqd3',
    descriptionKey: 'text_1774281559657q7h8pu6455p',
    command: (editor) => editor.chain().focus().toggleHeading({ level: 2 }).run(),
  },
  {
    titleKey: 'text_1774281559657t0kkn628zdy',
    descriptionKey: 'text_1774281559657o48ilt0rq5y',
    command: (editor) => editor.chain().focus().toggleHeading({ level: 3 }).run(),
  },
  {
    titleKey: 'text_1774281559657cbz20fzcjka',
    descriptionKey: 'text_17742815596575m8mqwrg1qy',
    command: (editor) => editor.chain().focus().toggleBulletList().run(),
  },
  {
    titleKey: 'text_1774281559657yc3z031hm6x',
    descriptionKey: 'text_1774281559657y9saycc2aev',
    command: (editor) =>
      editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(),
  },
  {
    titleKey: 'text_1774281559657l4kkx9ws4mz',
    descriptionKey: 'text_1774281559657qdknwsvn5ka',
    command: (editor) => editor.chain().focus().toggleCodeBlock().run(),
  },
]

export const SlashCommands = Extension.create({
  name: 'slashCommands',

  addStorage() {
    return {
      triggerMenu: null as ((clientRect: () => DOMRect) => void) | null,
    }
  },

  addOptions() {
    return {
      translate: ((key: string) => key) as (key: string) => string,
      onPricingCommand: undefined as OnPricingCommand | undefined,
      isPricingDisabled: undefined as (() => boolean) | undefined,
      onDiscountCommand: undefined as OnDiscountCommand | undefined,
      suggestion: {
        char: '/',
        command: ({
          editor,
          range,
          props,
        }: {
          editor: Editor
          range: Range
          props: SlashCommandItem
        }) => {
          editor.chain().focus().deleteRange(range).run()
          props.command(editor)
        },
        render: () => {
          let renderer: ReactRenderer<SlashMenuRef>
          let popup: TippyInstance[]

          return {
            onStart: (props: SuggestionProps<SlashCommandItem>) => {
              renderer = new ReactRenderer(SlashMenu, {
                props,
                editor: props.editor,
              })

              popup = tippy('body', {
                getReferenceClientRect: () => props.clientRect?.() ?? new DOMRect(),
                appendTo: () => document.body,
                content: renderer.element,
                showOnCreate: true,
                interactive: true,
                trigger: 'manual',
                placement: 'bottom-start',
              })
            },
            onUpdate: (props: SuggestionProps<SlashCommandItem>) => {
              renderer.updateProps(props)

              popup[0].setProps({
                getReferenceClientRect: () => props.clientRect?.() ?? new DOMRect(),
              })
            },
            onKeyDown: (props: SuggestionKeyDownProps) => {
              if (props.event.key === 'Escape') {
                popup[0].hide()
                return true
              }

              return renderer.ref?.onKeyDown(props) ?? false
            },
            onExit: () => {
              popup[0].destroy()
              renderer.destroy()
            },
          }
        },
      },
    }
  },

  addProseMirrorPlugins() {
    const { translate, onPricingCommand, isPricingDisabled, onDiscountCommand } = this.options

    const resolvedItems: SlashCommandItem[] = slashCommandDefinitions.map((def) => ({
      title: translate(def.titleKey),
      description: translate(def.descriptionKey),
      command: def.command,
    }))

    let pricingItem: SlashCommandItem | undefined

    if (onPricingCommand) {
      pricingItem = {
        title: translate('text_1779802343219a1cl5ckvtrn'),
        description: translate('text_1779802343219rul1jvs7170'),
        command: (editor) => {
          onPricingCommand({
            onSave: (attrs) => {
              editor.chain().focus().insertContent({ type: 'pricingBlock', attrs }).run()

              // After inserting an atom node, ProseMirror may create a NodeSelection
              // which triggers the BlockToolbar overlay. Move to a text selection.
              const { selection } = editor.state

              if (selection instanceof NodeSelection) {
                editor.commands.setTextSelection(selection.from + selection.node.nodeSize)
              }
            },
          })
        },
      }
      resolvedItems.push(pricingItem)
    }

    if (onDiscountCommand) {
      const discountItem: SlashCommandItem = {
        title: translate('text_1782889379261hdcd0jhzdm6'),
        description: translate('text_178288937926153opd9g5cwg'),
        command: (editor) => {
          onDiscountCommand({
            onSave: (attrs) => {
              editor.chain().focus().insertContent({ type: 'discountBlock', attrs }).run()

              // After inserting an atom node, ProseMirror may create a NodeSelection
              // which triggers the BlockToolbar overlay. Move to a text selection.
              const { selection } = editor.state

              if (selection instanceof NodeSelection) {
                editor.commands.setTextSelection(selection.from + selection.node.nodeSize)
              }
            },
          })
        },
      }

      resolvedItems.push(discountItem)
    }

    const editorRef = this.editor

    this.storage.triggerMenu = (clientRect: () => DOMRect) => {
      let destroyed = false

      const destroy = () => {
        if (destroyed) return
        destroyed = true
        popup[0]?.destroy()
        renderer?.destroy()
        document.removeEventListener('keydown', handleKeyDown, true)
        document.removeEventListener('mousedown', handleClickOutside, true)
      }

      const handleKeyDown = (event: KeyboardEvent) => {
        if (event.key === 'Escape') {
          event.preventDefault()
          destroy()

          return
        }

        const handled = renderer.ref?.onKeyDown({ event } as SuggestionKeyDownProps)

        if (handled) {
          event.preventDefault()
          event.stopPropagation()
        }
      }

      const handleClickOutside = (event: MouseEvent) => {
        if (!renderer.element.contains(event.target as Node)) {
          destroy()
        }
      }

      const renderer = new ReactRenderer(SlashMenu, {
        props: {
          items: resolvedItems.map((item) => ({
            ...item,
            disabled: item === pricingItem ? (isPricingDisabled?.() ?? false) : false,
          })),
          command: (item: SlashCommandItem) => {
            if (item.disabled) return
            item.command(editorRef)
            destroy()
          },
        },
        editor: editorRef,
      })

      const popup = tippy('body', {
        getReferenceClientRect: clientRect,
        appendTo: () => document.body,
        content: renderer.element,
        showOnCreate: true,
        interactive: true,
        trigger: 'manual',
        placement: 'bottom-start',
      })

      document.addEventListener('keydown', handleKeyDown, true)
      document.addEventListener('mousedown', handleClickOutside, true)
    }

    return [
      Suggestion({
        editor: this.editor,
        ...this.options.suggestion,
        items: ({ query }: { query: string }) => {
          return resolvedItems
            .filter((item) => item.title.toLowerCase().includes(query.toLowerCase()))
            .map((item) => ({
              ...item,
              disabled: item === pricingItem ? (isPricingDisabled?.() ?? false) : false,
            }))
        },
      }),
    ]
  },
})
