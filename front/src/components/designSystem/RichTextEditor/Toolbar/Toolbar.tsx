import { Editor, useEditorState } from '@tiptap/react'
import { Icon } from 'lago-design-system'
import React, { forwardRef, useMemo, useRef } from 'react'

import { Popper } from '~/components/designSystem/Popper'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

import ToolbarButton from './ToolbarButton'
import ToolbarDropdown from './ToolbarDropdown'
import { DropdownItem } from './types'
import { GROUP_NAMES, GroupName, useToolbarOverflow } from './useToolbarOverflow'

import ColorPicker from '../BlockControls/ColorPicker'
import { useRichTextEditorContext } from '../common/RichTextEditorContext'
import ImagePopperForm from '../forms/ImagePopperForm'
import LinkPopperForm from '../forms/LinkPopperForm'

export const TOOLBAR_CONTAINER_TEST_ID = 'toolbar-container'
export const TOOLBAR_UNDO_BUTTON_TEST_ID = 'toolbar-undo-button'
export const TOOLBAR_REDO_BUTTON_TEST_ID = 'toolbar-redo-button'
export const TOOLBAR_BOLD_BUTTON_TEST_ID = 'toolbar-bold-button'
export const TOOLBAR_ITALIC_BUTTON_TEST_ID = 'toolbar-italic-button'
export const TOOLBAR_UNDERLINE_BUTTON_TEST_ID = 'toolbar-underline-button'
export const TOOLBAR_STRIKE_BUTTON_TEST_ID = 'toolbar-strike-button'
export const TOOLBAR_CODE_BUTTON_TEST_ID = 'toolbar-code-button'
export const TOOLBAR_COLOR_BUTTON_TEST_ID = 'toolbar-color-button'
export const TOOLBAR_SUPERSCRIPT_BUTTON_TEST_ID = 'toolbar-superscript-button'
export const TOOLBAR_SUBSCRIPT_BUTTON_TEST_ID = 'toolbar-subscript-button'
export const TOOLBAR_TABLE_BUTTON_TEST_ID = 'toolbar-table-button'
export const TOOLBAR_CODE_BLOCK_BUTTON_TEST_ID = 'toolbar-code-block-button'
export const TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID = 'toolbar-text-styling-dropdown'
export const TOOLBAR_IMAGE_BUTTON_TEST_ID = 'toolbar-image-button'
export const TOOLBAR_OVERFLOW_BUTTON_TEST_ID = 'toolbar-overflow-button'
export const TOOLBAR_UNORDERED_LIST_BUTTON_TEST_ID = 'toolbar-unordered-list-button'
export const TOOLBAR_ORDERED_LIST_BUTTON_TEST_ID = 'toolbar-ordered-list-button'
export const TOOLBAR_ALIGN_LEFT_BUTTON_TEST_ID = 'toolbar-align-left-button'
export const TOOLBAR_ALIGN_CENTER_BUTTON_TEST_ID = 'toolbar-align-center-button'
export const TOOLBAR_ALIGN_RIGHT_BUTTON_TEST_ID = 'toolbar-align-right-button'
export const TOOLBAR_ALIGN_JUSTIFY_BUTTON_TEST_ID = 'toolbar-align-justify-button'

type ToolbarProps = {
  editor: Editor | null
}

const Separator = () => <div className="w-px shrink-0 bg-grey-300" />

const ToolbarGroup = forwardRef<HTMLDivElement, { children: React.ReactNode }>(
  ({ children }, ref) => (
    <div ref={ref} className="flex shrink-0 items-center gap-1">
      {children}
    </div>
  ),
)

ToolbarGroup.displayName = 'ToolbarGroup'

const Toolbar = ({ editor }: ToolbarProps) => {
  const { translate } = useInternationalization()
  const { onImageUpload } = useRichTextEditorContext()
  const containerRef = useRef<HTMLDivElement>(null)
  const kebabRef = useRef<HTMLDivElement>(null)
  const groupRefs = useMemo(
    () => ({
      undoRedo: React.createRef<HTMLDivElement>(),
      textStyling: React.createRef<HTMLDivElement>(),
      lists: React.createRef<HTMLDivElement>(),
      alignment: React.createRef<HTMLDivElement>(),
      media: React.createRef<HTMLDivElement>(),
    }),
    [],
  )

  const { visibleGroups, overflowedGroups, hasOverflow } = useToolbarOverflow({
    containerRef,
    groupRefs,
    kebabRef,
    gap: 8, // Tailwind gap-2
    separatorWidth: 1, // Separator w-px
  })

  const editorState = useEditorState({
    editor,
    selector: ({ editor: e }) => ({
      isBold: e?.isActive('bold') ?? false,
      isItalic: e?.isActive('italic') ?? false,
      isUnderline: e?.isActive('underline') ?? false,
      isStrike: e?.isActive('strike') ?? false,
      isParagraph: e?.isActive('paragraph') ?? true,
      isBulletList: e?.isActive('bulletList') ?? false,
      isOrderedList: e?.isActive('orderedList') ?? false,
      isCode: e?.isActive('code') ?? false,
      isCodeBlock: e?.isActive('codeBlock') ?? false,
      isH1: e?.isActive('heading', { level: 1 }) ?? false,
      isH2: e?.isActive('heading', { level: 2 }) ?? false,
      isH3: e?.isActive('heading', { level: 3 }) ?? false,
      isH4: e?.isActive('heading', { level: 4 }) ?? false,
      isLink: e?.isActive('link') ?? false,
      isSuperscript: e?.isActive('superscript') ?? false,
      isSubscript: e?.isActive('subscript') ?? false,
      highlightColor: (e?.getAttributes('highlight').color as string) || null,
      textColor: (e?.getAttributes('textStyle').color as string) || null,
      isAlignLeft: e?.isActive({ textAlign: 'left' }) ?? true,
      isAlignCenter: e?.isActive({ textAlign: 'center' }) ?? false,
      isAlignRight: e?.isActive({ textAlign: 'right' }) ?? false,
      isAlignJustify: e?.isActive({ textAlign: 'justify' }) ?? false,
      canUndo: e && !e.isDestroyed ? e.can().undo() : false,
      canRedo: e && !e.isDestroyed ? e.can().redo() : false,
    }),
  })

  if (!editor || !editorState) return null

  const textStylings: DropdownItem[] = [
    {
      name: translate('text_1775139857938fk9bw8iuaic'),
      value: 'paragraph',
      label: <Icon name="text" />,
      isActive: editorState.isParagraph,
      onButtonClick: () => editor.chain().focus().setParagraph().run(),
    },
    {
      name: translate('text_17751398579393awgjhlyjp9'),
      value: 'heading-1',
      label: <Icon name="h1" />,
      isActive: editorState.isH1,
      onButtonClick: () => editor.chain().focus().setHeading({ level: 1 }).run(),
    },
    {
      name: translate('text_1775139857939isc5wx6anei'),
      value: 'heading-2',
      label: <Icon name="h2" />,
      isActive: editorState.isH2,
      onButtonClick: () => editor.chain().focus().setHeading({ level: 2 }).run(),
    },
    {
      name: translate('text_1775139857939exn3v63g0ie'),
      value: 'heading-3',
      label: <Icon name="h3" />,
      isActive: editorState.isH3,
      onButtonClick: () => editor.chain().focus().setHeading({ level: 3 }).run(),
    },
    {
      name: translate('text_1775139857939u5lo05baoxn'),
      value: 'heading-4',
      label: <Icon name="h4" />,
      isActive: editorState.isH4,
      onButtonClick: () => editor.chain().focus().setHeading({ level: 4 }).run(),
    },
  ]

  const listStylings = [
    {
      testId: TOOLBAR_UNORDERED_LIST_BUTTON_TEST_ID,
      tooltip: translate('text_1774281559657cbz20fzcjka'),
      isActive: editorState.isBulletList,
      onClick: () => editor.chain().focus().toggleBulletList().run(),
      children: <Icon name="list-bullet" />,
    },
    {
      testId: TOOLBAR_ORDERED_LIST_BUTTON_TEST_ID,
      tooltip: translate('text_17742815596575m8mqwrg1qy'),
      isActive: editorState.isOrderedList,
      onClick: () => editor.chain().focus().toggleOrderedList().run(),
      children: <Icon name="list-numbered" />,
    },
  ]

  const alignments = [
    {
      testId: TOOLBAR_ALIGN_LEFT_BUTTON_TEST_ID,
      tooltip: translate('text_1775140688148v814phsfzav'),
      isActive: editorState.isAlignLeft,
      onClick: () => editor.chain().focus().setTextAlign('left').run(),
      children: <Icon name="content-left-align" />,
    },
    {
      testId: TOOLBAR_ALIGN_CENTER_BUTTON_TEST_ID,
      tooltip: translate('text_17751406881499358uq8dyp9'),
      isActive: editorState.isAlignCenter,
      onClick: () => editor.chain().focus().setTextAlign('center').run(),
      children: <Icon name="content-center-align" />,
    },
    {
      testId: TOOLBAR_ALIGN_RIGHT_BUTTON_TEST_ID,
      tooltip: translate('text_1775140688149nqfxjcltqzi'),
      isActive: editorState.isAlignRight,
      onClick: () => editor.chain().focus().setTextAlign('right').run(),
      children: <Icon name="content-right-align" />,
    },
    {
      testId: TOOLBAR_ALIGN_JUSTIFY_BUTTON_TEST_ID,
      tooltip: translate('text_1775140688149xlyu6d27lcv'),
      isActive: editorState.isAlignJustify,
      onClick: () => editor.chain().focus().setTextAlign('justify').run(),
      children: <Icon name="content-justify-align" />,
    },
  ]

  const inlineFormattings = [
    {
      testId: TOOLBAR_BOLD_BUTTON_TEST_ID,
      tooltip: translate('text_177486247001920oltp5jiat'),
      isActive: editorState.isBold,
      onClick: () => editor.chain().focus().toggleBold().run(),
      children: <Icon name="bold" />,
    },
    {
      testId: TOOLBAR_ITALIC_BUTTON_TEST_ID,
      tooltip: translate('text_1774862470019jznh75t0a6d'),
      isActive: editorState.isItalic,
      onClick: () => editor.chain().focus().toggleItalic().run(),
      children: <Icon name="italic" />,
    },
    {
      testId: TOOLBAR_UNDERLINE_BUTTON_TEST_ID,
      tooltip: translate('text_1774862470019g91vhwcvp6a'),
      isActive: editorState.isUnderline,
      onClick: () => editor.chain().focus().toggleUnderline().run(),
      children: <Icon name="underline" />,
    },
    {
      testId: TOOLBAR_STRIKE_BUTTON_TEST_ID,
      tooltip: translate('text_17748624700198fag2st68bl'),
      isActive: editorState.isStrike,
      onClick: () => editor.chain().focus().toggleStrike().run(),
      children: <Icon name="strikethrough" />,
    },
    {
      testId: TOOLBAR_CODE_BUTTON_TEST_ID,
      tooltip: translate('text_1774862470019tg1a4fvcdhz'),
      isActive: editorState.isCode,
      onClick: () => editor.chain().focus().toggleCode().run(),
      children: <Icon name="inline-code" />,
    },
    {
      testId: TOOLBAR_SUPERSCRIPT_BUTTON_TEST_ID,
      tooltip: translate('text_1774862470019bbd9uyzn6ny'),
      isActive: editorState.isSuperscript,
      onClick: () => editor.chain().focus().toggleSuperscript().run(),
      children: <Icon name="superscript" />,
    },
    {
      testId: TOOLBAR_SUBSCRIPT_BUTTON_TEST_ID,
      tooltip: translate('text_17748624700194n6kgjpso8u'),
      isActive: editorState.isSubscript,
      onClick: () => editor.chain().focus().toggleSubscript().run(),
      children: <Icon name="subscript" />,
    },
  ]

  const activeTextStyle = textStylings.find((s) => s.isActive)
  const hasNoActiveStyle = !activeTextStyle // selection spans mixed styles
  const isTextStyleActive = !editorState.isParagraph && !!activeTextStyle

  const renderGroup = (name: GroupName) => {
    switch (name) {
      case 'undoRedo':
        return (
          <ToolbarGroup key={name} ref={groupRefs[name]}>
            <ToolbarButton
              testId={TOOLBAR_UNDO_BUTTON_TEST_ID}
              tooltip={translate('text_1774862470018jqdazc278y0')}
              isActive={false}
              onClick={() => editor.chain().focus().undo().run()}
              isDisabled={!editorState.canUndo}
            >
              <Icon name="arrow-back-up" />
            </ToolbarButton>
            <ToolbarButton
              testId={TOOLBAR_REDO_BUTTON_TEST_ID}
              tooltip={translate('text_1774862470019a0txge16qpr')}
              isActive={false}
              onClick={() => editor.chain().focus().redo().run()}
              isDisabled={!editorState.canRedo}
            >
              <Icon name="arrow-forward-up" />
            </ToolbarButton>
          </ToolbarGroup>
        )
      case 'textStyling':
        return (
          <ToolbarGroup key={name} ref={groupRefs[name]}>
            {/* Text styling dropdown */}
            <ToolbarDropdown
              data-test={TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID}
              items={textStylings}
              opener={
                <ToolbarButton
                  testId={TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID}
                  tooltip={translate('text_1774862470019c5cxqnwghwv')}
                  isActive={isTextStyleActive}
                  isDisabled={hasNoActiveStyle}
                >
                  <Icon name="h1" />
                </ToolbarButton>
              }
            />

            {/* Inline formatting */}
            {inlineFormattings.map((fmt) => (
              <ToolbarButton
                key={fmt.testId}
                testId={fmt.testId}
                tooltip={fmt.tooltip}
                isActive={fmt.isActive}
                onClick={fmt.onClick}
              >
                {fmt.children}
              </ToolbarButton>
            ))}

            {/* Inline colors (background + text) */}
            <Popper
              PopperProps={{ placement: 'bottom-start' }}
              opener={
                <ToolbarButton
                  testId={TOOLBAR_COLOR_BUTTON_TEST_ID}
                  tooltip={translate('text_1774862470019yaqfus5r0ne')}
                  isActive={!!editorState.highlightColor || !!editorState.textColor}
                >
                  <Icon name="text-color" />
                </ToolbarButton>
              }
            >
              {() => (
                <MenuPopper>
                  <ColorPicker
                    activeBackgroundColor={editorState.highlightColor}
                    activeTextColor={editorState.textColor}
                    onSelectBackground={(color) => {
                      if (color) {
                        editor.chain().focus().setHighlight({ color }).run()
                      } else {
                        editor.chain().focus().unsetHighlight().run()
                      }
                    }}
                    onSelectText={(color) => {
                      if (color) {
                        editor.chain().focus().setColor(color).run()
                      } else {
                        editor.chain().focus().unsetColor().run()
                      }
                    }}
                  />
                </MenuPopper>
              )}
            </Popper>
          </ToolbarGroup>
        )
      case 'lists':
        return (
          <ToolbarGroup key={name} ref={groupRefs[name]}>
            {listStylings.map((style) => (
              <ToolbarButton
                key={style.testId}
                testId={style.testId}
                tooltip={style.tooltip}
                isActive={style.isActive}
                onClick={style.onClick}
              >
                {style.children}
              </ToolbarButton>
            ))}
          </ToolbarGroup>
        )
      case 'alignment':
        return (
          <ToolbarGroup key={name} ref={groupRefs[name]}>
            {alignments.map((alignment) => (
              <ToolbarButton
                key={alignment.testId}
                testId={alignment.testId}
                tooltip={alignment.tooltip}
                isActive={alignment.isActive}
                onClick={alignment.onClick}
              >
                {alignment.children}
              </ToolbarButton>
            ))}
          </ToolbarGroup>
        )
      case 'media':
        return (
          <ToolbarGroup key={name} ref={groupRefs[name]}>
            {/* Link */}
            <Popper
              PopperProps={{ placement: 'bottom-start' }}
              opener={
                <ToolbarButton
                  testId="toolbar-link-button"
                  tooltip={translate('text_1774862470019o9kt9r7s0e8')}
                  isActive={editorState.isLink}
                >
                  <Icon name="link" />
                </ToolbarButton>
              }
            >
              {({ closePopper }) => (
                <MenuPopper>
                  <LinkPopperForm editor={editor} closePopper={closePopper} />
                </MenuPopper>
              )}
            </Popper>

            {/* Table */}
            <ToolbarButton
              testId={TOOLBAR_TABLE_BUTTON_TEST_ID}
              tooltip={translate('text_1774862470019b9gczrfwx0i')}
              isActive={false}
              onClick={() =>
                editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()
              }
            >
              <Icon name="table-horizontale" />
            </ToolbarButton>
            <ToolbarButton
              testId={TOOLBAR_CODE_BLOCK_BUTTON_TEST_ID}
              tooltip={translate('text_1774862470019wdgkt31dezy')}
              isActive={editorState.isCodeBlock}
              onClick={() => editor.chain().focus().toggleCodeBlock().run()}
            >
              <Icon name="code" />
            </ToolbarButton>

            {/* Image */}
            {onImageUpload && (
              <Popper
                PopperProps={{ placement: 'bottom-start' }}
                opener={
                  <ToolbarButton
                    testId={TOOLBAR_IMAGE_BUTTON_TEST_ID}
                    tooltip={translate('text_1774862470019f83anhhatsg')}
                    isActive={false}
                  >
                    <Icon name="image" />
                  </ToolbarButton>
                }
              >
                {({ closePopper }) => (
                  <MenuPopper>
                    <ImagePopperForm editor={editor} closePopper={closePopper} />
                  </MenuPopper>
                )}
              </Popper>
            )}
          </ToolbarGroup>
        )
    }
  }

  return (
    <div
      ref={containerRef}
      data-test={TOOLBAR_CONTAINER_TEST_ID}
      className="sticky top-0 z-10 flex w-full min-w-0 gap-2 overflow-hidden bg-white py-3 pl-12 shadow-b"
    >
      {/* Visible groups */}
      {GROUP_NAMES.filter((name) => visibleGroups.has(name)).map((name, index) => (
        <React.Fragment key={name}>
          {index > 0 && <Separator />}
          {renderGroup(name)}
        </React.Fragment>
      ))}

      {/* Overflow kebab menu */}
      {hasOverflow && (
        <div ref={kebabRef} className="shrink-0">
          <Popper
            PopperProps={{ placement: 'bottom-end' }}
            opener={
              <ToolbarButton
                isActive={false}
                testId={TOOLBAR_OVERFLOW_BUTTON_TEST_ID}
                tooltip={translate('text_1777281711979fsxgdzarsdb')}
              >
                <Icon name="dots-horizontal" />
              </ToolbarButton>
            }
          >
            {() => (
              <MenuPopper>
                <div className="flex flex-wrap gap-2 p-2">
                  {overflowedGroups.map((name, index) => (
                    <React.Fragment key={name}>
                      {index > 0 && <Separator />}
                      {renderGroup(name)}
                    </React.Fragment>
                  ))}
                </div>
              </MenuPopper>
            )}
          </Popper>
        </div>
      )}
    </div>
  )
}

export default Toolbar
