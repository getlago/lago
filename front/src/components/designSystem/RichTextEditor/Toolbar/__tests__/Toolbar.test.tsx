import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Editor } from '@tiptap/core'

import { render } from '~/test-utils'

import { RichTextEditorProvider } from '../../common/RichTextEditorContext'
import Toolbar, {
  TOOLBAR_ALIGN_CENTER_BUTTON_TEST_ID,
  TOOLBAR_ALIGN_JUSTIFY_BUTTON_TEST_ID,
  TOOLBAR_ALIGN_LEFT_BUTTON_TEST_ID,
  TOOLBAR_ALIGN_RIGHT_BUTTON_TEST_ID,
  TOOLBAR_BOLD_BUTTON_TEST_ID,
  TOOLBAR_CODE_BLOCK_BUTTON_TEST_ID,
  TOOLBAR_CODE_BUTTON_TEST_ID,
  TOOLBAR_COLOR_BUTTON_TEST_ID,
  TOOLBAR_CONTAINER_TEST_ID,
  TOOLBAR_IMAGE_BUTTON_TEST_ID,
  TOOLBAR_ITALIC_BUTTON_TEST_ID,
  TOOLBAR_ORDERED_LIST_BUTTON_TEST_ID,
  TOOLBAR_OVERFLOW_BUTTON_TEST_ID,
  TOOLBAR_REDO_BUTTON_TEST_ID,
  TOOLBAR_STRIKE_BUTTON_TEST_ID,
  TOOLBAR_SUBSCRIPT_BUTTON_TEST_ID,
  TOOLBAR_SUPERSCRIPT_BUTTON_TEST_ID,
  TOOLBAR_TABLE_BUTTON_TEST_ID,
  TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID,
  TOOLBAR_UNDERLINE_BUTTON_TEST_ID,
  TOOLBAR_UNDO_BUTTON_TEST_ID,
  TOOLBAR_UNORDERED_LIST_BUTTON_TEST_ID,
} from '../Toolbar'

const createMockChain = () => {
  const chainMethods: Record<string, jest.Mock> = {}
  const runMock = jest.fn()

  const handler: ProxyHandler<Record<string, jest.Mock>> = {
    get: (_target, prop: string) => {
      if (prop === 'run') return runMock
      if (!chainMethods[prop]) {
        chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
      }

      return chainMethods[prop]
    },
  }

  return { proxy: new Proxy({}, handler), runMock, chainMethods }
}

const createMockEditor = (overrides: Record<string, boolean> = {}) => {
  const { proxy, runMock } = createMockChain()

  const defaults: Record<string, boolean> = {
    bold: false,
    italic: false,
    underline: false,
    strike: false,
    paragraph: true,
    bulletList: false,
    orderedList: false,
    code: false,
    codeBlock: false,
    heading: false,
    link: false,
    superscript: false,
    subscript: false,
    highlight: false,
    ...overrides,
  }

  return {
    editor: {
      isActive: jest.fn((type: string, attrs?: Record<string, unknown>) => {
        if (type === 'heading' && attrs?.level) {
          return defaults[`heading-${attrs.level}`] ?? false
        }
        if (typeof type === 'object') {
          const key = Object.values(type as Record<string, string>)[0]

          return defaults[`align-${key}`] ?? false
        }

        return defaults[type] ?? false
      }),
      getAttributes: jest.fn(() => ({})),
      can: jest.fn().mockReturnValue({
        undo: jest.fn().mockReturnValue(defaults.canUndo ?? false),
        redo: jest.fn().mockReturnValue(defaults.canRedo ?? false),
      }),
      chain: jest.fn().mockReturnValue(proxy),
      commands: {
        setColor: jest.fn(),
        unsetColor: jest.fn(),
        toggleHighlight: jest.fn(),
        unsetHighlight: jest.fn(),
      },
    } as unknown as Editor,
    runMock,
  }
}

global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}))

jest.mock('~/components/designSystem/RichTextEditor/Toolbar/useToolbarOverflow', () => {
  const GROUP_NAMES = ['undoRedo', 'textStyling', 'lists', 'alignment', 'media'] as const

  return {
    GROUP_NAMES,
    useToolbarOverflow: () => ({
      visibleGroups: new Set(GROUP_NAMES),
      overflowedGroups: [],
      hasOverflow: false,
    }),
  }
})

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  useEditorState: jest.fn().mockImplementation(({ editor, selector }) => {
    if (selector) {
      return selector({ editor })
    }

    return {}
  }),
}))

describe('Toolbar', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the toolbar renders', () => {
    describe('WHEN editor is provided', () => {
      it('THEN should render the toolbar container', async () => {
        const { editor } = createMockEditor()

        await act(() => render(<Toolbar editor={editor} />))

        expect(screen.getByTestId(TOOLBAR_CONTAINER_TEST_ID)).toBeInTheDocument()
      })

      it.each([
        ['undo', TOOLBAR_UNDO_BUTTON_TEST_ID],
        ['redo', TOOLBAR_REDO_BUTTON_TEST_ID],
        ['bold', TOOLBAR_BOLD_BUTTON_TEST_ID],
        ['italic', TOOLBAR_ITALIC_BUTTON_TEST_ID],
        ['underline', TOOLBAR_UNDERLINE_BUTTON_TEST_ID],
        ['strike', TOOLBAR_STRIKE_BUTTON_TEST_ID],
        ['code', TOOLBAR_CODE_BUTTON_TEST_ID],
        ['superscript', TOOLBAR_SUPERSCRIPT_BUTTON_TEST_ID],
        ['subscript', TOOLBAR_SUBSCRIPT_BUTTON_TEST_ID],
        ['color', TOOLBAR_COLOR_BUTTON_TEST_ID],
        ['unordered list', TOOLBAR_UNORDERED_LIST_BUTTON_TEST_ID],
        ['ordered list', TOOLBAR_ORDERED_LIST_BUTTON_TEST_ID],
        ['align left', TOOLBAR_ALIGN_LEFT_BUTTON_TEST_ID],
        ['align center', TOOLBAR_ALIGN_CENTER_BUTTON_TEST_ID],
        ['align right', TOOLBAR_ALIGN_RIGHT_BUTTON_TEST_ID],
        ['align justify', TOOLBAR_ALIGN_JUSTIFY_BUTTON_TEST_ID],
        ['table', TOOLBAR_TABLE_BUTTON_TEST_ID],
        ['code block', TOOLBAR_CODE_BLOCK_BUTTON_TEST_ID],
        ['image', TOOLBAR_IMAGE_BUTTON_TEST_ID],
      ])('THEN should render the %s button', async (_, testId) => {
        const { editor } = createMockEditor()

        await act(() =>
          render(
            <RichTextEditorProvider
              value={{
                mode: 'edit',
                mentionValues: {},
                entities: {},
                images: {},
                onImageUpload: jest.fn().mockResolvedValue('id'),
              }}
            >
              <Toolbar editor={editor} />
            </RichTextEditorProvider>,
          ),
        )

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN undo/redo state', () => {
    describe('WHEN there is no undo history', () => {
      it('THEN should disable the undo button', async () => {
        const { editor } = createMockEditor()

        await act(() => render(<Toolbar editor={editor} />))

        expect(screen.getByTestId(TOOLBAR_UNDO_BUTTON_TEST_ID)).toBeDisabled()
      })
    })

    describe('WHEN there is no redo history', () => {
      it('THEN should disable the redo button', async () => {
        const { editor } = createMockEditor()

        await act(() => render(<Toolbar editor={editor} />))

        expect(screen.getByTestId(TOOLBAR_REDO_BUTTON_TEST_ID)).toBeDisabled()
      })
    })

    describe('WHEN undo is available', () => {
      it('THEN should enable the undo button', async () => {
        const { editor } = createMockEditor({ canUndo: true })

        await act(() => render(<Toolbar editor={editor} />))

        expect(screen.getByTestId(TOOLBAR_UNDO_BUTTON_TEST_ID)).not.toBeDisabled()
      })
    })

    describe('WHEN redo is available', () => {
      it('THEN should enable the redo button', async () => {
        const { editor } = createMockEditor({ canRedo: true })

        await act(() => render(<Toolbar editor={editor} />))

        expect(screen.getByTestId(TOOLBAR_REDO_BUTTON_TEST_ID)).not.toBeDisabled()
      })
    })
  })

  describe('GIVEN formatting button clicks', () => {
    it.each([
      ['bold', TOOLBAR_BOLD_BUTTON_TEST_ID],
      ['italic', TOOLBAR_ITALIC_BUTTON_TEST_ID],
      ['underline', TOOLBAR_UNDERLINE_BUTTON_TEST_ID],
      ['strike', TOOLBAR_STRIKE_BUTTON_TEST_ID],
      ['code', TOOLBAR_CODE_BUTTON_TEST_ID],
      ['superscript', TOOLBAR_SUPERSCRIPT_BUTTON_TEST_ID],
      ['subscript', TOOLBAR_SUBSCRIPT_BUTTON_TEST_ID],
      ['unordered list', TOOLBAR_UNORDERED_LIST_BUTTON_TEST_ID],
      ['ordered list', TOOLBAR_ORDERED_LIST_BUTTON_TEST_ID],
      ['align left', TOOLBAR_ALIGN_LEFT_BUTTON_TEST_ID],
      ['align center', TOOLBAR_ALIGN_CENTER_BUTTON_TEST_ID],
      ['align right', TOOLBAR_ALIGN_RIGHT_BUTTON_TEST_ID],
      ['align justify', TOOLBAR_ALIGN_JUSTIFY_BUTTON_TEST_ID],
      ['table', TOOLBAR_TABLE_BUTTON_TEST_ID],
      ['code block', TOOLBAR_CODE_BLOCK_BUTTON_TEST_ID],
    ])('WHEN the %s button is clicked THEN should call the editor chain', async (_, testId) => {
      const user = userEvent.setup()
      const { editor, runMock } = createMockEditor()

      await act(() => render(<Toolbar editor={editor} />))
      await user.click(screen.getByTestId(testId))

      expect(editor.chain).toHaveBeenCalled()
      expect(runMock).toHaveBeenCalled()
    })

    describe('WHEN the undo button is clicked', () => {
      it('THEN should call the editor chain', async () => {
        const user = userEvent.setup()
        const { editor, runMock } = createMockEditor({ canUndo: true })

        await act(() => render(<Toolbar editor={editor} />))
        await user.click(screen.getByTestId(TOOLBAR_UNDO_BUTTON_TEST_ID))

        expect(editor.chain).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
      })
    })

    describe('WHEN the redo button is clicked', () => {
      it('THEN should call the editor chain', async () => {
        const user = userEvent.setup()
        const { editor, runMock } = createMockEditor({ canRedo: true })

        await act(() => render(<Toolbar editor={editor} />))
        await user.click(screen.getByTestId(TOOLBAR_REDO_BUTTON_TEST_ID))

        expect(editor.chain).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
      })
    })
  })

  // Link popper form tests moved to LinkPopperForm.test.tsx

  describe('GIVEN the text styling dropdown', () => {
    const openDropdown = async (overrides: Record<string, boolean> = {}) => {
      const user = userEvent.setup()
      const { editor, runMock } = createMockEditor(overrides)

      await act(() => render(<Toolbar editor={editor} />))
      await user.click(screen.getByTestId(TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID))

      return { user, editor, runMock }
    }

    it.each([
      ['paragraph', `${TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID}-paragraph`],
      ['heading-1', `${TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID}-heading-1`],
      ['heading-2', `${TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID}-heading-2`],
      ['heading-3', `${TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID}-heading-3`],
    ])('WHEN clicking %s THEN should call editor chain', async (_, itemTestId) => {
      const { user, editor, runMock } = await openDropdown()

      await waitFor(() => {
        expect(screen.getByTestId(itemTestId)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(itemTestId))

      expect(editor.chain).toHaveBeenCalled()
      expect(runMock).toHaveBeenCalled()
    })

    describe('WHEN a heading is active', () => {
      it('THEN should show the text style button with secondary variant (active)', async () => {
        const { editor } = createMockEditor({ 'heading-1': true, paragraph: false })

        await act(() => render(<Toolbar editor={editor} />))

        const button = screen.getByTestId(TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID)

        // secondary variant maps to MUI contained
        expect(button.classList.contains('MuiButton-contained')).toBe(true)
      })
    })

    describe('WHEN paragraph is active (default text)', () => {
      it('THEN should show the text style button with quaternary variant (inactive)', async () => {
        const { editor } = createMockEditor({ paragraph: true })

        await act(() => render(<Toolbar editor={editor} />))

        const button = screen.getByTestId(TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID)

        // quaternary variant maps to MUI text
        expect(button.classList.contains('MuiButton-text')).toBe(true)
      })
    })

    describe('WHEN no text style is active (mixed selection)', () => {
      it('THEN should disable the text style button', async () => {
        const { editor } = createMockEditor({ paragraph: false })

        await act(() => render(<Toolbar editor={editor} />))

        const button = screen.getByTestId(TOOLBAR_TEXT_STYLING_DROPDOWN_TEST_ID)

        expect(button).toBeDisabled()
      })
    })
  })

  describe('GIVEN tooltips on toolbar buttons', () => {
    describe('WHEN hovering a button', () => {
      it.each([
        ['undo', TOOLBAR_UNDO_BUTTON_TEST_ID],
        ['redo', TOOLBAR_REDO_BUTTON_TEST_ID],
        ['bold', TOOLBAR_BOLD_BUTTON_TEST_ID],
        ['italic', TOOLBAR_ITALIC_BUTTON_TEST_ID],
        ['underline', TOOLBAR_UNDERLINE_BUTTON_TEST_ID],
        ['strike', TOOLBAR_STRIKE_BUTTON_TEST_ID],
        ['code', TOOLBAR_CODE_BUTTON_TEST_ID],
        ['superscript', TOOLBAR_SUPERSCRIPT_BUTTON_TEST_ID],
        ['subscript', TOOLBAR_SUBSCRIPT_BUTTON_TEST_ID],
        ['color', TOOLBAR_COLOR_BUTTON_TEST_ID],
        ['unordered list', TOOLBAR_UNORDERED_LIST_BUTTON_TEST_ID],
        ['ordered list', TOOLBAR_ORDERED_LIST_BUTTON_TEST_ID],
        ['align left', TOOLBAR_ALIGN_LEFT_BUTTON_TEST_ID],
        ['align center', TOOLBAR_ALIGN_CENTER_BUTTON_TEST_ID],
        ['align right', TOOLBAR_ALIGN_RIGHT_BUTTON_TEST_ID],
        ['align justify', TOOLBAR_ALIGN_JUSTIFY_BUTTON_TEST_ID],
        ['table', TOOLBAR_TABLE_BUTTON_TEST_ID],
        ['code block', TOOLBAR_CODE_BLOCK_BUTTON_TEST_ID],
        ['image', TOOLBAR_IMAGE_BUTTON_TEST_ID],
      ])('THEN should display a tooltip for the %s button', async (_, testId) => {
        const user = userEvent.setup({ pointerEventsCheck: 0 })
        const { editor } = createMockEditor()

        await act(() =>
          render(
            <RichTextEditorProvider
              value={{
                mode: 'edit',
                mentionValues: {},
                entities: {},
                images: {},
                onImageUpload: jest.fn().mockResolvedValue('id'),
              }}
            >
              <Toolbar editor={editor} />
            </RichTextEditorProvider>,
          ),
        )
        await user.hover(screen.getByTestId(testId))

        expect(await screen.findByRole('tooltip')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the toolbar overflow behavior', () => {
    describe('WHEN all groups fit in the container', () => {
      it('THEN should not show the overflow button', async () => {
        const { editor } = createMockEditor()

        await act(() => render(<Toolbar editor={editor} />))

        expect(screen.queryByTestId(TOOLBAR_OVERFLOW_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no onImageUpload in context', () => {
    describe('WHEN the toolbar renders', () => {
      it('THEN the image button is not rendered', async () => {
        const { editor } = createMockEditor()

        await act(() => render(<Toolbar editor={editor} />))

        expect(screen.queryByTestId(TOOLBAR_IMAGE_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })
})
