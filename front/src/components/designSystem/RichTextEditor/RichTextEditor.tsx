import Placeholder from '@tiptap/extension-placeholder'
import {
  type Editor,
  EditorContent,
  ReactNodeViewRenderer,
  ReactRenderer,
  useEditor,
} from '@tiptap/react'
import { type MutableRefObject, useCallback, useEffect, useMemo, useRef } from 'react'
import tippy, { type Instance as TippyInstance } from 'tippy.js'

import type { Locale } from '~/core/translations'
import type { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import BlockToolbar from './BlockControls/BlockToolbar'
import {
  type EntityData,
  type OnDiscountCommand,
  type OnPricingCommand,
  RichTextEditorProvider,
} from './common/RichTextEditorContext'
import {
  RICH_TEXT_EDITOR_CONTENT_TEST_ID,
  RICH_TEXT_EDITOR_TEST_ID,
  RICH_TEXT_EDITOR_TOOLBAR_TEST_ID,
} from './constants'
import { getBaseExtensions } from './extensions/baseExtensions'
import { DiscountBlock } from './extensions/DiscountBlock'
import { type DiscountBlockAttributes } from './extensions/DiscountBlock.schema'
import { DragHandle } from './extensions/DragHandle'
import { LinkPasteHandler } from './extensions/LinkPasteHandler'
import {
  mentionBaseConfig,
  MentionSchema,
  type MentionSchemaOptions,
} from './extensions/Mention.schema'
import { PricingBlock } from './extensions/PricingBlock'
import { type PricingBlockAttributes } from './extensions/PricingBlock.schema'
import { QuoteImageSchema } from './extensions/QuoteImage'
import { QuoteImageNodeView } from './extensions/QuoteImageNodeView'
import { SlashCommands } from './extensions/SlashCommands'
import { TableCommands } from './extensions/TableCommands'
import { TemplateSelectorExtension } from './extensions/TemplateSelectorExtension'
import { type MentionItem, MentionList, type MentionListRef } from './Mentions/MentionList'
import { MentionNodeView } from './Mentions/MentionNodeView'
import './richTextEditor.css'
import TableControls from './Table/TableControls'
import type { EditorTemplate } from './TemplateSelector/types'
import Toolbar from './Toolbar/Toolbar'

export type RichTextEditorMode = 'edit' | 'preview'

interface RichTextEditorProps {
  mode?: RichTextEditorMode
  mentionValues?: Record<string, string>
  entities?: Record<string, EntityData>
  content?: string
  templates?: EditorTemplate[]
  getMarkdownRef?: React.MutableRefObject<(() => string) | null>
  onChange?: () => void
  onPricingCommand?: OnPricingCommand
  isPricingDisabled?: () => boolean
  onPricingBlocksChange?: (blocks: PricingBlockAttributes[]) => void
  onDiscountCommand?: OnDiscountCommand
  onDiscountBlocksChange?: (blocks: DiscountBlockAttributes[]) => void
  customerLocale?: Locale
  customerCurrency?: CurrencyEnum
  images?: Record<string, string>
  onImageUpload?: (base64: string) => Promise<string>
  isCompact?: boolean
  onPreviewReady?: (html: string) => void
  /**
   * Variables offered by the `@`-mention dropdown. Pass a STABLE reference
   * (module-level const or `useMemo`) — a new array identity on each render
   * recreates the editor and resets cursor/selection state.
   */
  variableItems?: MentionItem[]
}

const createMentionSuggestion = (
  items: MentionItem[],
): NonNullable<MentionSchemaOptions['suggestion']> => ({
  char: '@',
  items: ({ query }) => items.filter((v) => v.label.toLowerCase().includes(query.toLowerCase())),
  render: () => {
    let renderer: ReactRenderer<MentionListRef>
    let popup: TippyInstance[]

    return {
      onStart: (suggestionProps) => {
        renderer = new ReactRenderer(MentionList, {
          props: suggestionProps,
          editor: suggestionProps.editor,
        })

        popup = tippy('body', {
          getReferenceClientRect: () => suggestionProps.clientRect?.() ?? new DOMRect(),
          appendTo: () => document.body,
          content: renderer.element,
          showOnCreate: true,
          interactive: true,
          trigger: 'manual',
          placement: 'bottom-start',
        })
      },
      onUpdate: (suggestionProps) => {
        renderer.updateProps(suggestionProps)

        popup[0].setProps({
          getReferenceClientRect: () => suggestionProps.clientRect?.() ?? new DOMRect(),
        })
      },
      onKeyDown: (keyDownProps) => {
        if (keyDownProps.event.key === 'Escape') {
          popup[0].hide()
          return true
        }

        return renderer.ref?.onKeyDown(keyDownProps) ?? false
      },
      onExit: () => {
        popup[0].destroy()
        renderer.destroy()
      },
    }
  },
})

const getInitialEditorContent = (content?: string, templates?: EditorTemplate[]) => {
  if (content) {
    return content
  }

  if (templates && templates.length > 0) {
    return {
      type: 'doc',
      content: [
        { type: 'paragraph' },
        {
          type: 'templateSelector',
          attrs: { templates },
        },
      ],
    }
  }

  return ''
}

const collectPricingBlocks = (editorInstance: Editor): PricingBlockAttributes[] => {
  const blocks: PricingBlockAttributes[] = []

  editorInstance.state.doc.descendants((node) => {
    if (node.type.name === 'pricingBlock' && node.attrs.entityIds?.length) {
      blocks.push({
        pricingType: node.attrs.pricingType,
        entityIds: node.attrs.entityIds,
        localEntityIds: node.attrs.localEntityIds,
      })
    }
  })

  return blocks
}

const collectDiscountBlocks = (editorInstance: Editor): DiscountBlockAttributes[] => {
  const discountBlocks: DiscountBlockAttributes[] = []

  editorInstance.state.doc.descendants((node) => {
    if (node.type.name === 'discountBlock' && node.attrs.couponId) {
      discountBlocks.push({
        couponId: node.attrs.couponId,
        localId: node.attrs.localId,
      })
    }
  })

  return discountBlocks
}

const readMarkdownFromEditor = (editor: Editor | null | undefined): string | undefined => {
  if (!editor || !editor.storage || !('markdown' in editor.storage)) return undefined

  const storage: unknown = editor.storage.markdown

  if (
    !storage ||
    typeof storage !== 'object' ||
    !('getMarkdown' in storage) ||
    typeof storage.getMarkdown !== 'function'
  )
    return undefined

  const result: unknown = storage.getMarkdown()

  return typeof result === 'string' ? result : undefined
}

const buildSlashCommandsOptions = ({
  translate,
  onPricingCommand,
  onPricingCommandRef,
  isPricingDisabled,
  isPricingDisabledRef,
  onDiscountCommand,
  onDiscountCommandRef,
}: {
  translate: (key: string) => string
  onPricingCommand?: OnPricingCommand
  onPricingCommandRef: MutableRefObject<OnPricingCommand | undefined>
  isPricingDisabled?: () => boolean
  isPricingDisabledRef: MutableRefObject<(() => boolean) | undefined>
  onDiscountCommand?: OnDiscountCommand
  onDiscountCommandRef: MutableRefObject<OnDiscountCommand | undefined>
}) => ({
  translate,
  onPricingCommand: onPricingCommand
    ? (params: Parameters<OnPricingCommand>[0]) => onPricingCommandRef.current?.(params)
    : undefined,
  isPricingDisabled: isPricingDisabled
    ? () => isPricingDisabledRef.current?.() ?? false
    : undefined,
  onDiscountCommand: onDiscountCommand
    ? (params: Parameters<OnDiscountCommand>[0]) => onDiscountCommandRef.current?.(params)
    : undefined,
})

const RichTextEditor = ({
  mode = 'edit',
  mentionValues = {},
  entities: entitiesFromProps = {},
  content,
  templates,
  getMarkdownRef,
  onPricingCommand,
  isPricingDisabled,
  onPricingBlocksChange,
  onDiscountCommand,
  onDiscountBlocksChange,
  onChange,
  customerLocale,
  customerCurrency,
  images = {},
  onImageUpload,
  isCompact,
  onPreviewReady,
  variableItems = [],
}: RichTextEditorProps) => {
  const { translate } = useInternationalization()
  const onChangeRef = useRef(onChange)
  const onPricingBlocksChangeRef = useRef(onPricingBlocksChange)
  const onPricingCommandRef = useRef(onPricingCommand)
  const isPricingDisabledRef = useRef(isPricingDisabled)
  const onDiscountCommandRef = useRef(onDiscountCommand)
  const onDiscountBlocksChangeRef = useRef(onDiscountBlocksChange)

  onChangeRef.current = onChange
  onPricingBlocksChangeRef.current = onPricingBlocksChange
  onPricingCommandRef.current = onPricingCommand
  isPricingDisabledRef.current = isPricingDisabled
  onDiscountCommandRef.current = onDiscountCommand
  onDiscountBlocksChangeRef.current = onDiscountBlocksChange

  const mentionSuggestion = useMemo(() => createMentionSuggestion(variableItems), [variableItems])

  const editorAttributesClass = isCompact
    ? 'max-w-4xl mx-auto focus:outline-none min-h-[300px] mb-4 px-0'
    : 'max-w-4xl mx-auto focus:outline-none min-h-[300px] my-4 px-10'

  const editor = useEditor({
    extensions: [
      ...getBaseExtensions({ tableResizable: true }),

      // Editor-specific overrides and additions
      Placeholder.configure({
        placeholder: translate('text_1774281162711nymiwumt66k'),
      }),
      MentionSchema.extend({
        addNodeView() {
          return ReactNodeViewRenderer(MentionNodeView, { as: 'span' })
        },
      }).configure({
        ...mentionBaseConfig,
        mentionValues,
        suggestion: mentionSuggestion,
      } as MentionSchemaOptions),
      PricingBlock.configure({ entities: entitiesFromProps }),
      QuoteImageSchema.extend({
        addNodeView() {
          return ReactNodeViewRenderer(QuoteImageNodeView, { as: 'div' })
        },
      }).configure({ images }),
      DiscountBlock.configure({ entities: entitiesFromProps }),
      SlashCommands.configure(
        buildSlashCommandsOptions({
          translate,
          onPricingCommand,
          onPricingCommandRef,
          isPricingDisabled,
          isPricingDisabledRef,
          onDiscountCommand,
          onDiscountCommandRef,
        }),
      ),
      LinkPasteHandler,
      TemplateSelectorExtension.configure({ templates: templates ?? [] }),
      DragHandle,
      TableCommands,
    ],
    editorProps: {
      attributes: {
        class: editorAttributesClass,
      },
    },
    content: getInitialEditorContent(content, templates),
    onUpdate: ({ editor: editorInstance }) => {
      onChangeRef.current?.()

      if (onPricingBlocksChangeRef.current) {
        onPricingBlocksChangeRef.current(collectPricingBlocks(editorInstance))
      }

      if (onDiscountBlocksChangeRef.current) {
        onDiscountBlocksChangeRef.current(collectDiscountBlocks(editorInstance))
      }
    },
  })

  const isPreview = mode === 'preview'

  useEffect(() => {
    if (editor) {
      editor.setEditable(!isPreview)
    }
  }, [editor, isPreview])

  useEffect(() => {
    if (!editor || !isPreview || !onPreviewReady) return

    let raf2 = 0

    const raf1 = requestAnimationFrame(() => {
      raf2 = requestAnimationFrame(() => {
        onPreviewReady(editor.view.dom.innerHTML)
      })
    })

    return () => {
      cancelAnimationFrame(raf1)
      cancelAnimationFrame(raf2)
    }
  }, [editor, isPreview, onPreviewReady])

  const getMarkdown = useCallback(
    (): string | undefined => readMarkdownFromEditor(editor),
    [editor],
  )

  const contextValue = useMemo(
    () => ({
      mode,
      mentionValues,
      entities: entitiesFromProps,
      images,
      onPricingCommand,
      onImageUpload,
      onDiscountCommand,
      customerLocale,
      customerCurrency,
    }),
    [
      mode,
      mentionValues,
      entitiesFromProps,
      images,
      onImageUpload,
      onPricingCommand,
      onDiscountCommand,
      customerLocale,
      customerCurrency,
    ],
  )

  useEffect(() => {
    if (!getMarkdownRef) return

    getMarkdownRef.current = () => getMarkdown() ?? ''

    return () => {
      if (getMarkdownRef) {
        getMarkdownRef.current = null
      }
    }
  }, [getMarkdownRef, getMarkdown])

  if (!editor) return null

  return (
    <RichTextEditorProvider value={contextValue}>
      <div
        className={`rich-text-editor relative size-full overflow-auto ${isPreview ? '' : 'group/editor'}`}
        data-test={RICH_TEXT_EDITOR_TEST_ID}
      >
        {!isPreview && <Toolbar editor={editor} data-test={RICH_TEXT_EDITOR_TOOLBAR_TEST_ID} />}
        <div className="relative">
          <EditorContent editor={editor} data-test={RICH_TEXT_EDITOR_CONTENT_TEST_ID} />
          {!isPreview && <TableControls editor={editor} />}
        </div>
        {!isPreview && <BlockToolbar editor={editor} />}
      </div>
    </RichTextEditorProvider>
  )
}

export default RichTextEditor
