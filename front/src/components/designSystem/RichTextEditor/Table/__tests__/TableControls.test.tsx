import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Editor } from '@tiptap/react'

import { render } from '~/test-utils'

import TableControls, {
  TABLE_CONTROLS_ADD_COL_BUTTON_TEST_ID,
  TABLE_CONTROLS_ADD_ROW_BUTTON_TEST_ID,
  TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID,
  TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID,
  TABLE_CONTROLS_WRAPPER_TEST_ID,
} from '../TableControls'

// --- Mock chain builder (same proxy pattern as Toolbar.test.tsx) ---
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

// --- DOM helpers ---
const createTableDOM = (container: HTMLElement) => {
  const table = document.createElement('table')
  const tbody = document.createElement('tbody')

  for (let r = 0; r < 2; r++) {
    const tr = document.createElement('tr')

    for (let c = 0; c < 2; c++) {
      const td = document.createElement('td')

      td.textContent = `r${r}c${c}`
      tr.appendChild(td)
    }
    tbody.appendChild(tr)
  }
  table.appendChild(tbody)
  container.appendChild(table)

  return table
}

const createSingleRowTableDOM = (container: HTMLElement) => {
  const table = document.createElement('table')
  const tbody = document.createElement('tbody')
  const tr = document.createElement('tr')

  for (let c = 0; c < 2; c++) {
    const td = document.createElement('td')

    td.textContent = `r0c${c}`
    tr.appendChild(td)
  }
  tbody.appendChild(tr)
  table.appendChild(tbody)
  container.appendChild(table)

  return table
}

const createSingleColTableDOM = (container: HTMLElement) => {
  const table = document.createElement('table')
  const tbody = document.createElement('tbody')

  for (let r = 0; r < 2; r++) {
    const tr = document.createElement('tr')
    const td = document.createElement('td')

    td.textContent = `r${r}c0`
    tr.appendChild(td)
    tbody.appendChild(tr)
  }
  table.appendChild(tbody)
  container.appendChild(table)

  return table
}

const mockGetBoundingClientRect = (el: Element, rect: Partial<DOMRect>) => {
  jest.spyOn(el, 'getBoundingClientRect').mockReturnValue({
    x: 0,
    y: 0,
    width: 0,
    height: 0,
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    toJSON: () => ({}),
    ...rect,
  })
}

// --- Mock editor factory ---
let mockIsInTable = false

const createMockEditor = () => {
  const { proxy, runMock, chainMethods } = createMockChain()
  const eventHandlers: Record<string, Array<() => void>> = {}

  const editor = {
    state: {
      selection: { from: 1, $from: { depth: 0, node: () => null, index: () => 0 } },
      doc: {
        resolve: jest.fn().mockImplementation(() => ({
          depth: 2,
          node: jest.fn().mockImplementation((d: number) => {
            if (d === 1) return { type: { name: 'tableRow' } }
            if (d === 2) return { type: { name: 'tableCell' } }

            return { type: { name: 'doc' } }
          }),
          before: jest.fn().mockReturnValue(1),
        })),
      },
      tr: { setSelection: jest.fn().mockReturnThis() },
    },
    storage: {
      dragHandle: { selectedBlock: null },
    },
    view: {
      domAtPos: jest.fn().mockReturnValue({ node: document.createElement('td') }),
      posAtDOM: jest.fn().mockReturnValue(1),
      dispatch: jest.fn(),
      focus: jest.fn(),
    },
    chain: jest.fn().mockReturnValue(proxy),
    commands: {
      moveRowUp: jest.fn(),
      moveRowDown: jest.fn(),
      moveColumnLeft: jest.fn(),
      moveColumnRight: jest.fn(),
      setRowBackgroundColor: jest.fn(),
      setRowTextColor: jest.fn(),
      setColumnBackgroundColor: jest.fn(),
      setColumnTextColor: jest.fn(),
    },
    on: jest.fn((event: string, handler: () => void) => {
      if (!eventHandlers[event]) eventHandlers[event] = []
      eventHandlers[event].push(handler)
    }),
    off: jest.fn((event: string, handler: () => void) => {
      if (eventHandlers[event]) {
        eventHandlers[event] = eventHandlers[event].filter((h) => h !== handler)
      }
    }),
    isActive: jest.fn().mockReturnValue(false),
  } as unknown as Editor

  return { editor, runMock, chainMethods, eventHandlers }
}

jest.mock('@tiptap/pm/state', () => ({
  ...jest.requireActual('@tiptap/pm/state'),
  TextSelection: {
    near: jest.fn().mockImplementation(($pos: { pos?: number }) => ({ from: $pos.pos ?? 1 })),
  },
}))

jest.mock('@tiptap/pm/tables', () => {
  function CellSelection() {}

  ;(CellSelection as unknown as Record<string, jest.Mock>).rowSelection = jest.fn()
  ;(CellSelection as unknown as Record<string, jest.Mock>).colSelection = jest.fn()

  return { CellSelection }
})

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  useEditorState: jest.fn().mockImplementation(({ selector, editor }) => {
    if (selector) {
      return selector({ editor })
    }

    return mockIsInTable
  }),
}))

const getMockedCellSelection = () =>
  jest.requireMock<{
    CellSelection: jest.Mock & { rowSelection: jest.Mock; colSelection: jest.Mock }
  }>('@tiptap/pm/tables').CellSelection

const createCellSelectionInstance = (overrides: Record<string, unknown> = {}) => {
  const CS = getMockedCellSelection()
  const sel = Object.create(CS.prototype) as Record<string, unknown>

  return Object.assign(sel, {
    isRowSelection: jest.fn().mockReturnValue(false),
    isColSelection: jest.fn().mockReturnValue(false),
    forEachCell: jest.fn(),
    from: 1,
    $from: { depth: 0, node: () => ({ type: { name: 'doc' } }), index: () => 0 },
    ...overrides,
  })
}

const setupIsInTable = (editor: unknown, value: boolean) => {
  mockIsInTable = value
  ;(editor as { isActive: jest.Mock }).isActive.mockReturnValue(value)
}

const setupDOMForLayout = (wrapperEl: HTMLElement, editor: unknown) => {
  const table = createTableDOM(wrapperEl)
  const firstCell = table.querySelector('td') as HTMLTableCellElement

  ;(editor as { view: { domAtPos: jest.Mock } }).view.domAtPos.mockReturnValue({
    node: firstCell,
  })

  let posCounter = 1

  ;(editor as { view: { posAtDOM: jest.Mock } }).view.posAtDOM.mockImplementation(
    () => posCounter++,
  )

  mockGetBoundingClientRect(wrapperEl, { x: 0, y: 0, width: 600, height: 400 })
  mockGetBoundingClientRect(table, { x: 50, y: 50, width: 400, height: 200 })

  const rows = table.querySelectorAll('tr')

  rows.forEach((tr, i) => {
    mockGetBoundingClientRect(tr, { x: 50, y: 50 + i * 100, width: 400, height: 100 })
  })

  const cells = table.querySelectorAll('td')

  cells.forEach((td, i) => {
    const col = i % 2
    const row = Math.floor(i / 2)

    mockGetBoundingClientRect(td, {
      x: 50 + col * 200,
      y: 50 + row * 100,
      width: 200,
      height: 100,
    })
  })
}

const setupDOMForSingleRowLayout = (wrapperEl: HTMLElement, editor: unknown) => {
  const table = createSingleRowTableDOM(wrapperEl)
  const firstCell = table.querySelector('td') as HTMLTableCellElement

  ;(editor as { view: { domAtPos: jest.Mock } }).view.domAtPos.mockReturnValue({
    node: firstCell,
  })

  let posCounter = 1

  ;(editor as { view: { posAtDOM: jest.Mock } }).view.posAtDOM.mockImplementation(
    () => posCounter++,
  )

  mockGetBoundingClientRect(wrapperEl, { x: 0, y: 0, width: 600, height: 400 })
  mockGetBoundingClientRect(table, { x: 50, y: 50, width: 400, height: 100 })

  const rows = table.querySelectorAll('tr')

  rows.forEach((tr) => {
    mockGetBoundingClientRect(tr, { x: 50, y: 50, width: 400, height: 100 })
  })

  const cells = table.querySelectorAll('td')

  cells.forEach((td, i) => {
    mockGetBoundingClientRect(td, { x: 50 + i * 200, y: 50, width: 200, height: 100 })
  })
}

const setupDOMForSingleColLayout = (wrapperEl: HTMLElement, editor: unknown) => {
  const table = createSingleColTableDOM(wrapperEl)
  const firstCell = table.querySelector('td') as HTMLTableCellElement

  ;(editor as { view: { domAtPos: jest.Mock } }).view.domAtPos.mockReturnValue({
    node: firstCell,
  })

  let posCounter = 1

  ;(editor as { view: { posAtDOM: jest.Mock } }).view.posAtDOM.mockImplementation(
    () => posCounter++,
  )

  mockGetBoundingClientRect(wrapperEl, { x: 0, y: 0, width: 600, height: 400 })
  mockGetBoundingClientRect(table, { x: 50, y: 50, width: 200, height: 200 })

  const rows = table.querySelectorAll('tr')

  rows.forEach((tr, i) => {
    mockGetBoundingClientRect(tr, { x: 50, y: 50 + i * 100, width: 200, height: 100 })
  })

  const cells = table.querySelectorAll('td')

  cells.forEach((td, i) => {
    mockGetBoundingClientRect(td, { x: 50, y: 50 + i * 100, width: 200, height: 100 })
  })
}

describe('TableControls', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
    mockIsInTable = false
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN the cursor is not inside a table', () => {
      it('THEN should render the wrapper container', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, false)

        await act(() => render(<TableControls editor={editor} />))

        expect(screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should not render any control buttons', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, false)

        await act(() => render(<TableControls editor={editor} />))

        expect(
          screen.queryByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`),
        ).not.toBeInTheDocument()
        expect(
          screen.queryByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`),
        ).not.toBeInTheDocument()
        expect(screen.queryByTestId(TABLE_CONTROLS_ADD_COL_BUTTON_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(TABLE_CONTROLS_ADD_ROW_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the cursor is inside a table', () => {
      const renderWithLayout = async () => {
        const { editor, runMock } = createMockEditor()

        setupIsInTable(editor, true)

        const { container } = await act(() => render(<TableControls editor={editor} />))

        const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

        setupDOMForLayout(wrapperEl, editor)

        const onCalls = (editor.on as jest.Mock).mock.calls
        const selectionUpdateHandler = onCalls.find(
          ([event]: [string]) => event === 'selectionUpdate',
        )?.[1] as (() => void) | undefined

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        return { editor, runMock, container }
      }

      it('THEN should render row menu buttons for each row', async () => {
        await renderWithLayout()

        expect(
          screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`),
        ).toBeInTheDocument()
        expect(
          screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-1`),
        ).toBeInTheDocument()
      })

      it('THEN should render column menu buttons for each column', async () => {
        await renderWithLayout()

        expect(
          screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`),
        ).toBeInTheDocument()
        expect(
          screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-1`),
        ).toBeInTheDocument()
      })

      it.each([
        ['add column', TABLE_CONTROLS_ADD_COL_BUTTON_TEST_ID],
        ['add row', TABLE_CONTROLS_ADD_ROW_BUTTON_TEST_ID],
      ])('THEN should render the %s button', async (_, testId) => {
        await renderWithLayout()

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })

      describe('WHEN only one row exists', () => {
        const renderWithSingleRowLayout = async () => {
          const { editor, runMock } = createMockEditor()

          setupIsInTable(editor, true)

          await act(() => render(<TableControls editor={editor} />))

          const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

          setupDOMForSingleRowLayout(wrapperEl, editor)

          const onCalls = (editor.on as jest.Mock).mock.calls
          const selectionUpdateHandler = onCalls.find(
            ([event]: [string]) => event === 'selectionUpdate',
          )?.[1] as (() => void) | undefined

          if (selectionUpdateHandler) {
            await act(() => selectionUpdateHandler())
          }

          return { editor, runMock }
        }

        it('THEN should still render row menu buttons (menu handles delete visibility)', async () => {
          await renderWithSingleRowLayout()

          expect(
            screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`),
          ).toBeInTheDocument()
        })

        it('THEN should still render the add row button', async () => {
          await renderWithSingleRowLayout()

          expect(screen.getByTestId(TABLE_CONTROLS_ADD_ROW_BUTTON_TEST_ID)).toBeInTheDocument()
        })
      })

      describe('WHEN only one column exists', () => {
        const renderWithSingleColLayout = async () => {
          const { editor, runMock } = createMockEditor()

          setupIsInTable(editor, true)

          await act(() => render(<TableControls editor={editor} />))

          const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

          setupDOMForSingleColLayout(wrapperEl, editor)

          const onCalls = (editor.on as jest.Mock).mock.calls
          const selectionUpdateHandler = onCalls.find(
            ([event]: [string]) => event === 'selectionUpdate',
          )?.[1] as (() => void) | undefined

          if (selectionUpdateHandler) {
            await act(() => selectionUpdateHandler())
          }

          return { editor, runMock }
        }

        it('THEN should still render col menu buttons (menu handles delete visibility)', async () => {
          await renderWithSingleColLayout()

          expect(
            screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`),
          ).toBeInTheDocument()
        })

        it('THEN should still render the add column button', async () => {
          await renderWithSingleColLayout()

          expect(screen.getByTestId(TABLE_CONTROLS_ADD_COL_BUTTON_TEST_ID)).toBeInTheDocument()
        })
      })

      describe('WHEN the add column button is clicked', () => {
        it('THEN should call the editor chain with addColumnAfter', async () => {
          const user = userEvent.setup()
          const { editor, runMock } = await renderWithLayout()

          await user.click(screen.getByTestId(TABLE_CONTROLS_ADD_COL_BUTTON_TEST_ID))

          expect(editor.chain).toHaveBeenCalled()
          expect(runMock).toHaveBeenCalled()
        })
      })

      describe('WHEN the add row button is clicked', () => {
        it('THEN should call the editor chain with addRowAfter', async () => {
          const user = userEvent.setup()
          const { editor, runMock } = await renderWithLayout()

          await user.click(screen.getByTestId(TABLE_CONTROLS_ADD_ROW_BUTTON_TEST_ID))

          expect(editor.chain).toHaveBeenCalled()
          expect(runMock).toHaveBeenCalled()
        })
      })
    })
  })

  describe('GIVEN the cursor leaves the table', () => {
    describe('WHEN isInTable becomes false', () => {
      it('THEN should clear all controls', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)

        await act(() => render(<TableControls editor={editor} />))

        const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

        setupDOMForLayout(wrapperEl, editor)

        const onCalls = (editor.on as jest.Mock).mock.calls
        const selectionUpdateHandler = onCalls.find(
          ([event]: [string]) => event === 'selectionUpdate',
        )?.[1] as (() => void) | undefined

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        expect(
          screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`),
        ).toBeInTheDocument()

        setupIsInTable(editor, false)

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        expect(
          screen.queryByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the editor event subscriptions', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should subscribe to selectionUpdate and update events', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, false)

        await act(() => render(<TableControls editor={editor} />))

        expect(editor.on).toHaveBeenCalledWith('selectionUpdate', expect.any(Function))
        expect(editor.on).toHaveBeenCalledWith('update', expect.any(Function))
      })
    })

    describe('WHEN the component unmounts', () => {
      it('THEN should unsubscribe from editor events', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, false)

        const { unmount } = await act(() => render(<TableControls editor={editor} />))

        await act(() => unmount())

        expect(editor.off).toHaveBeenCalledWith('selectionUpdate', expect.any(Function))
        expect(editor.off).toHaveBeenCalledWith('update', expect.any(Function))
      })
    })
  })

  describe('GIVEN the hover zone structure', () => {
    const renderWithLayout = async () => {
      const { editor } = createMockEditor()

      setupIsInTable(editor, true)

      await act(() => render(<TableControls editor={editor} />))

      const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

      setupDOMForLayout(wrapperEl, editor)

      const onCalls = (editor.on as jest.Mock).mock.calls
      const selectionUpdateHandler = onCalls.find(
        ([event]: [string]) => event === 'selectionUpdate',
      )?.[1] as (() => void) | undefined

      if (selectionUpdateHandler) {
        await act(() => selectionUpdateHandler())
      }

      return { editor, wrapperEl }
    }

    it('THEN should render row border zones with correct CSS class', async () => {
      const { wrapperEl } = await renderWithLayout()

      const rowZones = wrapperEl.querySelectorAll('.table-controls__row-border-zone')

      expect(rowZones.length).toBe(2)
    })

    it('THEN should render column border zones with correct CSS class', async () => {
      const { wrapperEl } = await renderWithLayout()

      const colZones = wrapperEl.querySelectorAll('.table-controls__col-border-zone')

      expect(colZones.length).toBe(2)
    })

    it('THEN should render add-col-zone and add-row-zone containers', async () => {
      const { wrapperEl } = await renderWithLayout()

      const addColZone = wrapperEl.querySelector('.table-controls__add-col-zone')
      const addRowZone = wrapperEl.querySelector('.table-controls__add-row-zone')

      expect(addColZone).not.toBeNull()
      expect(addRowZone).not.toBeNull()
    })

    // Note: CSS :hover behavior cannot be tested in jsdom.
    // The container-based hover visibility should be verified via manual or e2e testing.
  })

  describe('GIVEN the row and column menu buttons', () => {
    const renderWithLayout = async () => {
      const { editor, runMock } = createMockEditor()

      setupIsInTable(editor, true)

      await act(() => render(<TableControls editor={editor} />))

      const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

      setupDOMForLayout(wrapperEl, editor)

      const onCalls = (editor.on as jest.Mock).mock.calls
      const selectionUpdateHandler = onCalls.find(
        ([event]: [string]) => event === 'selectionUpdate',
      )?.[1] as (() => void) | undefined

      if (selectionUpdateHandler) {
        await act(() => selectionUpdateHandler())
      }

      return { editor, runMock }
    }

    describe('WHEN the row menu buttons are rendered', () => {
      it('THEN each row menu button should have the correct test id pattern', async () => {
        await renderWithLayout()

        const rowBtn0 = screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`)
        const rowBtn1 = screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-1`)

        expect(rowBtn0).toHaveAttribute('aria-label', 'Row options')
        expect(rowBtn1).toHaveAttribute('aria-label', 'Row options')
      })
    })

    describe('WHEN the column menu buttons are rendered', () => {
      it('THEN each column menu button should have the correct test id pattern', async () => {
        await renderWithLayout()

        const colBtn0 = screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`)
        const colBtn1 = screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-1`)

        expect(colBtn0).toHaveAttribute('aria-label', 'Column options')
        expect(colBtn1).toHaveAttribute('aria-label', 'Column options')
      })
    })

    describe('WHEN the add column button is positioned', () => {
      it('THEN should be positioned at the right edge of the table', async () => {
        await renderWithLayout()

        const addColBtn = screen.getByTestId(TABLE_CONTROLS_ADD_COL_BUTTON_TEST_ID)
        const addColZone = addColBtn.parentElement as HTMLElement

        // tableX(50) + tableWidth(400) = 450
        expect(addColZone.style.left).toBe('450px')
      })
    })

    describe('WHEN the add row button is positioned', () => {
      it('THEN should be positioned at the bottom edge of the table', async () => {
        await renderWithLayout()

        const addRowBtn = screen.getByTestId(TABLE_CONTROLS_ADD_ROW_BUTTON_TEST_ID)
        const addRowZone = addRowBtn.parentElement as HTMLElement

        // tableY(50) + tableHeight(200) = 250
        expect(addRowZone.style.top).toBe('250px')
      })
    })
  })

  describe('GIVEN the focusedCell selector', () => {
    const renderWithFocusedCell = async (rowIndex: number, colIndex: number) => {
      const { editor } = createMockEditor()

      setupIsInTable(editor, true)

      // Simulate cursor inside table > tableRow > tableCell
      ;(editor as unknown as { state: { selection: { $from: unknown } } }).state.selection.$from = {
        depth: 3,
        node: (d: number) => {
          if (d === 1) return { type: { name: 'table' } }
          if (d === 2) return { type: { name: 'tableRow' }, attrs: {} }
          if (d === 3) return { type: { name: 'tableCell' } }

          return { type: { name: 'doc' } }
        },
        index: (d: number) => {
          if (d === 1) return rowIndex
          if (d === 2) return colIndex

          return 0
        },
      }

      await act(() => render(<TableControls editor={editor} />))

      const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

      setupDOMForLayout(wrapperEl, editor)

      const onCalls = (editor.on as jest.Mock).mock.calls
      const selectionUpdateHandler = onCalls.find(
        ([event]: [string]) => event === 'selectionUpdate',
      )?.[1] as (() => void) | undefined

      if (selectionUpdateHandler) {
        await act(() => selectionUpdateHandler())
      }

      return { editor, wrapperEl }
    }

    describe('WHEN the cursor is inside a table cell at row 0, col 1', () => {
      it('THEN should set data-focused on the matching row and column border zones', async () => {
        const { wrapperEl } = await renderWithFocusedCell(0, 1)

        const rowZones = wrapperEl.querySelectorAll('.table-controls__row-border-zone')

        expect(rowZones[0]).toHaveAttribute('data-focused')
        expect(rowZones[1]).not.toHaveAttribute('data-focused')

        const colZones = wrapperEl.querySelectorAll('.table-controls__col-border-zone')

        expect(colZones[0]).not.toHaveAttribute('data-focused')
        expect(colZones[1]).toHaveAttribute('data-focused')
      })
    })

    describe('WHEN a CellSelection is active', () => {
      it('THEN should not set data-focused on any border zone', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)

        const cellSel = createCellSelectionInstance()

        ;(editor as unknown as { state: { selection: unknown } }).state.selection = cellSel

        await act(() => render(<TableControls editor={editor} />))

        const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

        setupDOMForLayout(wrapperEl, editor)

        const onCalls = (editor.on as jest.Mock).mock.calls
        const selectionUpdateHandler = onCalls.find(
          ([event]: [string]) => event === 'selectionUpdate',
        )?.[1] as (() => void) | undefined

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        const rowZones = wrapperEl.querySelectorAll('.table-controls__row-border-zone')

        rowZones.forEach((zone) => {
          expect(zone).not.toHaveAttribute('data-focused')
        })
      })
    })

    describe('WHEN dragHandle has a selectedBlock', () => {
      it('THEN should not set data-focused on any border zone', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)
        ;(
          editor as unknown as { storage: { dragHandle: { selectedBlock: unknown } } }
        ).storage.dragHandle.selectedBlock = { id: 'some-block' }

        // Provide $from that would normally produce focusedCell
        ;(editor as unknown as { state: { selection: { $from: unknown } } }).state.selection.$from =
          {
            depth: 3,
            node: (d: number) => {
              if (d === 1) return { type: { name: 'table' } }
              if (d === 2) return { type: { name: 'tableRow' }, attrs: {} }

              return { type: { name: 'doc' } }
            },
            index: () => 0,
          }

        await act(() => render(<TableControls editor={editor} />))

        const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

        setupDOMForLayout(wrapperEl, editor)

        const onCalls = (editor.on as jest.Mock).mock.calls
        const selectionUpdateHandler = onCalls.find(
          ([event]: [string]) => event === 'selectionUpdate',
        )?.[1] as (() => void) | undefined

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        const rowZones = wrapperEl.querySelectorAll('.table-controls__row-border-zone')

        rowZones.forEach((zone) => {
          expect(zone).not.toHaveAttribute('data-focused')
        })
      })
    })
  })

  describe('GIVEN the cellSelection selector', () => {
    describe('WHEN a row CellSelection is active', () => {
      it('THEN should apply is-selected class to the matching row menu button', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)

        const cellSel = createCellSelectionInstance({
          isRowSelection: jest.fn().mockReturnValue(true),
          forEachCell: jest.fn().mockImplementation((cb: (_node: null, pos: number) => void) => {
            cb(null, 10)
          }),
        })

        ;(editor as unknown as { state: { selection: unknown } }).state.selection = cellSel
        ;(
          editor as unknown as { state: { doc: { resolve: jest.Mock } } }
        ).state.doc.resolve.mockImplementation(() => ({
          depth: 2,
          node: (d: number) => {
            if (d === 1) return { type: { name: 'table' } }

            return { type: { name: 'tableRow' } }
          },
          index: (d: number) => {
            if (d === 1) return 0

            return 0
          },
          before: jest.fn().mockReturnValue(1),
        }))

        await act(() => render(<TableControls editor={editor} />))

        const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

        setupDOMForLayout(wrapperEl, editor)

        const onCalls = (editor.on as jest.Mock).mock.calls
        const selectionUpdateHandler = onCalls.find(
          ([event]: [string]) => event === 'selectionUpdate',
        )?.[1] as (() => void) | undefined

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        const rowBtn0 = screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`)

        expect(rowBtn0.className).toContain('is-selected')
      })
    })

    describe('WHEN a column CellSelection is active', () => {
      it('THEN should apply is-selected class to the matching col menu button', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)

        const cellSel = createCellSelectionInstance({
          isColSelection: jest.fn().mockReturnValue(true),
          forEachCell: jest.fn().mockImplementation((cb: (_node: null, pos: number) => void) => {
            cb(null, 10)
          }),
        })

        ;(editor as unknown as { state: { selection: unknown } }).state.selection = cellSel
        ;(
          editor as unknown as { state: { doc: { resolve: jest.Mock } } }
        ).state.doc.resolve.mockImplementation(() => ({
          depth: 2,
          node: (d: number) => {
            if (d === 1) return { type: { name: 'tableRow' } }

            return { type: { name: 'table' } }
          },
          index: (d: number) => {
            if (d === 1) return 1

            return 0
          },
          before: jest.fn().mockReturnValue(1),
        }))

        await act(() => render(<TableControls editor={editor} />))

        const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

        setupDOMForLayout(wrapperEl, editor)

        const onCalls = (editor.on as jest.Mock).mock.calls
        const selectionUpdateHandler = onCalls.find(
          ([event]: [string]) => event === 'selectionUpdate',
        )?.[1] as (() => void) | undefined

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        const colBtn1 = screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-1`)

        expect(colBtn1.className).toContain('is-selected')
      })
    })
  })

  describe('GIVEN the rowColors selector', () => {
    describe('WHEN cursor is inside a table row with color attributes', () => {
      it('THEN should render without errors when row has colors', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)
        ;(editor as unknown as { state: { selection: { $from: unknown } } }).state.selection.$from =
          {
            depth: 2,
            node: (d: number) => {
              if (d === 1)
                return {
                  type: { name: 'tableRow' },
                  attrs: { backgroundColor: '#ff0000', textColor: '#00ff00' },
                }

              return { type: { name: 'table' } }
            },
            index: () => 0,
          }

        await act(() => render(<TableControls editor={editor} />))

        expect(screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN cursor is inside a table row without color attributes', () => {
      it('THEN should render without errors when row has no colors', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)
        ;(editor as unknown as { state: { selection: { $from: unknown } } }).state.selection.$from =
          {
            depth: 2,
            node: (d: number) => {
              if (d === 1)
                return {
                  type: { name: 'tableRow' },
                  attrs: { backgroundColor: null, textColor: null },
                }

              return { type: { name: 'table' } }
            },
            index: () => 0,
          }

        await act(() => render(<TableControls editor={editor} />))

        expect(screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the row menu interactions', () => {
    const renderWithMenuSupport = async () => {
      const { editor, runMock, chainMethods } = createMockEditor()

      setupIsInTable(editor, true)

      // Set up CellSelection.rowSelection for selectRow
      const CS = getMockedCellSelection()

      CS.rowSelection.mockReturnValue({ type: 'row-selection' })

      await act(() => render(<TableControls editor={editor} />))

      const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

      setupDOMForLayout(wrapperEl, editor)

      const onCalls = (editor.on as jest.Mock).mock.calls
      const selectionUpdateHandler = onCalls.find(
        ([event]: [string]) => event === 'selectionUpdate',
      )?.[1] as (() => void) | undefined

      if (selectionUpdateHandler) {
        await act(() => selectionUpdateHandler())
      }

      return { editor, runMock, chainMethods }
    }

    describe('WHEN a row menu button is clicked', () => {
      it('THEN should call selectRow and dispatch the selection', async () => {
        const user = userEvent.setup()
        const { editor } = await renderWithMenuSupport()

        await user.click(screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`))

        expect(editor.view.dispatch).toHaveBeenCalled()
        expect(editor.view.focus).toHaveBeenCalled()
      })
    })

    describe('WHEN the "Move up" button is clicked in the row menu', () => {
      it('THEN should call editor.commands.moveRowUp', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        // Open row menu for row 1 (move up is disabled for row 0)
        await user.click(screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-1`))

        const moveUpBtn = await screen.findByText('Move up')

        await user.click(moveUpBtn)

        expect(chainMethods.moveRowUp).toHaveBeenCalled()
      })
    })

    describe('WHEN the "Move down" button is clicked in the row menu', () => {
      it('THEN should call editor.commands.moveRowDown', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        // Open row menu for row 0 (move down is disabled for last row)
        await user.click(screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`))

        const moveDownBtn = await screen.findByText('Move down')

        await user.click(moveDownBtn)

        expect(chainMethods.moveRowDown).toHaveBeenCalled()
      })
    })

    describe('WHEN the "Delete row" button is clicked in the row menu', () => {
      it('THEN should call chain.deleteRow', async () => {
        const user = userEvent.setup()
        const { editor, runMock } = await renderWithMenuSupport()

        await user.click(screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`))

        const deleteBtn = await screen.findByText('Delete row')

        await user.click(deleteBtn)

        expect(editor.chain).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
      })
    })

    describe('WHEN a background color is selected in the row color picker', () => {
      it('THEN should call editor.commands.setRowBackgroundColor', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        // Open row menu
        await user.click(screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`))

        // Click "Text and block color" to open color sub-popper
        const colorBtn = await screen.findByText('Text and block color')

        await user.click(colorBtn)

        // Click "Clear background" button
        const clearBgBtn = await screen.findByTitle('Clear background')

        await user.click(clearBgBtn)

        expect(chainMethods.setRowBackgroundColor).toHaveBeenCalled()
      })
    })

    describe('WHEN a text color is selected in the row color picker', () => {
      it('THEN should call editor.commands.setRowTextColor', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        // Open row menu
        await user.click(screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`))

        // Click "Text and block color"
        const colorBtn = await screen.findByText('Text and block color')

        await user.click(colorBtn)

        // Click "Clear text color" button
        const clearTextBtn = await screen.findByTitle('Clear text color')

        await user.click(clearTextBtn)

        expect(chainMethods.setRowTextColor).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the column menu interactions', () => {
    const renderWithMenuSupport = async () => {
      const { editor, runMock, chainMethods } = createMockEditor()

      setupIsInTable(editor, true)

      const CS = getMockedCellSelection()

      CS.colSelection.mockReturnValue({ type: 'col-selection' })

      await act(() => render(<TableControls editor={editor} />))

      const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)

      setupDOMForLayout(wrapperEl, editor)

      const onCalls = (editor.on as jest.Mock).mock.calls
      const selectionUpdateHandler = onCalls.find(
        ([event]: [string]) => event === 'selectionUpdate',
      )?.[1] as (() => void) | undefined

      if (selectionUpdateHandler) {
        await act(() => selectionUpdateHandler())
      }

      return { editor, runMock, chainMethods }
    }

    describe('WHEN a column menu button is clicked', () => {
      it('THEN should call selectColumn and dispatch the selection', async () => {
        const user = userEvent.setup()
        const { editor } = await renderWithMenuSupport()

        await user.click(screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`))

        expect(editor.view.dispatch).toHaveBeenCalled()
        expect(editor.view.focus).toHaveBeenCalled()
      })
    })

    describe('WHEN the "Move left" button is clicked in the column menu', () => {
      it('THEN should call editor.commands.moveColumnLeft', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        // Open col menu for col 1 (move left is disabled for col 0)
        await user.click(screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-1`))

        const moveLeftBtn = await screen.findByText('Move left')

        await user.click(moveLeftBtn)

        expect(chainMethods.moveColumnLeft).toHaveBeenCalled()
      })
    })

    describe('WHEN the "Move right" button is clicked in the column menu', () => {
      it('THEN should call editor.commands.moveColumnRight', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        // Open col menu for col 0 (move right is disabled for last col)
        await user.click(screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`))

        const moveRightBtn = await screen.findByText('Move right')

        await user.click(moveRightBtn)

        expect(chainMethods.moveColumnRight).toHaveBeenCalled()
      })
    })

    describe('WHEN the "Delete column" button is clicked in the column menu', () => {
      it('THEN should call chain.deleteColumn', async () => {
        const user = userEvent.setup()
        const { editor, runMock } = await renderWithMenuSupport()

        await user.click(screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`))

        const deleteBtn = await screen.findByText('Delete column')

        await user.click(deleteBtn)

        expect(editor.chain).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
      })
    })

    describe('WHEN a background color is selected in the column color picker', () => {
      it('THEN should call editor.commands.setColumnBackgroundColor', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        await user.click(screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`))

        const colorBtn = await screen.findByText('Text and block color')

        await user.click(colorBtn)

        const clearBgBtn = await screen.findByTitle('Clear background')

        await user.click(clearBgBtn)

        expect(chainMethods.setColumnBackgroundColor).toHaveBeenCalled()
      })
    })

    describe('WHEN a text color is selected in the column color picker', () => {
      it('THEN should call editor.commands.setColumnTextColor', async () => {
        const user = userEvent.setup()
        const { chainMethods } = await renderWithMenuSupport()

        await user.click(screen.getByTestId(`${TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-0`))

        const colorBtn = await screen.findByText('Text and block color')

        await user.click(colorBtn)

        const clearTextBtn = await screen.findByTitle('Clear text color')

        await user.click(clearTextBtn)

        expect(chainMethods.setColumnTextColor).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the computeLayout edge cases', () => {
    describe('WHEN domAtPos returns a text node instead of an element', () => {
      it('THEN should use parentElement to find the table', async () => {
        const { editor } = createMockEditor()

        setupIsInTable(editor, true)

        await act(() => render(<TableControls editor={editor} />))

        const wrapperEl = screen.getByTestId(TABLE_CONTROLS_WRAPPER_TEST_ID)
        const table = createTableDOM(wrapperEl)
        const textNode = document.createTextNode('hello')
        const td = table.querySelector('td') as HTMLTableCellElement

        td.appendChild(textNode)

        // Return a text node instead of an element
        ;(editor as unknown as { view: { domAtPos: jest.Mock } }).view.domAtPos.mockReturnValue({
          node: textNode,
        })

        mockGetBoundingClientRect(wrapperEl, { x: 0, y: 0, width: 600, height: 400 })
        mockGetBoundingClientRect(table, { x: 50, y: 50, width: 400, height: 200 })
        table.querySelectorAll('tr').forEach((tr, i) => {
          mockGetBoundingClientRect(tr, { x: 50, y: 50 + i * 100, width: 400, height: 100 })
        })
        table.querySelectorAll('td').forEach((tdEl, i) => {
          const col = i % 2
          const row = Math.floor(i / 2)

          mockGetBoundingClientRect(tdEl, {
            x: 50 + col * 200,
            y: 50 + row * 100,
            width: 200,
            height: 100,
          })
        })

        let posCounter = 1

        ;(editor as unknown as { view: { posAtDOM: jest.Mock } }).view.posAtDOM.mockImplementation(
          () => posCounter++,
        )

        const onCalls = (editor.on as jest.Mock).mock.calls
        const selectionUpdateHandler = onCalls.find(
          ([event]: [string]) => event === 'selectionUpdate',
        )?.[1] as (() => void) | undefined

        if (selectionUpdateHandler) {
          await act(() => selectionUpdateHandler())
        }

        // Should still render controls (table found via parentElement.closest)
        expect(
          screen.getByTestId(`${TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID}-0`),
        ).toBeInTheDocument()
      })
    })
  })
})
