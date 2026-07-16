import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  GENERIC_PLACEHOLDER_BUTTON_TEST_ID,
  GENERIC_PLACEHOLDER_IMAGE_TEST_ID,
  GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID,
  GENERIC_PLACEHOLDER_TEST_ID,
  GENERIC_PLACEHOLDER_TITLE_TEST_ID,
  GenericPlaceholder,
} from '../GenericPlaceholder'

describe('GenericPlaceholder', () => {
  describe('Basic Functionality', () => {
    it('renders with required props', () => {
      render(
        <GenericPlaceholder subtitle="Test subtitle" image={<img src="test.png" alt="Test" />} />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)).toHaveTextContent(
        'Test subtitle',
      )
      expect(screen.getByTestId(GENERIC_PLACEHOLDER_IMAGE_TEST_ID)).toBeInTheDocument()
    })

    it('renders with title when provided', () => {
      render(
        <GenericPlaceholder
          title="Test Title"
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
        />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_TITLE_TEST_ID)).toHaveTextContent('Test Title')
    })

    it('does not render title when not provided', () => {
      render(
        <GenericPlaceholder subtitle="Test subtitle" image={<img src="test.png" alt="Test" />} />,
      )

      expect(screen.queryByTestId(GENERIC_PLACEHOLDER_TITLE_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders subtitle as string using html prop', () => {
      render(
        <GenericPlaceholder
          subtitle="Simple subtitle text"
          image={<img src="test.png" alt="Test" />}
        />,
      )

      const subtitle = screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)

      expect(subtitle).toHaveTextContent('Simple subtitle text')
      // When subtitle is a string, it's rendered via html prop (dangerouslySetInnerHTML)
      expect(subtitle.querySelector('span')).toBeInTheDocument()
    })

    it('renders subtitle as ReactNode using children prop', () => {
      render(
        <GenericPlaceholder
          subtitle={
            <div data-test="custom-subtitle">
              <span>Custom subtitle</span>
            </div>
          }
          image={<img src="test.png" alt="Test" />}
        />,
      )

      // When subtitle is a ReactNode, it's rendered as children (not via html prop)
      expect(screen.getByTestId('custom-subtitle')).toBeInTheDocument()
      expect(screen.getByText('Custom subtitle')).toBeInTheDocument()
    })

    it('renders string subtitle with html prop and ReactNode subtitle with children', () => {
      const { rerender } = render(
        <GenericPlaceholder subtitle="String subtitle" image={<img src="test.png" alt="Test" />} />,
      )

      // String subtitle is rendered via html prop (wrapped in span)
      let subtitle = screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)

      expect(subtitle).toHaveTextContent('String subtitle')
      expect(subtitle.querySelector('span')).toBeInTheDocument()

      // ReactNode subtitle is rendered as children (not wrapped in extra span)
      rerender(
        <GenericPlaceholder
          subtitle={<strong data-test="react-subtitle">ReactNode subtitle</strong>}
          image={<img src="test.png" alt="Test" />}
        />,
      )

      subtitle = screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)
      expect(screen.getByTestId('react-subtitle')).toBeInTheDocument()
      expect(subtitle).toHaveTextContent('ReactNode subtitle')
    })

    it('renders HTML markup in string subtitle via html prop', () => {
      const htmlSubtitle = 'Text with <strong>bold</strong> and <em>italic</em> markup'

      render(
        <GenericPlaceholder subtitle={htmlSubtitle} image={<img src="test.png" alt="Test" />} />,
      )

      const subtitle = screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)

      // The html prop allows rendering HTML tags from strings
      expect(subtitle.querySelector('strong')).toBeInTheDocument()
      expect(subtitle.querySelector('em')).toBeInTheDocument()
      expect(subtitle).toHaveTextContent('Text with bold and italic markup')
    })

    it('renders image as ReactNode', () => {
      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={
            <svg data-test="custom-image">
              <circle cx="50" cy="50" r="40" />
            </svg>
          }
        />,
      )

      expect(screen.getByTestId('custom-image')).toBeInTheDocument()
    })

    it('applies custom className', () => {
      render(
        <GenericPlaceholder
          className="custom-class"
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
        />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)).toHaveClass('custom-class')
    })
  })

  describe('Button Functionality', () => {
    it('renders button when buttonTitle and buttonAction are provided', () => {
      const buttonAction = jest.fn()

      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Click me"
          buttonAction={buttonAction}
        />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)).toHaveTextContent('Click me')
    })

    it('does not render button when buttonTitle is missing', () => {
      const buttonAction = jest.fn()

      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonAction={buttonAction}
        />,
      )

      expect(screen.queryByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })

    it('does not render button when buttonAction is missing', () => {
      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Click me"
        />,
      )

      expect(screen.queryByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })

    it('calls buttonAction when button is clicked', async () => {
      const user = userEvent.setup()
      const buttonAction = jest.fn()

      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Click me"
          buttonAction={buttonAction}
        />,
      )

      await user.click(screen.getByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID))

      expect(buttonAction).toHaveBeenCalledTimes(1)
    })

    it('handles async buttonAction', async () => {
      const user = userEvent.setup()
      const asyncAction = jest.fn().mockImplementation(() => Promise.resolve('async result'))

      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Async Action"
          buttonAction={asyncAction}
        />,
      )

      await user.click(screen.getByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID))

      expect(asyncAction).toHaveBeenCalledTimes(1)
    })

    it('renders button with specified variant', () => {
      const buttonAction = jest.fn()

      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Click me"
          buttonAction={buttonAction}
          buttonVariant="primary"
        />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Styling and Layout', () => {
    it('applies noMargins when true', () => {
      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          noMargins
        />,
      )

      const container = screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)

      expect(container).toHaveClass('m-0')
      expect(container).toHaveClass('p-0')
    })

    it('does not apply noMargins classes when false', () => {
      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          noMargins={false}
        />,
      )

      const container = screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)

      expect(container).not.toHaveClass('m-0')
      expect(container).not.toHaveClass('p-0')
    })

    it('applies margin-bottom to subtitle when button is present', () => {
      const buttonAction = jest.fn()

      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Click me"
          buttonAction={buttonAction}
        />,
      )

      const subtitle = screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)

      expect(subtitle).toHaveClass('mb-5')
    })

    it('does not apply margin-bottom to subtitle when button is not present', () => {
      render(
        <GenericPlaceholder subtitle="Test subtitle" image={<img src="test.png" alt="Test" />} />,
      )

      const subtitle = screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)

      expect(subtitle).not.toHaveClass('mb-5')
    })
  })

  describe('Edge Cases', () => {
    it('renders with empty string subtitle', () => {
      render(<GenericPlaceholder subtitle="" image={<img src="test.png" alt="Test" />} />)

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)).toHaveTextContent('')
    })

    it('renders with complex ReactNode as subtitle', () => {
      render(
        <GenericPlaceholder
          subtitle={
            <div>
              <p>Line 1</p>
              <p>Line 2</p>
              <button>Action</button>
            </div>
          }
          image={<img src="test.png" alt="Test" />}
        />,
      )

      expect(screen.getByText('Line 1')).toBeInTheDocument()
      expect(screen.getByText('Line 2')).toBeInTheDocument()
      expect(screen.getByText('Action')).toBeInTheDocument()
    })

    it('handles multiple clicks on button', async () => {
      const user = userEvent.setup()
      const buttonAction = jest.fn()

      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Click me"
          buttonAction={buttonAction}
        />,
      )

      const button = screen.getByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)

      await user.click(button)
      await user.click(button)
      await user.click(button)

      expect(buttonAction).toHaveBeenCalledTimes(3)
    })

    it('accepts and spreads additional props', () => {
      render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          data-custom="custom-value"
          aria-label="Placeholder component"
        />,
      )

      const container = screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)

      expect(container).toHaveAttribute('data-custom', 'custom-value')
      expect(container).toHaveAttribute('aria-label', 'Placeholder component')
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with minimal props', () => {
      const { container } = render(
        <GenericPlaceholder subtitle="Test subtitle" image={<img src="test.png" alt="Test" />} />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })

    it('matches snapshot with title', () => {
      const { container } = render(
        <GenericPlaceholder
          title="Test Title"
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
        />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })

    it('matches snapshot with button', () => {
      const { container } = render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          buttonTitle="Click me"
          buttonAction={jest.fn()}
        />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })

    it('matches snapshot with all props', () => {
      const { container } = render(
        <GenericPlaceholder
          title="Error occurred"
          subtitle="Something went wrong"
          image={<svg data-test="error-icon" />}
          buttonTitle="Retry"
          buttonVariant="primary"
          buttonAction={jest.fn()}
          className="custom-class"
        />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })

    it('matches snapshot with noMargins', () => {
      const { container } = render(
        <GenericPlaceholder
          subtitle="Test subtitle"
          image={<img src="test.png" alt="Test" />}
          noMargins
        />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })

    it('matches snapshot with ReactNode subtitle', () => {
      const { container } = render(
        <GenericPlaceholder
          subtitle={
            <div>
              <span>Custom</span> <strong>subtitle</strong>
            </div>
          }
          image={<img src="test.png" alt="Test" />}
        />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })

    it('matches snapshot with HTML markup in string subtitle', () => {
      const { container } = render(
        <GenericPlaceholder
          subtitle={
            <>
              Text with <strong>bold</strong> and <em>italic</em> markup
            </>
          }
          image={<img src="test.png" alt="Test" />}
        />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })
  })

  describe('Complex Scenarios', () => {
    it('renders complete error state placeholder', () => {
      const retryAction = jest.fn()

      render(
        <GenericPlaceholder
          title="Something went wrong"
          subtitle="Please refresh the page or contact us if the error persists."
          image={
            <svg width="136" height="104">
              <rect width="136" height="104" />
            </svg>
          }
          buttonTitle="Refresh the page"
          buttonVariant="primary"
          buttonAction={retryAction}
        />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_TITLE_TEST_ID)).toHaveTextContent(
        'Something went wrong',
      )
      expect(screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)).toHaveTextContent(
        'Please refresh the page or contact us if the error persists.',
      )
      expect(screen.getByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)).toHaveTextContent(
        'Refresh the page',
      )
    })

    it('renders complete empty state placeholder', () => {
      render(
        <GenericPlaceholder
          title="No results found"
          subtitle="Try adjusting your search or filter criteria."
          image={
            <svg width="136" height="104">
              <circle cx="68" cy="52" r="40" />
            </svg>
          }
        />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_TITLE_TEST_ID)).toHaveTextContent(
        'No results found',
      )
      expect(screen.getByTestId(GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID)).toHaveTextContent(
        'Try adjusting your search or filter criteria.',
      )
      expect(screen.queryByTestId(GENERIC_PLACEHOLDER_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders with custom styled elements', () => {
      render(
        <GenericPlaceholder
          title="Custom Placeholder"
          subtitle={
            <div className="text-red-500">
              This is a <strong>custom</strong> subtitle with styling
            </div>
          }
          image={<div className="bg-blue-500">Custom Image</div>}
          className="border-2 bg-grey-300"
        />,
      )

      expect(screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)).toHaveClass('border-2', 'bg-grey-300')
      expect(screen.getByText('Custom Image')).toBeInTheDocument()
    })
  })
})
