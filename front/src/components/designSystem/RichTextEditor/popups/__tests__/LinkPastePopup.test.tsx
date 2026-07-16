import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  LINK_PASTE_POPUP_CARD_BUTTON_TEST_ID,
  LINK_PASTE_POPUP_TEST_ID,
  LINK_PASTE_POPUP_TEXT_BUTTON_TEST_ID,
  LINK_PASTE_POPUP_URL_TEST_ID,
  LinkPastePopup,
} from '../LinkPastePopup'

const mockOnDisplayAsCard = jest.fn()
const mockOnKeepAsText = jest.fn()

const defaultProps = {
  url: 'https://example.com',
  onDisplayAsCard: mockOnDisplayAsCard,
  onKeepAsText: mockOnKeepAsText,
}

describe('LinkPastePopup', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the popup renders', () => {
    describe('WHEN props are provided', () => {
      it('THEN should render the popup container', () => {
        render(<LinkPastePopup {...defaultProps} />)

        expect(screen.getByTestId(LINK_PASTE_POPUP_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the URL', () => {
        render(<LinkPastePopup {...defaultProps} />)

        expect(screen.getByTestId(LINK_PASTE_POPUP_URL_TEST_ID)).toHaveTextContent(
          'https://example.com',
        )
      })

      it.each([
        ['display as card', LINK_PASTE_POPUP_CARD_BUTTON_TEST_ID],
        ['keep as text', LINK_PASTE_POPUP_TEXT_BUTTON_TEST_ID],
      ])('THEN should render the %s button', (_, testId) => {
        render(<LinkPastePopup {...defaultProps} />)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user clicks a button', () => {
    describe('WHEN clicking "Display as card"', () => {
      it('THEN should call onDisplayAsCard', async () => {
        const user = userEvent.setup()

        render(<LinkPastePopup {...defaultProps} />)
        await user.click(screen.getByTestId(LINK_PASTE_POPUP_CARD_BUTTON_TEST_ID))

        expect(mockOnDisplayAsCard).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN clicking "Keep as text"', () => {
      it('THEN should call onKeepAsText', async () => {
        const user = userEvent.setup()

        render(<LinkPastePopup {...defaultProps} />)
        await user.click(screen.getByTestId(LINK_PASTE_POPUP_TEXT_BUTTON_TEST_ID))

        expect(mockOnKeepAsText).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN keyboard navigation', () => {
    describe('WHEN Enter is pressed without navigation', () => {
      it('THEN should call onDisplayAsCard (first item selected by default)', () => {
        render(<LinkPastePopup {...defaultProps} />)
        const container = screen.getByTestId(LINK_PASTE_POPUP_TEST_ID)

        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }))
        })

        expect(mockOnDisplayAsCard).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN ArrowDown then Enter is pressed', () => {
      it('THEN should call onKeepAsText (second item)', () => {
        render(<LinkPastePopup {...defaultProps} />)
        const container = screen.getByTestId(LINK_PASTE_POPUP_TEST_ID)

        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }))
        })
        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }))
        })

        expect(mockOnKeepAsText).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN ArrowUp is pressed from the first item', () => {
      it('THEN should wrap to the last item and call onKeepAsText on Enter', () => {
        render(<LinkPastePopup {...defaultProps} />)
        const container = screen.getByTestId(LINK_PASTE_POPUP_TEST_ID)

        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true }))
        })
        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }))
        })

        expect(mockOnKeepAsText).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN ArrowDown wraps around past the last item', () => {
      it('THEN should wrap to the first item and call onDisplayAsCard on Enter', () => {
        render(<LinkPastePopup {...defaultProps} />)
        const container = screen.getByTestId(LINK_PASTE_POPUP_TEST_ID)

        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }))
        })
        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }))
        })
        act(() => {
          container.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }))
        })

        expect(mockOnDisplayAsCard).toHaveBeenCalledTimes(1)
      })
    })
  })
})
