import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  MENTION_LIST_CONTAINER_TEST_ID,
  MENTION_LIST_ITEM_TEST_ID,
  type MentionItem,
  MentionList,
} from '../MentionList'

// scrollIntoView is not available in jsdom
Element.prototype.scrollIntoView = jest.fn()

const createMockItems = (): MentionItem[] => [
  { id: 'customerName', label: 'Customer Name' },
  { id: 'planName', label: 'Plan Name' },
]

const mockCommand = jest.fn()

describe('MentionList', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the wrapper renders with items', () => {
    describe('WHEN items are provided', () => {
      it('THEN should use the mention-list container test ID', async () => {
        await act(() => render(<MentionList items={createMockItems()} command={mockCommand} />))

        expect(screen.getByTestId(MENTION_LIST_CONTAINER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should use the mention-list item test IDs', async () => {
        await act(() => render(<MentionList items={createMockItems()} command={mockCommand} />))

        expect(screen.getByTestId(`${MENTION_LIST_ITEM_TEST_ID}-0`)).toBeInTheDocument()
        expect(screen.getByTestId(`${MENTION_LIST_ITEM_TEST_ID}-1`)).toBeInTheDocument()
      })

      it('THEN should display item labels', async () => {
        await act(() => render(<MentionList items={createMockItems()} command={mockCommand} />))

        expect(screen.getByTestId(`${MENTION_LIST_ITEM_TEST_ID}-0`)).toHaveTextContent(
          'Customer Name',
        )
        expect(screen.getByTestId(`${MENTION_LIST_ITEM_TEST_ID}-1`)).toHaveTextContent('Plan Name')
      })
    })
  })

  describe('GIVEN the user clicks on an item', () => {
    describe('WHEN an item is clicked', () => {
      it('THEN should call command with the clicked MentionItem', async () => {
        const user = userEvent.setup()
        const items = createMockItems()

        await act(() => render(<MentionList items={items} command={mockCommand} />))
        await user.click(screen.getByTestId(`${MENTION_LIST_ITEM_TEST_ID}-1`))

        expect(mockCommand).toHaveBeenCalledWith(items[1])
      })
    })
  })
})
