import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import SlashCommandBlockWrapper, {
  SLASH_COMMAND_BLOCK_VIEW_TEST_ID,
} from '../SlashCommandBlockWrapper'

// The design-system <Typography variant="caption"> renders data-test="caption",
// so the block's caption line can be targeted without touching the component.
const CAPTION_TEST_ID = 'caption'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const defaultProps = {
  typeText: 'Pricing',
  displayText: 'Basic Plan (basic)',
  handleClick: jest.fn(),
  icon: 'document' as const,
}

describe('SlashCommandBlockWrapper', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered with valid props', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the type text', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} />)

        expect(screen.getByText('Pricing')).toBeInTheDocument()
      })

      it('THEN should render the display text', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} />)

        expect(screen.getByText('Basic Plan (basic)')).toBeInTheDocument()
      })

      it('THEN should render the caption line', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} />)

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)

        expect(within(button).getByTestId(CAPTION_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the button with the correct test id', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} />)

        expect(screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the button is clicked', () => {
    describe('WHEN the user clicks the button', () => {
      it('THEN should call handleClick', async () => {
        const user = userEvent.setup()

        render(<SlashCommandBlockWrapper {...defaultProps} />)

        await user.click(screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID))

        expect(defaultProps.handleClick).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN a mouseDown event on the button', () => {
    describe('WHEN mouseDown occurs', () => {
      it('THEN should stop propagation to prevent parent handlers', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} />)

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)
        const mouseDownEvent = new MouseEvent('mousedown', { bubbles: true, cancelable: true })
        const stopPropagationSpy = jest.spyOn(mouseDownEvent, 'stopPropagation')

        button.dispatchEvent(mouseDownEvent)

        expect(stopPropagationSpy).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN different display text values', () => {
    describe('WHEN rendered with add-on subtotal text', () => {
      it('THEN should display the subtotal text', () => {
        render(
          <SlashCommandBlockWrapper {...defaultProps} displayText="One-off invoice of $150.00" />,
        )

        expect(screen.getByText('One-off invoice of $150.00')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a caption prefix is provided', () => {
    describe('WHEN rendered with captionTextPrefix', () => {
      it('THEN should render the prefix and a separator before the caption text', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} captionTextPrefix="basic" />)

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)
        const caption = within(button).getByTestId(CAPTION_TEST_ID)

        expect(caption).toHaveTextContent('basic •')
      })
    })
  })

  describe('GIVEN a caption suffix is provided', () => {
    describe('WHEN rendered with captionTextSuffix', () => {
      it('THEN should render the suffix after the caption text', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} captionTextSuffix="2 add-ons" />)

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)
        const caption = within(button).getByTestId(CAPTION_TEST_ID)

        expect(caption).toHaveTextContent('2 add-ons')
      })
    })
  })

  describe('GIVEN no caption prefix or suffix is provided', () => {
    describe('WHEN rendered with only the required props', () => {
      it('THEN should not render the prefix separator', () => {
        render(<SlashCommandBlockWrapper {...defaultProps} />)

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)
        const caption = within(button).getByTestId(CAPTION_TEST_ID)

        expect(caption).not.toHaveTextContent('•')
      })
    })
  })
})
