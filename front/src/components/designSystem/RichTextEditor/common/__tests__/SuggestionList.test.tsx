import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { render } from '~/test-utils'

import {
  SUGGESTION_LIST_CONTAINER_TEST_ID,
  SUGGESTION_LIST_ITEM_TEST_ID,
  SuggestionList,
  type SuggestionListRef,
} from '../SuggestionList'

// scrollIntoView is not available in jsdom
Element.prototype.scrollIntoView = jest.fn()

interface TestItem {
  id: string
  name: string
}

const createMockItems = (): TestItem[] => [
  { id: '1', name: 'Alpha' },
  { id: '2', name: 'Beta' },
  { id: '3', name: 'Gamma' },
]

const mockCommand = jest.fn()
const getKey = (item: TestItem) => item.id
const getLabel = (item: TestItem) => item.name

describe('SuggestionList', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the list receives items', () => {
    describe('WHEN items are provided', () => {
      it('THEN should render the container with default test ID', async () => {
        await act(() =>
          render(
            <SuggestionList
              items={createMockItems()}
              command={mockCommand}
              getKey={getKey}
              getLabel={getLabel}
            />,
          ),
        )

        expect(screen.getByTestId(SUGGESTION_LIST_CONTAINER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render all items with default test IDs', async () => {
        await act(() =>
          render(
            <SuggestionList
              items={createMockItems()}
              command={mockCommand}
              getKey={getKey}
              getLabel={getLabel}
            />,
          ),
        )

        expect(screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-0`)).toBeInTheDocument()
        expect(screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-1`)).toBeInTheDocument()
        expect(screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-2`)).toBeInTheDocument()
      })

      it('THEN should display item labels via getLabel', async () => {
        await act(() =>
          render(
            <SuggestionList
              items={createMockItems()}
              command={mockCommand}
              getKey={getKey}
              getLabel={getLabel}
            />,
          ),
        )

        expect(screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-0`)).toHaveTextContent('Alpha')
        expect(screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-1`)).toHaveTextContent('Beta')
        expect(screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-2`)).toHaveTextContent('Gamma')
      })
    })

    describe('WHEN custom test IDs are provided', () => {
      it('THEN should use the custom container and item test IDs', async () => {
        await act(() =>
          render(
            <SuggestionList
              items={createMockItems()}
              command={mockCommand}
              getKey={getKey}
              getLabel={getLabel}
              containerTestId="custom-container"
              itemTestId="custom-item"
            />,
          ),
        )

        expect(screen.getByTestId('custom-container')).toBeInTheDocument()
        expect(screen.getByTestId('custom-item-0')).toBeInTheDocument()
      })
    })

    describe('WHEN items array is empty', () => {
      it('THEN should not render the container', async () => {
        await act(() =>
          render(
            <SuggestionList items={[]} command={mockCommand} getKey={getKey} getLabel={getLabel} />,
          ),
        )

        expect(screen.queryByTestId(SUGGESTION_LIST_CONTAINER_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user clicks on an item', () => {
    describe('WHEN an item is clicked', () => {
      it('THEN should call command with the clicked item', async () => {
        const user = userEvent.setup()
        const items = createMockItems()

        await act(() =>
          render(
            <SuggestionList
              items={items}
              command={mockCommand}
              getKey={getKey}
              getLabel={getLabel}
            />,
          ),
        )
        await user.click(screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-1`))

        expect(mockCommand).toHaveBeenCalledWith(items[1])
      })
    })
  })

  describe('GIVEN keyboard navigation via ref', () => {
    const renderWithRef = async () => {
      const ref = createRef<SuggestionListRef>()
      const items = createMockItems()

      await act(() =>
        render(
          <SuggestionList
            ref={ref}
            items={items}
            command={mockCommand}
            getKey={getKey}
            getLabel={getLabel}
          />,
        ),
      )

      return { ref, items }
    }

    const simulateKeyDown = (ref: React.RefObject<SuggestionListRef | null>, key: string) => {
      return ref.current?.onKeyDown({
        event: new KeyboardEvent('keydown', { key }),
      } as unknown as Parameters<SuggestionListRef['onKeyDown']>[0])
    }

    describe('WHEN ArrowDown is pressed', () => {
      it('THEN should return true', async () => {
        const { ref } = await renderWithRef()

        let result: boolean | undefined

        act(() => {
          result = simulateKeyDown(ref, 'ArrowDown')
        })

        expect(result).toBe(true)
      })

      it('THEN should select the next item so Enter dispatches it', async () => {
        const { ref, items } = await renderWithRef()

        act(() => {
          simulateKeyDown(ref, 'ArrowDown')
        })
        act(() => {
          simulateKeyDown(ref, 'Enter')
        })

        expect(mockCommand).toHaveBeenCalledWith(items[1])
      })

      it('THEN should wrap around to the first item after the last', async () => {
        const { ref, items } = await renderWithRef()

        act(() => {
          simulateKeyDown(ref, 'ArrowDown')
        })
        act(() => {
          simulateKeyDown(ref, 'ArrowDown')
        })
        act(() => {
          simulateKeyDown(ref, 'ArrowDown')
        })
        act(() => {
          simulateKeyDown(ref, 'Enter')
        })

        expect(mockCommand).toHaveBeenCalledWith(items[0])
      })
    })

    describe('WHEN ArrowUp is pressed', () => {
      it('THEN should return true', async () => {
        const { ref } = await renderWithRef()

        let result: boolean | undefined

        act(() => {
          result = simulateKeyDown(ref, 'ArrowUp')
        })

        expect(result).toBe(true)
      })

      it('THEN should wrap to the last item from the first', async () => {
        const { ref, items } = await renderWithRef()

        act(() => {
          simulateKeyDown(ref, 'ArrowUp')
        })
        act(() => {
          simulateKeyDown(ref, 'Enter')
        })

        expect(mockCommand).toHaveBeenCalledWith(items[2])
      })
    })

    describe('WHEN Enter is pressed', () => {
      it('THEN should call command with the currently selected item and return true', async () => {
        const { ref, items } = await renderWithRef()

        let result: boolean | undefined

        act(() => {
          result = simulateKeyDown(ref, 'Enter')
        })

        expect(result).toBe(true)
        expect(mockCommand).toHaveBeenCalledWith(items[0])
      })
    })

    describe('WHEN an unhandled key is pressed', () => {
      it('THEN should return false', async () => {
        const { ref } = await renderWithRef()

        let result: boolean | undefined

        act(() => {
          result = simulateKeyDown(ref, 'Escape')
        })

        expect(result).toBe(false)
      })
    })
  })

  describe('GIVEN items with getDisabled', () => {
    const createMockItemsWithDisabled = () => [
      { id: '1', name: 'Alpha' },
      { id: '2', name: 'Beta' },
      { id: '3', name: 'Gamma' },
    ]

    const getDisabled = (item: TestItem) => item.id === '2'

    const renderWithDisabled = async () => {
      const ref = createRef<SuggestionListRef>()
      const items = createMockItemsWithDisabled()

      await act(() =>
        render(
          <SuggestionList
            ref={ref}
            items={items}
            command={mockCommand}
            getKey={getKey}
            getLabel={getLabel}
            getDisabled={getDisabled}
          />,
        ),
      )

      return { ref, items }
    }

    const simulateKeyDown = (ref: React.RefObject<SuggestionListRef | null>, key: string) => {
      return ref.current?.onKeyDown({
        event: new KeyboardEvent('keydown', { key }),
      } as unknown as Parameters<SuggestionListRef['onKeyDown']>[0])
    }

    describe('WHEN rendering items', () => {
      it('THEN should render disabled items with disabled attribute', async () => {
        await renderWithDisabled()

        const disabledItem = screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-1`)

        expect(disabledItem).toBeDisabled()
      })

      it('THEN should render enabled items without disabled attribute', async () => {
        await renderWithDisabled()

        const enabledItem = screen.getByTestId(`${SUGGESTION_LIST_ITEM_TEST_ID}-0`)

        expect(enabledItem).not.toBeDisabled()
      })
    })

    describe('WHEN ArrowDown is pressed and next item is disabled', () => {
      it('THEN should skip the disabled item and select the next enabled one', async () => {
        const { ref } = await renderWithDisabled()

        // From index 0, ArrowDown should skip index 1 (disabled) and go to index 2
        act(() => {
          simulateKeyDown(ref, 'ArrowDown')
        })
        act(() => {
          simulateKeyDown(ref, 'Enter')
        })

        expect(mockCommand).toHaveBeenCalledWith(
          expect.objectContaining({ id: '3', name: 'Gamma' }),
        )
      })
    })

    describe('WHEN ArrowUp is pressed and previous item is disabled', () => {
      it('THEN should skip the disabled item and select the next enabled one', async () => {
        const { ref } = await renderWithDisabled()

        // From index 0, ArrowUp wraps to index 2 (Gamma is enabled)
        act(() => {
          simulateKeyDown(ref, 'ArrowUp')
        })
        act(() => {
          simulateKeyDown(ref, 'Enter')
        })

        expect(mockCommand).toHaveBeenCalledWith(
          expect.objectContaining({ id: '3', name: 'Gamma' }),
        )
      })

      it('THEN should skip disabled item when navigating backwards through it', async () => {
        const { ref } = await renderWithDisabled()

        // Move to Gamma (index 2) first
        act(() => {
          simulateKeyDown(ref, 'ArrowDown')
        })
        // From Gamma (index 2), ArrowUp should skip Beta (index 1) and go to Alpha (index 0)
        act(() => {
          simulateKeyDown(ref, 'ArrowUp')
        })
        act(() => {
          simulateKeyDown(ref, 'Enter')
        })

        expect(mockCommand).toHaveBeenCalledWith(
          expect.objectContaining({ id: '1', name: 'Alpha' }),
        )
      })
    })

    describe('WHEN Enter is pressed on a disabled item', () => {
      it('THEN should not call command', async () => {
        const ref = createRef<SuggestionListRef>()
        const allDisabledItems = [{ id: '1', name: 'Alpha' }]
        const allDisabled = () => true

        await act(() =>
          render(
            <SuggestionList
              ref={ref}
              items={allDisabledItems}
              command={mockCommand}
              getKey={getKey}
              getLabel={getLabel}
              getDisabled={allDisabled}
            />,
          ),
        )

        act(() => {
          ref.current?.onKeyDown({
            event: new KeyboardEvent('keydown', { key: 'Enter' }),
          } as unknown as Parameters<SuggestionListRef['onKeyDown']>[0])
        })

        expect(mockCommand).not.toHaveBeenCalled()
      })
    })
  })
})
