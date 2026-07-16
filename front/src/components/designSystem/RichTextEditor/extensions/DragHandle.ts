import { type Editor, Extension } from '@tiptap/core'
import type { Node as PmNode } from '@tiptap/pm/model'
import { NodeSelection, Plugin, PluginKey, TextSelection } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import { ALL_ICONS } from 'lago-design-system'
import { createElement } from 'react'
import { createRoot } from 'react-dom/client'

const dragHandlePluginKey = new PluginKey('dragHandle')

const renderIcon = (container: HTMLElement, icon: keyof typeof ALL_ICONS): void => {
  // Defer to avoid "triggering nested component updates from render" warning.
  // ProseMirror creates decoration widgets synchronously during React's render cycle.
  queueMicrotask(() => {
    const root = createRoot(container)

    root.render(createElement(ALL_ICONS[icon], { width: 16, height: 16 }))
  })
}

export type DragHandleStorage = {
  selectedBlock: { pos: number } | null
  hideMenu: boolean
}

const isDragHandleStorage = (value: unknown): value is DragHandleStorage =>
  value !== null && typeof value === 'object' && 'selectedBlock' in value

export const getDragHandleStorage = (editor: Editor): DragHandleStorage => {
  if ('dragHandle' in editor.storage && isDragHandleStorage(editor.storage.dragHandle)) {
    return editor.storage.dragHandle
  }

  return { selectedBlock: null, hideMenu: false }
}

export const DragHandle = Extension.create({
  name: 'dragHandle',

  addStorage() {
    return {
      /** When a table's drag handle is clicked, the table plugin converts NodeSelection
       *  to CellSelection, so BlockToolbar can't detect it. We store the selected block
       *  info here so BlockToolbar can fall back to it. */
      selectedBlock: null as { pos: number } | null,
      hideMenu: false,
    }
  },

  onSelectionUpdate() {
    const storage = getDragHandleStorage(this.editor)

    // Clear table block selection when the user moves the cursor elsewhere
    if (storage.selectedBlock) {
      const { pos } = storage.selectedBlock
      const node = this.editor.state.doc.nodeAt(pos)

      if (node?.type.name !== 'table') {
        storage.selectedBlock = null

        return
      }

      // Check if the selection is still inside this table
      const selFrom = this.editor.state.selection.from
      const tableEnd = pos + node.nodeSize

      if (selFrom < pos || selFrom > tableEnd) {
        storage.selectedBlock = null
      }
    }
  },

  addProseMirrorPlugins() {
    const editor = this.editor
    const storage = getDragHandleStorage(editor)

    function selectBlock(pos: number) {
      storage.hideMenu = false
      const node = editor.view.state.doc.nodeAt(pos)

      // For tables, avoid NodeSelection entirely — prosemirror-tables converts it
      // to CellSelection which causes a flash of selected cells. Instead, place a
      // TextSelection inside the first cell and use storage + ProseMirror-selectednode
      // class for the block-selected appearance.
      if (node?.type.name === 'table') {
        storage.selectedBlock = { pos }

        // Place cursor inside the first cell so the table remains "active"
        const $insideTable = editor.view.state.doc.resolve(pos + 1)
        const textPos = TextSelection.near($insideTable)
        const tr = editor.view.state.tr.setSelection(textPos)

        editor.view.dispatch(tr)
        editor.view.focus()

        return
      }

      storage.selectedBlock = null

      const tr = editor.view.state.tr.setSelection(NodeSelection.create(editor.view.state.doc, pos))

      editor.view.dispatch(tr)
      editor.view.focus()
    }

    function createHandleElement(pos: number): HTMLElement {
      const group = document.createElement('div')

      group.className = 'block-handle-group'
      group.contentEditable = 'false'

      // Plus button — opens slash command menu
      const plusButton = document.createElement('div')

      plusButton.className = 'block-handle-button block-handle-plus'
      const plusIconContainer = document.createElement('span')

      plusButton.appendChild(plusIconContainer)
      renderIcon(plusIconContainer, 'plus')

      plusButton.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()

        if ('slashCommands' in editor.storage) {
          const { triggerMenu } = editor.storage.slashCommands as {
            triggerMenu?: (clientRect: () => DOMRect) => void
          }

          triggerMenu?.(() => plusButton.getBoundingClientRect())
        }
      })

      // Grip button — drag handle and block selection
      const gripButton = document.createElement('div')

      gripButton.className = 'block-handle-button block-handle-grip'
      gripButton.draggable = true
      const gripIconContainer = document.createElement('span')

      gripButton.appendChild(gripIconContainer)
      renderIcon(gripIconContainer, 'double-dots-vertical')

      gripButton.addEventListener('dragstart', (e) => {
        selectBlock(pos)

        editor.view.dragging = {
          slice: editor.view.state.selection.content(),
          move: true,
        }

        if (e.dataTransfer) {
          e.dataTransfer.effectAllowed = 'move'
        }

        const blockDom = editor.view.nodeDOM(pos)

        if (blockDom instanceof HTMLElement && e.dataTransfer) {
          e.dataTransfer.setDragImage(blockDom, 0, 0)
        }

        editor.view.dom.classList.add('is-dragging')
      })

      gripButton.addEventListener('dragend', () => {
        editor.view.dom.classList.remove('is-dragging')
      })

      gripButton.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()
        selectBlock(pos)
      })

      group.appendChild(plusButton)
      group.appendChild(gripButton)

      return group
    }

    function buildDecorations(doc: PmNode): DecorationSet {
      const decorations: Decoration[] = []

      doc.forEach((node, pos) => {
        decorations.push(
          Decoration.widget(pos, () => createHandleElement(pos), {
            side: -1,
            key: `drag-handle-${pos}`,
            ignoreSelection: true,
          }),
        )
      })

      return DecorationSet.create(doc, decorations)
    }

    return [
      new Plugin({
        key: dragHandlePluginKey,
        view(editorView) {
          const handleOutsideClick = (event: MouseEvent) => {
            const target = event.target as HTMLElement

            // Editor-owned floating UI (e.g. the block toolbar's color picker)
            // renders in a Popper portaled to document.body — outside
            // .rich-text-editor. Clicking it must not count as an outside click,
            // or the active block NodeSelection would be cleared on mousedown
            // before the toolbar command runs, so the color is never applied
            // (LAGO-1671).
            if (target.closest('[data-rte-preserve-selection]')) return

            const editorContainer = editorView.dom.closest('.rich-text-editor')

            if (!editorContainer || editorContainer.contains(target)) return

            const { selection } = editorView.state
            const isNodeSelected = selection instanceof NodeSelection
            const isTableSelected = storage.selectedBlock !== null

            if (!isNodeSelected && !isTableSelected) return

            storage.selectedBlock = null
            storage.hideMenu = false

            const $pos = editorView.state.doc.resolve(
              Math.min(selection.from, editorView.state.doc.content.size),
            )
            const textSel = TextSelection.near($pos)

            editorView.dispatch(editorView.state.tr.setSelection(textSel))
          }

          document.addEventListener('mousedown', handleOutsideClick)

          return {
            destroy() {
              document.removeEventListener('mousedown', handleOutsideClick)
            },
          }
        },
        state: {
          init(_, state) {
            return buildDecorations(state.doc)
          },
          apply(tr, oldSet) {
            if (!tr.docChanged) return oldSet

            // Rebuild when block structure changes: different count or different
            // node types (e.g. paragraph → bulletList). For in-block edits
            // (typing, formatting) map existing decorations.
            const oldDoc = tr.before
            const newDoc = tr.doc

            if (oldDoc.childCount === newDoc.childCount) {
              let structureChanged = false

              for (let i = 0; i < newDoc.childCount; i++) {
                const oldChild = oldDoc.child(i)
                const newChild = newDoc.child(i)

                if (
                  oldChild.type.name !== newChild.type.name ||
                  oldChild.attrs !== newChild.attrs
                ) {
                  structureChanged = true
                  break
                }
              }

              if (!structureChanged) {
                return oldSet.map(tr.mapping, tr.doc)
              }
            }

            return buildDecorations(newDoc)
          },
        },
        props: {
          decorations(state) {
            const handleDecos = dragHandlePluginKey.getState(state) as DecorationSet

            // Add table block-selected decoration from storage, but only while
            // the selection is still inside the table.
            if (storage.selectedBlock) {
              const { pos } = storage.selectedBlock
              const node = state.doc.nodeAt(pos)

              if (node?.type.name === 'table') {
                const selFrom = state.selection.from
                const tableEnd = pos + node.nodeSize

                if (selFrom >= pos && selFrom <= tableEnd) {
                  const tableDeco = Decoration.node(pos, pos + node.nodeSize, {
                    class: 'is-block-selected',
                  })

                  return handleDecos.add(state.doc, [tableDeco])
                }
              }
            }

            return handleDecos
          },
          handleClick() {
            // User clicked inside the editor content (not on a drag handle).
            // Clear the table-selected-via-drag-handle flag.
            storage.selectedBlock = null

            return false // don't consume the event
          },
          handleKeyDown(view, event) {
            if (event.key !== 'Escape') return false

            const { selection } = view.state
            const isNodeSelected = selection instanceof NodeSelection
            const isTableSelected = storage.selectedBlock !== null

            if (!isNodeSelected && !isTableSelected) return false

            // First ESC: hide the block menu (BlockToolbar)
            if (!storage.hideMenu) {
              storage.hideMenu = true
              view.dispatch(view.state.tr.setMeta('hideBlockMenu', true))

              return true
            }

            // Second ESC: deselect the block
            storage.hideMenu = false

            if (isNodeSelected) {
              const $pos = view.state.doc.resolve(selection.to)
              const textSel = TextSelection.near($pos)

              view.dispatch(view.state.tr.setSelection(textSel))
            } else if (isTableSelected) {
              storage.selectedBlock = null
              view.dispatch(view.state.tr.setMeta('clearBlockSelection', true))
            }

            return true
          },
        },
      }),
    ]
  },
})
