import { fireEvent, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { Accordion } from '../Accordion'

describe('Accordion', () => {
  describe('Basic Functionality', () => {
    it('renders the accordion with summary text', () => {
      render(
        <Accordion summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      expect(screen.getByText('Test Summary')).toBeInTheDocument()
    })

    it('does not show content when initially closed', () => {
      render(
        <Accordion summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      expect(screen.queryByText('Test Content')).not.toBeInTheDocument()
    })

    it('shows content when initiallyOpen is true', () => {
      render(
        <Accordion summary={<div>Test Summary</div>} initiallyOpen>
          <div>Test Content</div>
        </Accordion>,
      )

      expect(screen.getByText('Test Content')).toBeInTheDocument()
    })

    it('toggles content visibility when clicked', async () => {
      const user = userEvent.setup()

      render(
        <Accordion summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      expect(screen.queryByText('Test Content')).not.toBeInTheDocument()

      const summary = screen.getByText('Test Summary')

      await user.click(summary)

      await waitFor(() => {
        expect(screen.getByText('Test Content')).toBeInTheDocument()
      })

      await user.click(summary)

      await waitFor(() => {
        expect(screen.queryByText('Test Content')).not.toBeInTheDocument()
      })
    })

    it('calls onOpen callback when accordion is opened', async () => {
      const user = userEvent.setup()
      const onOpen = jest.fn()

      render(
        <Accordion summary={<div>Test Summary</div>} onOpen={onOpen}>
          <div>Test Content</div>
        </Accordion>,
      )

      const summary = screen.getByText('Test Summary')

      await user.click(summary)

      await waitFor(() => {
        expect(onOpen).toHaveBeenCalledTimes(1)
      })
    })

    it('does not call onOpen when accordion is closed', async () => {
      const user = userEvent.setup()
      const onOpen = jest.fn()

      render(
        <Accordion summary={<div>Test Summary</div>} initiallyOpen onOpen={onOpen}>
          <div>Test Content</div>
        </Accordion>,
      )

      const summary = screen.getByText('Test Summary')

      await user.click(summary)

      await waitFor(() => {
        expect(screen.queryByText('Test Content')).not.toBeInTheDocument()
      })

      expect(onOpen).not.toHaveBeenCalled()
    })
  })

  describe('Children as Function', () => {
    it('renders children as function with isOpen state', async () => {
      const user = userEvent.setup()

      render(
        <Accordion summary={<div>Test Summary</div>}>
          {({ isOpen }) => <div>{isOpen ? 'Open' : 'Closed'}</div>}
        </Accordion>,
      )

      const summary = screen.getByText('Test Summary')

      await user.click(summary)

      await waitFor(() => {
        expect(screen.getByText('Open')).toBeInTheDocument()
      })
    })

    it('updates function children when accordion state changes', async () => {
      const user = userEvent.setup()

      render(
        <Accordion summary={<div>Test Summary</div>} initiallyOpen>
          {({ isOpen }) => <div>State: {isOpen ? 'Open' : 'Closed'}</div>}
        </Accordion>,
      )

      expect(screen.getByText('State: Open')).toBeInTheDocument()

      const summary = screen.getByText('Test Summary')

      await user.click(summary)

      await waitFor(() => {
        expect(screen.queryByText('State: Open')).not.toBeInTheDocument()
      })
    })
  })

  describe('Variants', () => {
    it('renders card variant by default', () => {
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      const accordion = container.querySelector('.MuiAccordion-root')

      expect(accordion).toHaveClass('border', 'border-solid', 'border-grey-400')
    })

    it('renders borderless variant correctly', () => {
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>} variant="borderless">
          <div>Test Content</div>
        </Accordion>,
      )

      const accordion = container.querySelector('.MuiAccordion-root')

      expect(accordion).toHaveClass('!rounded-none')
      expect(accordion).not.toHaveClass('border', 'border-solid', 'border-grey-400')
    })
  })

  describe('Sizes', () => {
    it('renders medium size by default for card variant', () => {
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>} variant="card">
          <div>Test Content</div>
        </Accordion>,
      )

      const summary = container.querySelector('.MuiAccordionSummary-root')

      expect(summary).toHaveClass('h-18')
    })

    it('renders large size when specified', () => {
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>} variant="card" size="large">
          <div>Test Content</div>
        </Accordion>,
      )

      const summary = container.querySelector('.MuiAccordionSummary-root')

      expect(summary).toHaveClass('h-23')
    })

    it('renders medium size when specified', () => {
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>} variant="card" size="medium">
          <div>Test Content</div>
        </Accordion>,
      )

      const summary = container.querySelector('.MuiAccordionSummary-root')

      expect(summary).toHaveClass('h-18')
    })
  })

  describe('Content Margin', () => {
    it('applies default padding for medium size', async () => {
      const user = userEvent.setup()
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>} variant="card" size="medium">
          <div>Test Content</div>
        </Accordion>,
      )

      await user.click(screen.getByText('Test Summary'))

      await waitFor(() => {
        const details = container.querySelector('.MuiAccordionDetails-root')

        expect(details).toHaveClass('p-4')
      })
    })

    it('applies default padding for large size', async () => {
      const user = userEvent.setup()
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>} variant="card" size="large">
          <div>Test Content</div>
        </Accordion>,
      )

      await user.click(screen.getByText('Test Summary'))

      await waitFor(() => {
        const details = container.querySelector('.MuiAccordionDetails-root')

        expect(details).toHaveClass('p-8')
      })
    })

    it('removes content margin when noContentMargin is true', async () => {
      const user = userEvent.setup()
      const { container } = render(
        <Accordion summary={<div>Test Summary</div>} variant="card" size="medium" noContentMargin>
          <div>Test Content</div>
        </Accordion>,
      )

      await user.click(screen.getByText('Test Summary'))

      await waitFor(() => {
        const details = container.querySelector('.MuiAccordionDetails-root')

        expect(details).toHaveClass('p-0')
        expect(details).not.toHaveClass('p-4')
      })
    })
  })

  describe('Icon Button', () => {
    it('shows chevron-right icon when closed', () => {
      render(
        <Accordion summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      expect(screen.queryByTestId('chevron-right-filled/medium')).toBeInTheDocument()
    })

    it('shows chevron-down icon when open', async () => {
      const user = userEvent.setup()

      render(
        <Accordion summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      await user.click(screen.getByText('Test Summary'))

      await waitFor(() => {
        expect(screen.queryByTestId('chevron-down-filled/medium')).toBeInTheDocument()
      })
    })
  })

  describe('Custom Props', () => {
    it('applies custom id', () => {
      const { container } = render(
        <Accordion id="custom-accordion" summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      const accordion = container.querySelector('#custom-accordion')

      expect(accordion).toBeInTheDocument()
    })

    it('applies custom className', () => {
      const { container } = render(
        <Accordion className="custom-class" summary={<div>Test Summary</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      const accordion = container.querySelector('.custom-class')

      expect(accordion).toBeInTheDocument()
    })
  })

  describe('Text Selection Behavior', () => {
    it('does not toggle when text is selected (Range selection)', async () => {
      const user = userEvent.setup()

      render(
        <Accordion summary={<div>Test Summary Text</div>}>
          <div>Test Content</div>
        </Accordion>,
      )

      // Mock text selection
      const mockSelection = {
        type: 'Range',
      } as Selection

      jest.spyOn(window, 'getSelection').mockReturnValue(mockSelection)

      const summary = screen.getByText('Test Summary Text')

      await user.click(summary)

      // Content should not appear because selection type is Range
      expect(screen.queryByText('Test Content')).not.toBeInTheDocument()

      jest.restoreAllMocks()
    })
  })

  describe('Controlled mode', () => {
    it('uses isOpen prop instead of internal state and calls onToggle', () => {
      const onToggle = jest.fn()
      const { rerender } = render(
        <Accordion isOpen={false} onToggle={onToggle} summary={<span>Summary</span>}>
          <span data-test="content">Content</span>
        </Accordion>,
      )

      // unmountOnExit is true, so closed content is not in the DOM
      expect(screen.queryByTestId('content')).not.toBeInTheDocument()

      const summary = screen.getByText('Summary')

      fireEvent.click(summary)
      expect(onToggle).toHaveBeenCalledWith(true)

      // Parent owns the state: re-render with isOpen=true to reflect it
      rerender(
        <Accordion isOpen onToggle={onToggle} summary={<span>Summary</span>}>
          <span data-test="content">Content</span>
        </Accordion>,
      )
      expect(screen.getByTestId('content')).toBeInTheDocument()
    })

    it('does not update internal state when controlled (isOpen prop controls visibility)', () => {
      const onToggle = jest.fn()

      render(
        <Accordion isOpen={false} onToggle={onToggle} summary={<span>Summary</span>}>
          <span data-test="content">Content</span>
        </Accordion>,
      )

      expect(screen.queryByTestId('content')).not.toBeInTheDocument()

      fireEvent.click(screen.getByText('Summary'))

      // Even after click, content stays hidden because parent did not update isOpen
      expect(screen.queryByTestId('content')).not.toBeInTheDocument()
      expect(onToggle).toHaveBeenCalledWith(true)
    })

    it('calls onToggle with false when closing in controlled mode', () => {
      const onToggle = jest.fn()

      render(
        <Accordion isOpen onToggle={onToggle} summary={<span>Summary</span>}>
          <span data-test="content">Content</span>
        </Accordion>,
      )

      expect(screen.getByTestId('content')).toBeInTheDocument()

      fireEvent.click(screen.getByText('Summary'))
      expect(onToggle).toHaveBeenCalledWith(false)
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot for closed card accordion', () => {
      const { container } = render(
        <Accordion summary={<div>Summary Text</div>}>
          <div>Content Text</div>
        </Accordion>,
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot for open card accordion', () => {
      const { container } = render(
        <Accordion summary={<div>Summary Text</div>} initiallyOpen>
          <div>Content Text</div>
        </Accordion>,
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot for borderless variant', () => {
      const { container } = render(
        <Accordion summary={<div>Summary Text</div>} variant="borderless" initiallyOpen>
          <div>Content Text</div>
        </Accordion>,
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot for large size', () => {
      const { container } = render(
        <Accordion summary={<div>Summary Text</div>} variant="card" size="large" initiallyOpen>
          <div>Content Text</div>
        </Accordion>,
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot for medium size', () => {
      const { container } = render(
        <Accordion summary={<div>Summary Text</div>} variant="card" size="medium" initiallyOpen>
          <div>Content Text</div>
        </Accordion>,
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with noContentMargin', () => {
      const { container } = render(
        <Accordion
          summary={<div>Summary Text</div>}
          variant="card"
          size="medium"
          noContentMargin
          initiallyOpen
        >
          <div>Content Text</div>
        </Accordion>,
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with function children', () => {
      const { container } = render(
        <Accordion summary={<div>Summary Text</div>} initiallyOpen>
          {({ isOpen }) => <div>State: {isOpen ? 'Open' : 'Closed'}</div>}
        </Accordion>,
      )

      expect(container).toMatchSnapshot()
    })
  })
})
