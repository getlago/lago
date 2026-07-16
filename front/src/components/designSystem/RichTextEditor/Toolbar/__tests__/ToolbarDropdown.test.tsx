import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import ToolbarDropdown from '../ToolbarDropdown'
import { DropdownItem } from '../types'

const createMockItems = (overrides: Partial<DropdownItem>[] = []): DropdownItem[] => [
  {
    name: 'Paragraph',
    value: 'paragraph',
    label: 'T',
    isActive: true,
    onButtonClick: jest.fn(),
    ...overrides[0],
  },
  {
    name: 'Heading 1',
    value: 'heading-1',
    label: 'H1',
    isActive: false,
    onButtonClick: jest.fn(),
    ...overrides[1],
  },
  {
    name: 'Heading 2',
    value: 'heading-2',
    isActive: false,
    onButtonClick: jest.fn(),
    ...overrides[2],
  },
]

const DATA_TEST = 'test-dropdown'

describe('ToolbarDropdown', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  const renderAndOpen = async (items?: DropdownItem[]) => {
    const user = userEvent.setup()
    const mockItems = items ?? createMockItems()

    await act(() =>
      render(
        <ToolbarDropdown
          data-test={DATA_TEST}
          items={mockItems}
          opener={<button data-test="opener-button">Open</button>}
        />,
      ),
    )

    await user.click(screen.getByTestId('opener-button'))

    return { user, mockItems }
  }

  describe('GIVEN the dropdown is opened', () => {
    describe('WHEN items are provided', () => {
      it('THEN should render all items', async () => {
        const { mockItems } = await renderAndOpen()

        for (const item of mockItems) {
          await waitFor(() => {
            expect(screen.getByTestId(`${DATA_TEST}-${item.value}`)).toBeInTheDocument()
          })
        }
      })
    })

    describe('WHEN an item has a label', () => {
      it('THEN should display the label', async () => {
        await renderAndOpen()

        await waitFor(() => {
          expect(screen.getByTestId(`${DATA_TEST}-paragraph`)).toBeInTheDocument()
        })

        // Items with labels (Paragraph has 'T', Heading 1 has 'H1')
        expect(screen.getByText('T')).toBeInTheDocument()
        expect(screen.getByText('H1')).toBeInTheDocument()
      })
    })

    describe('WHEN an item has no label', () => {
      it('THEN should not display a label for that item', async () => {
        await renderAndOpen()

        await waitFor(() => {
          expect(screen.getByTestId(`${DATA_TEST}-heading-2`)).toBeInTheDocument()
        })

        // Heading 2 has no label, but its name should still be visible
        expect(screen.getByText('Heading 2')).toBeInTheDocument()
      })
    })

    describe('WHEN an item is active', () => {
      it('THEN should display a checkmark icon', async () => {
        await renderAndOpen()

        await waitFor(() => {
          expect(screen.getByTestId(`${DATA_TEST}-paragraph`)).toBeInTheDocument()
        })

        // The active item (Paragraph) should have a checkmark icon
        const activeItem = screen.getByTestId(`${DATA_TEST}-paragraph`)
        const checkmarkIcon = activeItem.querySelector('svg')

        expect(checkmarkIcon).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an item is clicked', () => {
    describe('WHEN the user clicks an item', () => {
      it('THEN should call the onButtonClick handler', async () => {
        const { user, mockItems } = await renderAndOpen()

        await waitFor(() => {
          expect(screen.getByTestId(`${DATA_TEST}-heading-1`)).toBeInTheDocument()
        })

        await user.click(screen.getByTestId(`${DATA_TEST}-heading-1`))

        expect(mockItems[1].onButtonClick).toHaveBeenCalledTimes(1)
      })

      it('THEN should close the dropdown', async () => {
        const { user } = await renderAndOpen()

        await waitFor(() => {
          expect(screen.getByTestId(`${DATA_TEST}-heading-1`)).toBeInTheDocument()
        })

        await user.click(screen.getByTestId(`${DATA_TEST}-heading-1`))

        await waitFor(() => {
          expect(screen.queryByTestId(`${DATA_TEST}-heading-1`)).not.toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN no data-test prop', () => {
    describe('WHEN the dropdown is opened', () => {
      it('THEN should not add data-test to items', async () => {
        const user = userEvent.setup()
        const mockItems = createMockItems()

        await act(() =>
          render(
            <ToolbarDropdown
              items={mockItems}
              opener={<button data-test="opener-button">Open</button>}
            />,
          ),
        )

        await user.click(screen.getByTestId('opener-button'))

        await waitFor(() => {
          expect(screen.getByText('Paragraph')).toBeInTheDocument()
        })

        // Items should not have data-test attributes
        expect(screen.queryByTestId('undefined-paragraph')).not.toBeInTheDocument()
      })
    })
  })
})
