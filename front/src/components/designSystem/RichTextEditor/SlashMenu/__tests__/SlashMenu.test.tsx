import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import type { SlashCommandItem } from '../../extensions/SlashCommands'
import { SLASH_MENU_CONTAINER_TEST_ID, SLASH_MENU_ITEM_TEST_ID, SlashMenu } from '../SlashMenu'

// scrollIntoView is not available in jsdom
Element.prototype.scrollIntoView = jest.fn()

const createMockItems = (): SlashCommandItem[] => [
  { title: 'Heading 1', description: 'Large heading', command: jest.fn() },
  { title: 'Bullet List', description: 'Unordered list', command: jest.fn() },
]

const mockCommand = jest.fn()

describe('SlashMenu', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the wrapper renders with items', () => {
    describe('WHEN items are provided', () => {
      it('THEN should use the slash-menu container test ID', async () => {
        await act(() => render(<SlashMenu items={createMockItems()} command={mockCommand} />))

        expect(screen.getByTestId(SLASH_MENU_CONTAINER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should use the slash-menu item test IDs', async () => {
        await act(() => render(<SlashMenu items={createMockItems()} command={mockCommand} />))

        expect(screen.getByTestId(`${SLASH_MENU_ITEM_TEST_ID}-0`)).toBeInTheDocument()
        expect(screen.getByTestId(`${SLASH_MENU_ITEM_TEST_ID}-1`)).toBeInTheDocument()
      })

      it('THEN should display item titles as labels', async () => {
        await act(() => render(<SlashMenu items={createMockItems()} command={mockCommand} />))

        expect(screen.getByTestId(`${SLASH_MENU_ITEM_TEST_ID}-0`)).toHaveTextContent('Heading 1')
        expect(screen.getByTestId(`${SLASH_MENU_ITEM_TEST_ID}-1`)).toHaveTextContent('Bullet List')
      })
    })
  })

  describe('GIVEN the user clicks on an item', () => {
    describe('WHEN an item is clicked', () => {
      it('THEN should call command with the clicked SlashCommandItem', async () => {
        const user = userEvent.setup()
        const items = createMockItems()

        await act(() => render(<SlashMenu items={items} command={mockCommand} />))
        await user.click(screen.getByTestId(`${SLASH_MENU_ITEM_TEST_ID}-1`))

        expect(mockCommand).toHaveBeenCalledWith(items[1])
      })
    })
  })
})
