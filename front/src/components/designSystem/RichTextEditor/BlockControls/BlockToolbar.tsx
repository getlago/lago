import type { Editor } from '@tiptap/core'
import { NodeSelection } from '@tiptap/pm/state'
import { useEditorState } from '@tiptap/react'
import { useCallback, useEffect, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

import ColorPicker from './ColorPicker'

import { getDragHandleStorage } from '../extensions/DragHandle'

export const BLOCK_TOOLBAR_TEST_ID = 'block-toolbar'
export const BLOCK_TOOLBAR_MOVE_UP_BUTTON_TEST_ID = 'block-toolbar-move-up-button'
export const BLOCK_TOOLBAR_MOVE_DOWN_BUTTON_TEST_ID = 'block-toolbar-move-down-button'
export const BLOCK_TOOLBAR_DELETE_BUTTON_TEST_ID = 'block-toolbar-delete-button'
export const BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID = 'block-toolbar-color-button'

type BlockToolbarProps = {
  editor: Editor
}

const getNodeColorAttrs = (attrs: Record<string, unknown>) => ({
  backgroundColor: typeof attrs.backgroundColor === 'string' ? attrs.backgroundColor : null,
  textColor: typeof attrs.textColor === 'string' ? attrs.textColor : null,
})

const buildBlockInfo = (
  pos: number,
  node: { attrs: Record<string, unknown> },
  doc: Editor['state']['doc'],
) => {
  const $pos = doc.resolve(pos)
  const index = $pos.index(0)

  return {
    pos,
    node,
    ...getNodeColorAttrs(node.attrs),
    isFirst: index === 0,
    isLast: index >= doc.childCount - 1,
  }
}

const getNodeSelectionBlock = (e: Editor) => {
  const { selection } = e.state

  if (!(selection instanceof NodeSelection) || e.view.dragging) return null

  return buildBlockInfo(selection.from, selection.node, e.state.doc)
}

const getDragHandleTableBlock = (e: Editor) => {
  if (e.view.dragging) return null

  const selectedBlock = getDragHandleStorage(e).selectedBlock

  if (!selectedBlock) return null

  const node = e.state.doc.nodeAt(selectedBlock.pos)

  if (node?.type.name !== 'table') return null

  const selFrom = e.state.selection.from
  const tableEnd = selectedBlock.pos + node.nodeSize

  if (selFrom < selectedBlock.pos || selFrom > tableEnd) return null

  return buildBlockInfo(selectedBlock.pos, node, e.state.doc)
}

const BlockToolbar = ({ editor }: BlockToolbarProps) => {
  const { translate } = useInternationalization()
  const toolbarRef = useRef<HTMLDivElement>(null)
  const [position, setPosition] = useState<{ top: number; left: number } | null>(null)

  const blockSelection = useEditorState({
    editor,
    selector: ({ editor: e }) => {
      if (!e || e.isDestroyed) return null
      if (getDragHandleStorage(e).hideMenu) return null

      return getNodeSelectionBlock(e) ?? getDragHandleTableBlock(e)
    },
  })

  const updatePosition = useCallback(() => {
    if (!blockSelection || !editor || editor.isDestroyed) {
      setPosition(null)

      return
    }

    const dom = editor.view.nodeDOM(blockSelection.pos)

    if (!dom || !(dom instanceof HTMLElement)) {
      setPosition(null)

      return
    }

    const editorContainer = editor.view.dom.closest('.rich-text-editor')

    if (!editorContainer) {
      setPosition(null)

      return
    }

    const containerRect = editorContainer.getBoundingClientRect()
    const blockRect = dom.getBoundingClientRect()

    setPosition({
      top: blockRect.top - containerRect.top,
      left: blockRect.left - containerRect.left,
    })
  }, [editor, blockSelection])

  useEffect(() => {
    updatePosition()
  }, [updatePosition])

  useEffect(() => {
    if (!blockSelection) return

    const scrollContainer = editor.view.dom.closest('.rich-text-editor')

    if (!scrollContainer) return

    scrollContainer.addEventListener('scroll', updatePosition, { passive: true })

    return () => {
      scrollContainer.removeEventListener('scroll', updatePosition)
    }
  }, [editor, blockSelection, updatePosition])

  if (!blockSelection || !position) return null

  return (
    <div
      ref={toolbarRef}
      className="absolute z-20 flex flex-col gap-1 rounded-xl border border-grey-200 bg-white p-2 shadow-md"
      style={{ top: position.top, left: position.left }}
      data-test={BLOCK_TOOLBAR_TEST_ID}
    >
      {/* Colors (background + text) */}
      <Popper
        PopperProps={{ placement: 'right-start' }}
        opener={
          <Button
            variant="quaternary"
            align="left"
            className="w-full"
            startIcon="text-color"
            data-test={BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID}
          >
            {translate('text_17751458820889ebguo3021w')}
          </Button>
        }
      >
        {() => (
          <MenuPopper>
            {/* Marked so the drag-handle outside-click handler does not treat a
                click on this portaled picker as an outside click and clear the
                block NodeSelection before the color command runs (LAGO-1671). */}
            <div data-rte-preserve-selection>
              <ColorPicker
                activeBackgroundColor={blockSelection.backgroundColor}
                activeTextColor={blockSelection.textColor}
                onSelectBackground={(color) => {
                  editor.commands.setBlockBackgroundColor(color)
                }}
                onSelectText={(color) => {
                  editor.commands.setBlockTextColor(color)
                }}
              />
            </div>
          </MenuPopper>
        )}
      </Popper>

      {/* Move up */}
      <Button
        variant="quaternary"
        startIcon="arrow-top"
        align="left"
        disabled={blockSelection.isFirst}
        data-test={BLOCK_TOOLBAR_MOVE_UP_BUTTON_TEST_ID}
        onClick={() => editor.commands.moveBlockUp()}
      >
        {translate('text_17756354158189xlxmul84lu')}
      </Button>

      {/* Move down */}
      <Button
        variant="quaternary"
        startIcon="arrow-bottom"
        align="left"
        disabled={blockSelection.isLast}
        data-test={BLOCK_TOOLBAR_MOVE_DOWN_BUTTON_TEST_ID}
        onClick={() => editor.commands.moveBlockDown()}
      >
        {translate('text_1775635415819dqd4uqcq6jl')}
      </Button>

      {/* Delete */}
      <Button
        variant="quaternary"
        startIcon="trash"
        align="left"
        data-test={BLOCK_TOOLBAR_DELETE_BUTTON_TEST_ID}
        onClick={() => {
          const node = editor.state.doc.nodeAt(blockSelection.pos)

          if (node) {
            editor
              .chain()
              .focus()
              .deleteRange({ from: blockSelection.pos, to: blockSelection.pos + node.nodeSize })
              .run()
          }
        }}
      >
        {translate('text_1775145882088oj33ff13ddh')}
      </Button>
    </div>
  )
}

export default BlockToolbar
