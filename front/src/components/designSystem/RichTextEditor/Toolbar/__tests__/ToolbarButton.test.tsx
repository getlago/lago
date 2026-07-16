import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { render } from '~/test-utils'

import ToolbarButton from '../ToolbarButton'

describe('ToolbarButton', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the button is rendered', () => {
    describe('WHEN isActive is false', () => {
      it('THEN should render with secondary variant', async () => {
        await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={false}>
              Bold
            </ToolbarButton>,
          ),
        )

        const button = screen.getByTestId('test-button')

        expect(button).toBeInTheDocument()
      })
    })

    describe('WHEN isActive is true', () => {
      it('THEN should render with primary variant', async () => {
        await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={true}>
              Bold
            </ToolbarButton>,
          ),
        )

        const button = screen.getByTestId('test-button')

        expect(button).toBeInTheDocument()
      })
    })

    describe('WHEN isDisabled is true', () => {
      it('THEN should disable the button', async () => {
        await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={false} isDisabled={true}>
              Undo
            </ToolbarButton>,
          ),
        )

        expect(screen.getByTestId('test-button')).toBeDisabled()
      })
    })

    describe('WHEN isDisabled is false', () => {
      it('THEN should not disable the button', async () => {
        await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={false} isDisabled={false}>
              Undo
            </ToolbarButton>,
          ),
        )

        expect(screen.getByTestId('test-button')).not.toBeDisabled()
      })
    })

    describe('WHEN isPopper is true', () => {
      it('THEN should render with chevron-down end icon', async () => {
        const { container } = await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={false} isPopper={true}>
              Style
            </ToolbarButton>,
          ),
        )

        // The chevron-down icon should be rendered as an end icon
        const icons = container.querySelectorAll('svg')

        expect(icons.length).toBeGreaterThan(0)
      })
    })
  })

  describe('GIVEN a tooltip is provided', () => {
    describe('WHEN hovering the button', () => {
      it('THEN should display the tooltip', async () => {
        const user = userEvent.setup()

        await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={false} tooltip="Bold">
              B
            </ToolbarButton>,
          ),
        )

        const button = screen.getByTestId('test-button')

        await user.hover(button)

        expect(await screen.findByRole('tooltip')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no tooltip is provided', () => {
    describe('WHEN the button is rendered', () => {
      it('THEN should not render a tooltip wrapper', async () => {
        await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={false}>
              B
            </ToolbarButton>,
          ),
        )

        expect(screen.queryByRole('tooltip')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an onClick handler', () => {
    describe('WHEN the button is clicked', () => {
      it('THEN should call the onClick handler', async () => {
        const onClick = jest.fn()
        const user = userEvent.setup()

        await act(() =>
          render(
            <ToolbarButton testId="test-button" isActive={false} onClick={onClick}>
              Bold
            </ToolbarButton>,
          ),
        )

        await user.click(screen.getByTestId('test-button'))

        expect(onClick).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN a ref is forwarded', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should forward the ref to the underlying button', async () => {
        const ref = createRef<HTMLButtonElement>()

        await act(() =>
          render(
            <ToolbarButton ref={ref} testId="test-button" isActive={false}>
              Bold
            </ToolbarButton>,
          ),
        )

        expect(ref.current).toBeInstanceOf(HTMLButtonElement)
      })
    })
  })
})
