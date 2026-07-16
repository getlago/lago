import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { render } from '~/test-utils'

import { Tooltip } from '../Tooltip'

// Test IDs
export const TOOLTIP_TRIGGER_TEST_ID = 'tooltip-trigger'
export const TOOLTIP_CONTENT_TEST_ID = 'tooltip-content'

describe('Tooltip', () => {
  describe('Basic Functionality', () => {
    it('renders the tooltip trigger element', () => {
      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      expect(screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)).toBeInTheDocument()
    })

    it('renders children content', () => {
      render(
        <Tooltip title="Test tooltip">
          <div data-test={TOOLTIP_TRIGGER_TEST_ID}>Trigger element</div>
        </Tooltip>,
      )

      expect(screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)).toBeInTheDocument()
      expect(screen.getByText('Trigger element')).toBeInTheDocument()
    })

    it('does not show tooltip by default', () => {
      render(
        <Tooltip title="Test tooltip">
          <button>Hover me</button>
        </Tooltip>,
      )

      expect(screen.queryByText('Test tooltip')).not.toBeInTheDocument()
    })
  })

  describe('Mouse Interaction', () => {
    it('shows tooltip on mouse enter', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })

    it('hides tooltip on mouse leave', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })

      await user.unhover(trigger)

      await waitFor(() => {
        expect(screen.queryByText('Test tooltip')).not.toBeInTheDocument()
      })
    })

    it('closes tooltip on click', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })

      await user.click(trigger)

      await waitFor(() => {
        expect(screen.queryByText('Test tooltip')).not.toBeInTheDocument()
      })
    })
  })

  describe('Keyboard Interaction', () => {
    it('shows tooltip on focus', async () => {
      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Focus me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      trigger.focus()

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })

    it('hides tooltip on blur', async () => {
      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Focus me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      trigger.focus()

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })

      trigger.blur()

      await waitFor(() => {
        expect(screen.queryByText('Test tooltip')).not.toBeInTheDocument()
      })
    })
  })

  describe('disableHoverListener Prop', () => {
    it('does not show tooltip on hover when disableHoverListener is true', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" disableHoverListener>
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      // Wait a bit to ensure tooltip doesn't appear
      await new Promise((resolve) => setTimeout(resolve, 500))

      expect(screen.queryByText('Test tooltip')).not.toBeInTheDocument()
    })

    it('does not show tooltip on focus when disableHoverListener is true', async () => {
      render(
        <Tooltip title="Test tooltip" disableHoverListener>
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Focus me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      trigger.focus()

      // Wait a bit to ensure tooltip doesn't appear
      await new Promise((resolve) => setTimeout(resolve, 500))

      expect(screen.queryByText('Test tooltip')).not.toBeInTheDocument()
    })

    it('shows tooltip on hover when disableHoverListener is false', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" disableHoverListener={false}>
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })
  })

  describe('Placement', () => {
    it('renders with default placement', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })

    it('renders with top placement', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" placement="top">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })

    it('renders with bottom placement', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" placement="bottom">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })

    it('renders with left placement', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" placement="left">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })

    it('renders with right placement', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" placement="right">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Test tooltip')).toBeInTheDocument()
      })
    })
  })

  describe('Custom Styling', () => {
    it('applies custom className to wrapper', () => {
      render(
        <Tooltip title="Test tooltip" className="custom-tooltip-class">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)
      // The wrapper is two levels up (trigger -> MUI wrapper -> our wrapper)
      const wrapper = trigger.parentElement?.parentElement

      expect(wrapper).toHaveClass('custom-tooltip-class')
    })

    it('applies default maxWidth', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        const tooltip = document.querySelector('.MuiTooltip-tooltip')

        expect(tooltip).toHaveStyle({ maxWidth: '320px' })
      })
    })

    it('applies custom maxWidth', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" maxWidth="500px">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        const tooltip = document.querySelector('.MuiTooltip-tooltip')

        expect(tooltip).toHaveStyle({ maxWidth: '500px' })
      })
    })
  })

  describe('Callbacks', () => {
    it('accepts onClose callback prop', () => {
      const onClose = jest.fn()

      render(
        <Tooltip title="Test tooltip" onClose={onClose}>
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      // Test passes if the component accepts the prop without errors
      expect(screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Ref Forwarding', () => {
    it('forwards ref to wrapper div', () => {
      const ref = createRef<HTMLDivElement>()

      render(
        <Tooltip ref={ref} title="Test tooltip">
          <button>Hover me</button>
        </Tooltip>,
      )

      expect(ref.current).toBeInstanceOf(HTMLDivElement)
    })

    it('ref is accessible and can be used', () => {
      const ref = createRef<HTMLDivElement>()

      render(
        <Tooltip ref={ref} title="Test tooltip" className="test-class">
          <button>Hover me</button>
        </Tooltip>,
      )

      expect(ref.current).not.toBeNull()
      expect(ref.current?.classList.contains('test-class')).toBe(true)
    })
  })

  describe('ReactNode Title', () => {
    it('renders ReactNode as tooltip title', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title={<div data-test="custom-tooltip-content">Custom tooltip content</div>}>
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByTestId('custom-tooltip-content')).toBeInTheDocument()
        expect(screen.getByText('Custom tooltip content')).toBeInTheDocument()
      })
    })

    it('renders complex ReactNode as tooltip title', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip
          title={
            <div>
              <strong>Bold text</strong>
              <p>Regular text</p>
            </div>
          }
        >
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        expect(screen.getByText('Bold text')).toBeInTheDocument()
        expect(screen.getByText('Regular text')).toBeInTheDocument()
      })
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with default props', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        const tooltip = document.querySelector('.MuiTooltip-tooltip')

        expect(tooltip).toMatchSnapshot()
      })
    })

    it('matches snapshot with custom maxWidth', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" maxWidth="600px">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        const tooltip = document.querySelector('.MuiTooltip-tooltip')

        expect(tooltip).toMatchSnapshot()
      })
    })

    it('matches snapshot with ReactNode title', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip
          title={
            <div>
              <strong>Custom Title</strong>
            </div>
          }
        >
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        const tooltip = document.querySelector('.MuiTooltip-tooltip')

        expect(tooltip).toMatchSnapshot()
      })
    })

    it('matches snapshot with custom className', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" className="custom-wrapper-class">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        const tooltip = document.querySelector('.MuiTooltip-tooltip')

        expect(tooltip).toMatchSnapshot()
      })
    })

    it('matches snapshot with different placement', async () => {
      const user = userEvent.setup()

      render(
        <Tooltip title="Test tooltip" placement="left">
          <button data-test={TOOLTIP_TRIGGER_TEST_ID}>Hover me</button>
        </Tooltip>,
      )

      const trigger = screen.getByTestId(TOOLTIP_TRIGGER_TEST_ID)

      await user.hover(trigger)

      await waitFor(() => {
        const tooltip = document.querySelector('.MuiTooltip-tooltip')

        expect(tooltip).toMatchSnapshot()
      })
    })
  })
})
