import { cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import BlockToolbar, {
  BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID,
  BLOCK_TOOLBAR_DELETE_BUTTON_TEST_ID,
  BLOCK_TOOLBAR_MOVE_DOWN_BUTTON_TEST_ID,
  BLOCK_TOOLBAR_MOVE_UP_BUTTON_TEST_ID,
  BLOCK_TOOLBAR_TEST_ID,
} from '../BlockToolbar'

const mockDeleteRange = jest.fn()
const mockSetBlockBackgroundColor = jest.fn()
const mockSetBlockTextColor = jest.fn()
const mockMoveBlockUp = jest.fn()
const mockMoveBlockDown = jest.fn()
const mockRunFn = jest.fn()

const createMockChain = () => {
  const handler: ProxyHandler<Record<string, jest.Mock>> = {
    get: (_target, prop: string) => {
      if (prop === 'run') return mockRunFn
      if (prop === 'deleteRange') return mockDeleteRange.mockReturnValue(new Proxy({}, handler))

      return jest.fn().mockReturnValue(new Proxy({}, handler))
    },
  }

  return new Proxy({}, handler)
}

let mockSelectorReturn: unknown = null

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  useEditorState: jest.fn(({ selector }: { selector?: (ctx: { editor: unknown }) => unknown }) => {
    if (selector) {
      return mockSelectorReturn
    }

    return null
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const createMockBlockElement = () => {
  const block = document.createElement('p')

  block.getBoundingClientRect = jest.fn().mockReturnValue({
    top: 100,
    left: 50,
    width: 400,
    height: 24,
    right: 450,
    bottom: 124,
  })

  return block
}

const createMockEditorContainer = () => {
  const container = document.createElement('div')

  container.className = 'rich-text-editor'
  container.getBoundingClientRect = jest.fn().mockReturnValue({
    top: 20,
    left: 10,
    width: 800,
    height: 600,
    right: 810,
    bottom: 620,
  })

  return container
}

const createMockEditor = (overrides?: {
  blockElement?: HTMLElement | null
  editorContainer?: HTMLElement | null
}) => {
  const blockElement =
    overrides && 'blockElement' in overrides ? overrides.blockElement : createMockBlockElement()
  const editorContainer =
    overrides && 'editorContainer' in overrides
      ? overrides.editorContainer
      : createMockEditorContainer()

  const editorDom = document.createElement('div')

  editorDom.closest = jest.fn().mockImplementation((selector: string) => {
    if (selector === '.rich-text-editor') return editorContainer

    return null
  })

  return {
    commands: {
      setBlockBackgroundColor: mockSetBlockBackgroundColor,
      setBlockTextColor: mockSetBlockTextColor,
      moveBlockUp: mockMoveBlockUp,
      moveBlockDown: mockMoveBlockDown,
    },
    chain: jest.fn().mockImplementation(() => createMockChain()),
    view: {
      nodeDOM: jest.fn().mockReturnValue(blockElement),
      dom: editorDom,
    },
    state: {
      selection: { from: 0 },
      doc: {
        nodeAt: jest.fn().mockReturnValue({ nodeSize: 10 }),
      },
    },
  } as unknown as Parameters<typeof BlockToolbar>[0]['editor']
}

describe('BlockToolbar', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
    mockSelectorReturn = null
  })

  describe('GIVEN no block is selected', () => {
    describe('WHEN the component renders', () => {
      it('THEN should not render the toolbar', () => {
        mockSelectorReturn = null

        render(<BlockToolbar editor={createMockEditor()} />)

        expect(screen.queryByTestId(BLOCK_TOOLBAR_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a block is selected', () => {
    const blockSelection = {
      pos: 0,
      node: {},
      backgroundColor: null,
      textColor: null,
      isFirst: false,
      isLast: false,
    }

    describe('WHEN the component renders with a valid position', () => {
      it('THEN should render the toolbar', () => {
        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        expect(screen.getByTestId(BLOCK_TOOLBAR_TEST_ID)).toBeInTheDocument()
      })

      it.each([
        ['delete button', BLOCK_TOOLBAR_DELETE_BUTTON_TEST_ID],
        ['color button', BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID],
        ['move up button', BLOCK_TOOLBAR_MOVE_UP_BUTTON_TEST_ID],
        ['move down button', BLOCK_TOOLBAR_MOVE_DOWN_BUTTON_TEST_ID],
      ])('THEN should render the %s', (_, testId) => {
        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })

      it('THEN should position the toolbar relative to the block', () => {
        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        const toolbar = screen.getByTestId(BLOCK_TOOLBAR_TEST_ID)

        // block.top(100) - container.top(20) = 80
        expect(toolbar.style.top).toBe('80px')
        // block.left(50) - container.left(10) = 40
        expect(toolbar.style.left).toBe('40px')
      })
    })

    describe('WHEN the delete button is clicked', () => {
      it('THEN should delete the block via deleteRange', async () => {
        const user = userEvent.setup()

        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        await user.click(screen.getByTestId(BLOCK_TOOLBAR_DELETE_BUTTON_TEST_ID))

        expect(mockDeleteRange).toHaveBeenCalledWith({ from: 0, to: 10 })
        expect(mockRunFn).toHaveBeenCalled()
      })
    })

    describe('WHEN the move up button is clicked', () => {
      it('THEN should call editor.commands.moveBlockUp', async () => {
        const user = userEvent.setup()

        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        await user.click(screen.getByTestId(BLOCK_TOOLBAR_MOVE_UP_BUTTON_TEST_ID))

        expect(mockMoveBlockUp).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the move down button is clicked', () => {
      it('THEN should call editor.commands.moveBlockDown', async () => {
        const user = userEvent.setup()

        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        await user.click(screen.getByTestId(BLOCK_TOOLBAR_MOVE_DOWN_BUTTON_TEST_ID))

        expect(mockMoveBlockDown).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the block is the first block', () => {
      it('THEN the move up button should be disabled', () => {
        mockSelectorReturn = { ...blockSelection, isFirst: true }

        render(<BlockToolbar editor={createMockEditor()} />)

        expect(screen.getByTestId(BLOCK_TOOLBAR_MOVE_UP_BUTTON_TEST_ID)).toBeDisabled()
      })
    })

    describe('WHEN the block is the last block', () => {
      it('THEN the move down button should be disabled', () => {
        mockSelectorReturn = { ...blockSelection, isLast: true }

        render(<BlockToolbar editor={createMockEditor()} />)

        expect(screen.getByTestId(BLOCK_TOOLBAR_MOVE_DOWN_BUTTON_TEST_ID)).toBeDisabled()
      })
    })

    describe('WHEN nodeDOM returns null', () => {
      it('THEN should not render the toolbar', () => {
        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor({ blockElement: null })} />)

        expect(screen.queryByTestId(BLOCK_TOOLBAR_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the editor container is not found', () => {
      it('THEN should not render the toolbar', () => {
        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor({ editorContainer: null })} />)

        expect(screen.queryByTestId(BLOCK_TOOLBAR_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a block with existing colors is selected', () => {
    describe('WHEN the block has a backgroundColor', () => {
      it('THEN should render the color button', () => {
        mockSelectorReturn = {
          pos: 0,
          node: {},
          backgroundColor: '#fee2e2',
          textColor: null,
          isFirst: false,
          isLast: false,
        }

        render(<BlockToolbar editor={createMockEditor()} />)

        expect(screen.getByTestId(BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should open the color picker and call setBlockBackgroundColor when a swatch is clicked', async () => {
        const user = userEvent.setup()

        mockSelectorReturn = {
          pos: 0,
          node: {},
          backgroundColor: '#fee2e2',
          textColor: null,
          isFirst: false,
          isLast: false,
        }

        render(<BlockToolbar editor={createMockEditor()} />)

        await user.click(screen.getByTestId(BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID))

        // Background section renders swatches with inline backgroundColor style
        const blueButtons = screen.getAllByTitle('Blue')
        const bgSwatch = blueButtons[blueButtons.length - 1]

        await user.click(bgSwatch)

        expect(mockSetBlockBackgroundColor).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN the useEditorState selector', () => {
    let capturedSelector: any = null

    const captureSelectorAndRender = () => {
      const tiptap = jest.requireMock('@tiptap/react')

      tiptap.useEditorState.mockImplementation(
        ({ selector }: { selector: (ctx: { editor: unknown }) => unknown }) => {
          capturedSelector = selector

          return mockSelectorReturn
        },
      )

      const mockEditor = createMockEditor()

      render(<BlockToolbar editor={mockEditor} />)

      // Restore default mock after capturing
      tiptap.useEditorState.mockImplementation(
        ({ selector }: { selector?: (ctx: { editor: unknown }) => unknown }) => {
          if (selector) return mockSelectorReturn

          return null
        },
      )
    }

    it('THEN should return null when selection is not a NodeSelection', () => {
      captureSelectorAndRender()

      const result = capturedSelector?.({
        editor: {
          state: { selection: { from: 0 } },
          view: { dragging: null },
          storage: { dragHandle: { selectedBlock: null } },
        },
      })

      expect(result).toBeNull()
    })

    describe('WHEN a table is selected via drag handle and cursor is inside the table', () => {
      it('THEN should return the table block selection as fallback', () => {
        captureSelectorAndRender()

        const tableNode = {
          type: { name: 'table' },
          nodeSize: 20,
          attrs: { backgroundColor: '#fee2e2', textColor: '#dc2626' },
        }

        const result = capturedSelector?.({
          editor: {
            state: {
              selection: { from: 8 },
              doc: {
                nodeAt: () => tableNode,
                resolve: () => ({ index: () => 0 }),
                childCount: 3,
              },
            },
            view: { dragging: null },
            storage: { dragHandle: { selectedBlock: { pos: 5 } } },
          },
        })

        expect(result).toEqual({
          pos: 5,
          node: tableNode,
          backgroundColor: '#fee2e2',
          textColor: '#dc2626',
          isFirst: true,
          isLast: false,
        })
      })
    })

    describe('WHEN a table is selected via drag handle but cursor is outside the table', () => {
      it('THEN should return null', () => {
        captureSelectorAndRender()

        const tableNode = {
          type: { name: 'table' },
          nodeSize: 20,
          attrs: { backgroundColor: null, textColor: null },
        }

        const result = capturedSelector?.({
          editor: {
            state: {
              selection: { from: 50 },
              doc: {
                nodeAt: () => tableNode,
                resolve: () => ({ index: () => 0 }),
                childCount: 3,
              },
            },
            view: { dragging: null },
            storage: { dragHandle: { selectedBlock: { pos: 5 } } },
          },
        })

        expect(result).toBeNull()
      })
    })

    describe('WHEN drag handle has a selectedBlock that is not a table', () => {
      it('THEN should return null', () => {
        captureSelectorAndRender()

        const paragraphNode = {
          type: { name: 'paragraph' },
          nodeSize: 10,
          attrs: {},
        }

        const result = capturedSelector?.({
          editor: {
            state: {
              selection: { from: 6 },
              doc: {
                nodeAt: () => paragraphNode,
                resolve: () => ({ index: () => 0 }),
                childCount: 3,
              },
            },
            view: { dragging: null },
            storage: { dragHandle: { selectedBlock: { pos: 5 } } },
          },
        })

        expect(result).toBeNull()
      })
    })

    describe('WHEN drag handle has a selectedBlock but editor is dragging', () => {
      it('THEN should return null', () => {
        captureSelectorAndRender()

        const result = capturedSelector?.({
          editor: {
            state: {
              selection: { from: 8 },
              doc: {
                nodeAt: () => ({ type: { name: 'table' }, nodeSize: 20, attrs: {} }),
              },
            },
            view: { dragging: { slice: {}, move: true } },
            storage: { dragHandle: { selectedBlock: { pos: 5 } } },
          },
        })

        expect(result).toBeNull()
      })
    })

    describe('WHEN the selection is a NodeSelection', () => {
      it('THEN should return the block info from the node selection', () => {
        captureSelectorAndRender()

        // Create an object that passes instanceof NodeSelection
        // Use defineProperty because Selection has getter-only properties
        const { NodeSelection } = jest.requireActual('@tiptap/pm/state')
        const mockNode = { attrs: { backgroundColor: '#dbeafe', textColor: '#1d4ed8' } }
        const mockSelection = Object.create(NodeSelection.prototype, {
          from: { value: 5 },
          node: { value: mockNode },
        })

        const result = capturedSelector?.({
          editor: {
            state: {
              selection: mockSelection,
              doc: {
                resolve: () => ({ index: () => 2 }),
                childCount: 5,
              },
            },
            view: { dragging: null },
            storage: { dragHandle: { selectedBlock: null } },
          },
        })

        expect(result).toEqual({
          pos: 5,
          node: mockNode,
          backgroundColor: '#dbeafe',
          textColor: '#1d4ed8',
          isFirst: false,
          isLast: false,
        })
      })
    })

    describe('WHEN the selection is a NodeSelection but editor is dragging', () => {
      it('THEN should return null', () => {
        captureSelectorAndRender()

        const { NodeSelection } = jest.requireActual('@tiptap/pm/state')
        const mockSelection = Object.create(NodeSelection.prototype, {
          from: { value: 5 },
          node: { value: { attrs: {} } },
        })

        const result = capturedSelector?.({
          editor: {
            state: {
              selection: mockSelection,
              doc: {
                resolve: () => ({ index: () => 0 }),
                childCount: 3,
              },
            },
            view: { dragging: { slice: {}, move: true } },
            storage: { dragHandle: { selectedBlock: null } },
          },
        })

        expect(result).toBeNull()
      })
    })

    describe('WHEN hideMenu is true in DragHandle storage', () => {
      it('THEN should return null even with a node selected', () => {
        captureSelectorAndRender()

        const { NodeSelection } = jest.requireActual('@tiptap/pm/state')
        const mockNode = { attrs: { backgroundColor: '#dbeafe', textColor: '#1d4ed8' } }
        const mockSelection = Object.create(NodeSelection.prototype, {
          from: { value: 5 },
          node: { value: mockNode },
        })

        const result = capturedSelector?.({
          editor: {
            isDestroyed: false,
            state: {
              selection: mockSelection,
              doc: {
                resolve: () => ({ index: () => 0 }),
                childCount: 3,
              },
            },
            view: { dragging: null },
            storage: { dragHandle: { selectedBlock: null, hideMenu: true } },
          },
        })

        expect(result).toBeNull()
      })
    })
  })

  describe('GIVEN the color picker interactions', () => {
    const blockSelection = {
      pos: 0,
      node: {},
      backgroundColor: null,
      textColor: null,
      isFirst: false,
      isLast: false,
    }

    describe('WHEN a background color is selected', () => {
      it('THEN should call editor.commands.setBlockBackgroundColor', async () => {
        const user = userEvent.setup()

        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        // Click color button to open popper
        await user.click(screen.getByTestId(BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID))

        // Click "Clear background" in the color picker
        const clearBgBtn = await screen.findByTitle('Clear background')

        await user.click(clearBgBtn)

        expect(mockSetBlockBackgroundColor).toHaveBeenCalledWith(null)
      })
    })

    describe('WHEN a text color is selected', () => {
      it('THEN should call editor.commands.setBlockTextColor', async () => {
        const user = userEvent.setup()

        mockSelectorReturn = blockSelection

        render(<BlockToolbar editor={createMockEditor()} />)

        await user.click(screen.getByTestId(BLOCK_TOOLBAR_COLOR_BUTTON_TEST_ID))

        const clearTextBtn = await screen.findByTitle('Clear text color')

        await user.click(clearTextBtn)

        expect(mockSetBlockTextColor).toHaveBeenCalledWith(null)
      })
    })
  })
})
