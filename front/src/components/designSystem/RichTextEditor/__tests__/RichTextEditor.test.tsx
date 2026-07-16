import { act, cleanup, screen } from '@testing-library/react'
import { Markdown } from 'tiptap-markdown'

import { render } from '~/test-utils'

import { RICH_TEXT_EDITOR_CONTENT_TEST_ID, RICH_TEXT_EDITOR_TEST_ID } from '../constants'
import RichTextEditor from '../RichTextEditor'

const mockContentTestId = RICH_TEXT_EDITOR_CONTENT_TEST_ID

global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}))

// Capture the config passed to SlashCommands.configure()
let capturedSlashCommandsConfig: Record<string, unknown> = {}

jest.mock('../extensions/PricingBlock', () => ({
  PricingBlock: {
    configure: jest.fn(() => 'pricing-block-extension'),
  },
}))

jest.mock('../extensions/DiscountBlock', () => ({
  DiscountBlock: {
    configure: jest.fn(() => 'discount-block-extension'),
  },
}))

jest.mock('../extensions/SlashCommands', () => ({
  SlashCommands: {
    configure: jest.fn((config: Record<string, unknown>) => {
      capturedSlashCommandsConfig = config

      return 'slash-commands-extension'
    }),
  },
  slashCommandDefinitions: [],
}))

const mockGetMarkdown = jest.fn().mockReturnValue('# Hello World')

const mockEditor = {
  setEditable: jest.fn(),
  on: jest.fn(),
  off: jest.fn(),
  state: { selection: { from: 0 } },
  view: {
    domAtPos: jest.fn().mockReturnValue({ node: document.createElement('div') }),
    posAtDOM: jest.fn().mockReturnValue(0),
  },
  storage: {
    markdown: {
      getMarkdown: mockGetMarkdown,
    },
  } as Record<string, unknown>,
  extensionManager: {
    extensions: [
      {
        name: Markdown.name,
        storage: {
          getMarkdown: mockGetMarkdown,
        },
      },
    ],
  } as { extensions: Array<{ name: string; storage: unknown }> },
  getHTML: jest.fn().mockReturnValue('<p>Preview content</p>'),
  isActive: jest.fn().mockReturnValue(false),
  getAttributes: jest.fn().mockReturnValue({}),
  can: jest.fn().mockReturnValue({
    undo: jest.fn().mockReturnValue(false),
    redo: jest.fn().mockReturnValue(false),
  }),
  chain: jest.fn().mockReturnValue({
    focus: jest.fn().mockReturnValue({
      toggleBold: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleItalic: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleUnderline: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleStrike: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleCode: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleHighlight: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleSuperscript: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleSubscript: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleBulletList: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleOrderedList: jest.fn().mockReturnValue({ run: jest.fn() }),
      toggleCodeBlock: jest.fn().mockReturnValue({ run: jest.fn() }),
      setHeading: jest.fn().mockReturnValue({ run: jest.fn() }),
      setParagraph: jest.fn().mockReturnValue({ run: jest.fn() }),
      setTextAlign: jest.fn().mockReturnValue({ run: jest.fn() }),
      setLink: jest.fn().mockReturnValue({ run: jest.fn() }),
      unsetLink: jest.fn().mockReturnValue({ run: jest.fn() }),
      insertTable: jest.fn().mockReturnValue({ run: jest.fn() }),
      undo: jest.fn().mockReturnValue({ run: jest.fn() }),
      redo: jest.fn().mockReturnValue({ run: jest.fn() }),
    }),
  }),
}

// Capture the config passed to MentionSchema.extend() and .configure()
let capturedMentionConfig: Record<string, unknown> = {}
let capturedMentionExtendConfig: Record<string, unknown> = {}

jest.mock('../extensions/Mention.schema', () => ({
  MentionSchema: {
    extend: jest.fn((extendConfig: Record<string, unknown>) => {
      capturedMentionExtendConfig = extendConfig

      return {
        configure: jest.fn((config: Record<string, unknown>) => {
          capturedMentionConfig = config

          return 'mention-extension'
        }),
      }
    }),
    configure: jest.fn((config: Record<string, unknown>) => {
      capturedMentionConfig = config

      return 'mention-extension'
    }),
  },
  configureMention: jest.fn(() => 'configured-mention-extension'),
  mentionBaseConfig: {
    HTMLAttributes: { class: 'variable-mention' },
  },
}))

// Capture the config passed to QuoteImageSchema.extend() and .configure()
let capturedQuoteImageConfig: Record<string, unknown> = {}
let capturedQuoteImageExtendConfig: Record<string, unknown> = {}

jest.mock('../extensions/QuoteImage', () => ({
  QuoteImageSchema: {
    extend: jest.fn((extendConfig: Record<string, unknown>) => {
      capturedQuoteImageExtendConfig = extendConfig

      return {
        configure: jest.fn((config: Record<string, unknown>) => {
          capturedQuoteImageConfig = config

          return 'quote-image-extension'
        }),
      }
    }),
  },
}))

let capturedEditorConfig: Record<string, unknown> = {}

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  useEditor: jest.fn().mockImplementation((config: Record<string, unknown>) => {
    capturedEditorConfig = config

    return mockEditor
  }),
  useEditorState: jest.fn().mockImplementation(({ selector }) => {
    if (selector) {
      return selector({ editor: mockEditor })
    }

    return {}
  }),
  EditorContent: ({ editor }: { editor: unknown }) => {
    return editor ? <div data-test={mockContentTestId}>Editor content</div> : null
  },
}))

describe('RichTextEditor', () => {
  afterEach(cleanup)

  describe('GIVEN the editor is initialized', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the editor container', async () => {
        await act(() => render(<RichTextEditor />))

        expect(screen.getByTestId(RICH_TEXT_EDITOR_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the editor content', async () => {
        await act(() => render(<RichTextEditor />))

        expect(screen.getByTestId(RICH_TEXT_EDITOR_CONTENT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the toolbar', async () => {
        await act(() => render(<RichTextEditor />))

        expect(screen.getByTestId('toolbar-container')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the editor fails to initialize', () => {
    describe('WHEN useEditor returns null', () => {
      it('THEN should render nothing', async () => {
        const tiptap = jest.requireMock('@tiptap/react')

        tiptap.useEditor.mockImplementation(() => null)

        const { container } = await act(() => render(<RichTextEditor />))

        expect(container.innerHTML).toBe('')

        tiptap.useEditor.mockImplementation((config: Record<string, unknown>) => {
          capturedEditorConfig = config

          return mockEditor
        })
      })
    })
  })

  describe('GIVEN the mention extension is configured', () => {
    const sixItems = [
      { id: 'customerName', label: 'Customer Name' },
      { id: 'planName', label: 'Plan Name' },
      { id: 'amountDue', label: 'Amount Due' },
      { id: 'invoiceNumber', label: 'Invoice Number' },
      { id: 'dueDate', label: 'Due Date' },
      { id: 'companyName', label: 'Company Name' },
    ]

    beforeEach(async () => {
      await act(() => render(<RichTextEditor variableItems={sixItems} />))
    })

    it('THEN should set the trigger character to @', () => {
      const suggestion = capturedMentionConfig.suggestion as { char: string }

      expect(suggestion.char).toBe('@')
    })

    it('THEN should include mentionBaseConfig properties', () => {
      const attrs = capturedMentionConfig.HTMLAttributes as { class: string }

      expect(attrs.class).toBe('variable-mention')
    })

    it('THEN should pass mentionValues to the config', () => {
      expect(capturedMentionConfig.mentionValues).toBeDefined()
    })

    describe('WHEN filtering items with an empty query', () => {
      it('THEN should return all 6 variable items', () => {
        const suggestion = capturedMentionConfig.suggestion as {
          items: (args: { query: string }) => { id: string; label: string }[]
        }
        const results = suggestion.items({ query: '' })

        expect(results).toHaveLength(6)
      })
    })

    describe('WHEN filtering items with a matching query', () => {
      it.each([
        ['name', 3, ['Customer Name', 'Plan Name', 'Company Name']],
        ['invoice', 1, ['Invoice Number']],
        ['due', 2, ['Amount Due', 'Due Date']],
      ])(
        'THEN should return matching items for query "%s"',
        (query, expectedCount, expectedLabels) => {
          const suggestion = capturedMentionConfig.suggestion as {
            items: (args: { query: string }) => { id: string; label: string }[]
          }
          const results = suggestion.items({ query })

          expect(results).toHaveLength(expectedCount)
          expect(results.map((r) => r.label)).toEqual(expectedLabels)
        },
      )
    })

    describe('WHEN filtering items case-insensitively', () => {
      it('THEN should match regardless of case', () => {
        const suggestion = capturedMentionConfig.suggestion as {
          items: (args: { query: string }) => { id: string; label: string }[]
        }
        const upper = suggestion.items({ query: 'PLAN' })
        const lower = suggestion.items({ query: 'plan' })
        const mixed = suggestion.items({ query: 'PlAn' })

        expect(upper).toHaveLength(1)
        expect(lower).toHaveLength(1)
        expect(mixed).toHaveLength(1)
        expect(upper[0].label).toBe('Plan Name')
      })
    })

    describe('WHEN filtering items with a non-matching query', () => {
      it('THEN should return an empty array', () => {
        const suggestion = capturedMentionConfig.suggestion as {
          items: (args: { query: string }) => { id: string; label: string }[]
        }
        const results = suggestion.items({ query: 'nonexistent' })

        expect(results).toHaveLength(0)
      })
    })
  })

  describe('GIVEN variableItems prop drives the mention suggestion', () => {
    describe('WHEN variableItems are provided', () => {
      it('THEN suggestion.items returns only those items on empty query', async () => {
        const items = [
          { id: 'customer_name', label: 'Customer name' },
          { id: 'quote_number', label: 'Quote number' },
        ]

        await act(() => render(<RichTextEditor variableItems={items} />))

        const suggestion = capturedMentionConfig.suggestion as {
          items: (args: { query: string }) => { id: string; label: string }[]
        }
        const results = suggestion.items({ query: '' })

        expect(results).toHaveLength(2)
        expect(results.map((r) => r.label)).toEqual(['Customer name', 'Quote number'])
      })

      it('THEN suggestion.items filters by query substring (case-insensitive)', async () => {
        const items = [
          { id: 'customer_name', label: 'Customer name' },
          { id: 'quote_number', label: 'Quote number' },
          { id: 'quote_currency', label: 'Quote currency' },
        ]

        await act(() => render(<RichTextEditor variableItems={items} />))

        const suggestion = capturedMentionConfig.suggestion as {
          items: (args: { query: string }) => { id: string; label: string }[]
        }

        expect(suggestion.items({ query: 'quote' })).toHaveLength(2)
        expect(suggestion.items({ query: 'CUST' })).toHaveLength(1)
        expect(suggestion.items({ query: 'CUST' })[0].label).toBe('Customer name')
        expect(suggestion.items({ query: 'xyz' })).toHaveLength(0)
      })
    })

    describe('WHEN variableItems is not provided (default)', () => {
      it('THEN suggestion.items returns empty array', async () => {
        await act(() => render(<RichTextEditor />))

        const suggestion = capturedMentionConfig.suggestion as {
          items: (args: { query: string }) => { id: string; label: string }[]
        }
        const results = suggestion.items({ query: '' })

        expect(results).toHaveLength(0)
      })
    })
  })

  describe('GIVEN the editor is created', () => {
    it('THEN calls useEditor with no dependency array so it is created once', async () => {
      // Regression: a 2nd-arg deps array recreates the editor whenever any dep
      // changes identity. The default `mentionValues = {}` (and unstable
      // entities/callbacks from callers) get a new reference every render, so a
      // deps array causes an infinite re-mount loop ("Maximum update depth
      // exceeded") the moment the editor is interacted with. The editor must be
      // created once; dynamic values are threaded via refs, and the static
      // variableItems catalog is stable.
      const tiptap = jest.requireMock('@tiptap/react')

      tiptap.useEditor.mockClear()

      await act(() => render(<RichTextEditor />))

      expect(tiptap.useEditor.mock.calls[0]).toHaveLength(1)
    })
  })

  describe('GIVEN the editor is in preview mode', () => {
    describe('WHEN mode is set to preview', () => {
      it('THEN should not render the toolbar', async () => {
        await act(() => render(<RichTextEditor mode="preview" />))

        expect(screen.queryByTestId('toolbar-container')).not.toBeInTheDocument()
      })

      it('THEN should render the editor content via EditorContent', async () => {
        await act(() => render(<RichTextEditor mode="preview" />))

        expect(screen.getByTestId(RICH_TEXT_EDITOR_CONTENT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the editor container', async () => {
        await act(() => render(<RichTextEditor mode="preview" />))

        expect(screen.getByTestId(RICH_TEXT_EDITOR_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the editor is in edit mode', () => {
    describe('WHEN mode is set to edit', () => {
      it('THEN should render the toolbar', async () => {
        await act(() => render(<RichTextEditor mode="edit" />))

        expect(screen.getByTestId('toolbar-container')).toBeInTheDocument()
      })

      it('THEN should set the editor to editable', async () => {
        await act(() => render(<RichTextEditor mode="edit" />))

        expect(mockEditor.setEditable).toHaveBeenCalledWith(true)
      })
    })

    describe('WHEN mode is not specified', () => {
      it('THEN should default to edit mode and render the toolbar', async () => {
        await act(() => render(<RichTextEditor />))

        expect(screen.getByTestId('toolbar-container')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the slash commands extension is configured', () => {
    beforeEach(async () => {
      await act(() => render(<RichTextEditor />))
    })

    it('THEN should pass a translate function to SlashCommands.configure', () => {
      expect(capturedSlashCommandsConfig.translate).toBeDefined()
      expect(typeof capturedSlashCommandsConfig.translate).toBe('function')
    })
  })

  describe('GIVEN the getMarkdownRef prop is provided', () => {
    describe('WHEN the editor is initialized', () => {
      it('THEN should assign a function to getMarkdownRef.current', async () => {
        const getMarkdownRef = { current: null } as React.MutableRefObject<(() => string) | null>

        await act(() => render(<RichTextEditor getMarkdownRef={getMarkdownRef} />))

        expect(typeof getMarkdownRef.current).toBe('function')
      })

      it('THEN should return markdown content when called', async () => {
        const getMarkdownRef = { current: null } as React.MutableRefObject<(() => string) | null>

        await act(() => render(<RichTextEditor getMarkdownRef={getMarkdownRef} />))

        const result = getMarkdownRef.current?.()

        expect(mockGetMarkdown).toHaveBeenCalled()
        expect(result).toBe('# Hello World')
      })
    })

    describe('WHEN the markdown extension is not found', () => {
      it('THEN should return undefined', async () => {
        const getMarkdownRef = { current: null } as React.MutableRefObject<(() => string) | null>
        const originalStorage = mockEditor.storage

        mockEditor.storage = {}

        await act(() => render(<RichTextEditor getMarkdownRef={getMarkdownRef} />))

        const result = getMarkdownRef.current?.()

        expect(result).toBe('')

        mockEditor.storage = originalStorage
      })
    })

    describe('WHEN the markdown extension storage has no getMarkdown function', () => {
      it('THEN should return undefined', async () => {
        const getMarkdownRef = { current: null } as React.MutableRefObject<(() => string) | null>
        const originalStorage = mockEditor.storage

        mockEditor.storage = { markdown: {} }

        await act(() => render(<RichTextEditor getMarkdownRef={getMarkdownRef} />))

        const result = getMarkdownRef.current?.()

        expect(result).toBe('')

        mockEditor.storage = originalStorage
      })
    })
  })

  describe('GIVEN the mention extension addNodeView config', () => {
    beforeEach(async () => {
      await act(() => render(<RichTextEditor />))
    })

    it('THEN should provide an addNodeView function', () => {
      expect(capturedMentionExtendConfig.addNodeView).toBeDefined()
      expect(typeof capturedMentionExtendConfig.addNodeView).toBe('function')
    })
  })

  describe('GIVEN the isCompact prop', () => {
    describe('WHEN isCompact is true', () => {
      it('THEN should configure the editor with compact class', async () => {
        await act(() => render(<RichTextEditor isCompact />))

        const editorProps = capturedEditorConfig.editorProps as {
          attributes: { class: string }
        }

        expect(editorProps.attributes.class).toContain('px-0')
        expect(editorProps.attributes.class).toContain('mb-4')
        expect(editorProps.attributes.class).not.toContain('px-10')
      })
    })

    describe('WHEN isCompact is false or not provided', () => {
      it('THEN should configure the editor with default class', async () => {
        await act(() => render(<RichTextEditor />))

        const editorProps = capturedEditorConfig.editorProps as {
          attributes: { class: string }
        }

        expect(editorProps.attributes.class).toContain('px-10')
        expect(editorProps.attributes.class).toContain('my-4')
      })
    })
  })

  describe('GIVEN customer locale and currency props', () => {
    describe('WHEN customerLocale is provided', () => {
      it('THEN should render without errors', async () => {
        await act(() => render(<RichTextEditor customerLocale="fr" />))

        expect(screen.getByTestId(RICH_TEXT_EDITOR_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN customerCurrency is provided', () => {
      it('THEN should render without errors', async () => {
        await act(() => render(<RichTextEditor customerCurrency={'EUR' as never} />))

        expect(screen.getByTestId(RICH_TEXT_EDITOR_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN both customerLocale and customerCurrency are provided', () => {
      it('THEN should render without errors', async () => {
        await act(() =>
          render(<RichTextEditor customerLocale="fr" customerCurrency={'EUR' as never} />),
        )

        expect(screen.getByTestId(RICH_TEXT_EDITOR_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the mention suggestion render callbacks', () => {
    const getMockSuggestionProps = () => ({
      editor: mockEditor,
      clientRect: jest.fn().mockReturnValue({ top: 0, left: 0, width: 100, height: 20 }),
    })

    beforeEach(async () => {
      await act(() => render(<RichTextEditor />))
    })

    it('THEN should have render callbacks defined', () => {
      const suggestion = capturedMentionConfig.suggestion as {
        render: () => Record<string, unknown>
      }

      expect(suggestion.render).toBeDefined()

      const callbacks = suggestion.render()

      expect(callbacks.onStart).toBeDefined()
      expect(callbacks.onUpdate).toBeDefined()
      expect(callbacks.onKeyDown).toBeDefined()
      expect(callbacks.onExit).toBeDefined()
    })

    it('THEN onKeyDown should return true when Escape is pressed', () => {
      const suggestion = capturedMentionConfig.suggestion as {
        render: () => {
          onStart: (props: Record<string, unknown>) => void
          onKeyDown: (props: Record<string, unknown>) => boolean
          onExit: () => void
        }
      }

      const callbacks = suggestion.render()

      callbacks.onStart(getMockSuggestionProps())

      const result = callbacks.onKeyDown({ event: { key: 'Escape' } })

      expect(result).toBe(true)

      callbacks.onExit()
    })
  })

  describe('GIVEN onPreviewReady in preview mode', () => {
    it('THEN calls onPreviewReady with the rendered DOM html after rAF', async () => {
      const rafSpy = jest
        .spyOn(window, 'requestAnimationFrame')
        .mockImplementation((cb: FrameRequestCallback) => {
          cb(0)
          return 0
        })
      const dom = document.createElement('div')

      dom.innerHTML = '<p>Preview content</p>'
      ;(mockEditor.view as Record<string, unknown>).dom = dom

      const onPreviewReady = jest.fn()

      await act(() => render(<RichTextEditor mode="preview" onPreviewReady={onPreviewReady} />))

      expect(onPreviewReady).toHaveBeenCalledWith('<p>Preview content</p>')

      rafSpy.mockRestore()
    })
  })

  describe('GIVEN the images and onImageUpload props', () => {
    describe('WHEN images is provided', () => {
      it('THEN should pass images to QuoteImageSchema.configure', async () => {
        const images = { 'blob-1': 'https://signed/blob-1' }

        await act(() => render(<RichTextEditor images={images} />))

        expect(capturedQuoteImageConfig.images).toEqual(images)
      })
    })

    describe('WHEN images is not provided (default)', () => {
      it('THEN should configure QuoteImageSchema with an empty map', async () => {
        await act(() => render(<RichTextEditor />))

        expect(capturedQuoteImageConfig.images).toEqual({})
      })
    })

    it('THEN should provide an addNodeView function on the extended QuoteImageSchema', async () => {
      await act(() => render(<RichTextEditor />))

      expect(capturedQuoteImageExtendConfig.addNodeView).toBeDefined()
      expect(typeof capturedQuoteImageExtendConfig.addNodeView).toBe('function')
    })

    it('THEN should render without errors when onImageUpload is provided', async () => {
      const onImageUpload = jest.fn()

      await act(() => render(<RichTextEditor onImageUpload={onImageUpload} />))

      expect(screen.getByTestId(RICH_TEXT_EDITOR_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('GIVEN onDiscountCommand prop', () => {
    describe('WHEN onDiscountCommand is provided', () => {
      it('THEN passes onDiscountCommand to SlashCommands.configure', async () => {
        const onDiscountCommand = jest.fn()

        await act(() => render(<RichTextEditor onDiscountCommand={onDiscountCommand} />))

        expect(capturedSlashCommandsConfig.onDiscountCommand).toBeDefined()
        expect(typeof capturedSlashCommandsConfig.onDiscountCommand).toBe('function')
      })
    })

    describe('WHEN onDiscountCommand is not provided', () => {
      it('THEN passes undefined onDiscountCommand to SlashCommands.configure', async () => {
        await act(() => render(<RichTextEditor />))

        expect(capturedSlashCommandsConfig.onDiscountCommand).toBeUndefined()
      })
    })
  })

  describe('GIVEN the DiscountBlock extension', () => {
    it('THEN registers DiscountBlock with entities from props', async () => {
      const { DiscountBlock } = jest.requireMock('../extensions/DiscountBlock') as {
        DiscountBlock: { configure: jest.Mock }
      }

      DiscountBlock.configure.mockClear()

      const entities = {
        'local-1': {
          entityId: 'cpn_1',
          entityType: 'coupon' as const,
          name: 'Summer Sale',
          code: 'SUMMER',
        },
      }

      await act(() => render(<RichTextEditor entities={entities} />))

      expect(DiscountBlock.configure).toHaveBeenCalledWith({ entities })
    })
  })

  describe('GIVEN onDiscountBlocksChange prop', () => {
    describe('WHEN the editor updates with discount block nodes', () => {
      it('THEN calls onDiscountBlocksChange with the collected discount blocks', async () => {
        const onDiscountBlocksChange = jest.fn()

        await act(() => render(<RichTextEditor onDiscountBlocksChange={onDiscountBlocksChange} />))

        const onUpdate = (capturedEditorConfig as { onUpdate?: (arg: { editor: unknown }) => void })
          .onUpdate

        expect(onUpdate).toBeDefined()

        const mockDocWithDiscount = {
          state: {
            doc: {
              descendants: jest.fn((cb: (node: unknown) => void) => {
                cb({
                  type: { name: 'discountBlock' },
                  attrs: { couponId: 'cpn_1', localId: 'local-1' },
                })
                cb({ type: { name: 'discountBlock' }, attrs: { couponId: '', localId: 'local-2' } })
              }),
            },
          },
        }

        await act(() => onUpdate?.({ editor: mockDocWithDiscount }))

        expect(onDiscountBlocksChange).toHaveBeenCalledWith([
          { couponId: 'cpn_1', localId: 'local-1' },
        ])
      })
    })

    describe('WHEN the editor updates without discount block nodes', () => {
      it('THEN calls onDiscountBlocksChange with an empty array', async () => {
        const onDiscountBlocksChange = jest.fn()

        await act(() => render(<RichTextEditor onDiscountBlocksChange={onDiscountBlocksChange} />))

        const onUpdate = (capturedEditorConfig as { onUpdate?: (arg: { editor: unknown }) => void })
          .onUpdate
        const mockDocEmpty = {
          state: {
            doc: {
              descendants: jest.fn((cb: (node: unknown) => void) => {
                cb({ type: { name: 'paragraph' }, attrs: {} })
              }),
            },
          },
        }

        await act(() => onUpdate?.({ editor: mockDocEmpty }))

        expect(onDiscountBlocksChange).toHaveBeenCalledWith([])
      })
    })
  })
})
