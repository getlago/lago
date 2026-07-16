import { Extension } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { ReactRenderer } from '@tiptap/react'
import tippy, { type Instance as TippyInstance } from 'tippy.js'

import { LinkPastePopup } from '../popups/LinkPastePopup'

const URL_REGEX = /^https?:\/\/\S+$/

const linkPasteHandlerKey = new PluginKey('linkPasteHandler')

export const LinkPasteHandler = Extension.create({
  name: 'linkPasteHandler',

  addProseMirrorPlugins() {
    const editor = this.editor

    return [
      new Plugin({
        key: linkPasteHandlerKey,

        props: {
          handlePaste(_view, event) {
            const text = event.clipboardData?.getData('text/plain')?.trim()

            if (!text || !URL_REGEX.test(text)) {
              return false
            }

            // Insert the URL as a link
            editor
              .chain()
              .focus()
              .insertContent({
                type: 'text',
                text,
                marks: [{ type: 'link', attrs: { href: text } }],
              })
              .run()

            // Find the DOM element of the just-inserted link to anchor the popup
            const { from } = editor.state.selection
            const linkStart = from - text.length
            const linkEnd = from

            // Small delay to let the DOM update, then show the popup
            requestAnimationFrame(() => {
              const coords = editor.view.coordsAtPos(linkStart)

              let renderer: ReactRenderer | null = null
              let popup: TippyInstance[] | null = null

              const cleanup = () => {
                popup?.[0]?.destroy()
                renderer?.destroy()
                popup = null
                renderer = null
              }

              renderer = new ReactRenderer(LinkPastePopup, {
                props: {
                  url: text,
                  onDisplayAsCard: () => {
                    editor
                      .chain()
                      .focus()
                      .deleteRange({ from: linkStart, to: linkEnd })
                      .insertContentAt(linkStart, {
                        type: 'linkCard',
                        attrs: { href: text },
                      })
                      .run()
                    cleanup()
                  },
                  onKeepAsText: () => {
                    cleanup()
                  },
                },
                editor,
              })

              popup = tippy('body', {
                getReferenceClientRect: () =>
                  new DOMRect(coords.left, coords.top, 0, coords.bottom - coords.top),
                appendTo: () => document.body,
                content: renderer.element,
                showOnCreate: true,
                interactive: true,
                trigger: 'manual',
                placement: 'bottom-start',
              })

              // Close popup when user clicks elsewhere in the editor
              const handleClick = (e: MouseEvent) => {
                if (
                  renderer?.element &&
                  e.target instanceof Node &&
                  !renderer.element.contains(e.target)
                ) {
                  cleanup()
                  document.removeEventListener('click', handleClick)
                }
              }

              document.addEventListener('click', handleClick)
            })

            // We handled the paste
            return true
          },
        },
      }),
    ]
  },
})
