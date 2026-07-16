import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  Selector,
  SELECTOR_END_CONTENT_TEST_ID,
  SELECTOR_HOVER_ACTIONS_TEST_ID,
  SelectorActions,
} from '../Selector'

async function prepare(props: Partial<React.ComponentProps<typeof Selector>> = {}) {
  await act(() =>
    render(<Selector title="Test title" subtitle="Test subtitle" icon="target" {...props} />),
  )
}

describe('Selector', () => {
  afterEach(cleanup)

  describe('basic rendering', () => {
    it('renders title and subtitle', async () => {
      await prepare()

      expect(screen.getByText('Test title')).toBeInTheDocument()
      expect(screen.getByText('Test subtitle')).toBeInTheDocument()
    })

    it('renders with a string icon name', async () => {
      await prepare({ icon: 'target' })

      expect(screen.getByTestId('target/medium')).toBeInTheDocument()
    })

    it('renders with a ReactElement icon', async () => {
      await prepare({ icon: <div data-test="custom-icon">Custom</div> })

      expect(screen.getByTestId('custom-icon')).toBeInTheDocument()
    })

    it('renders with role button', async () => {
      await prepare()

      const button = screen.getByRole('button')

      expect(button).toBeInTheDocument()
    })

    it('applies group/selector class for hover targeting', async () => {
      await prepare()

      const button = screen.getByRole('button')

      expect(button.className).toContain('group/selector')
    })
  })

  describe('endContent', () => {
    it('renders endContent as a ReactElement', async () => {
      await prepare({ endContent: <span data-test="custom-end">Badge</span> })

      expect(screen.getByTestId('custom-end')).toBeInTheDocument()
    })

    it('does not render endContent when not provided', async () => {
      await prepare()

      expect(screen.queryByTestId(SELECTOR_END_CONTENT_TEST_ID)).not.toBeInTheDocument()
    })

    it('adds group-hover/selector:hidden class when hoverActions is provided', async () => {
      await prepare({
        endContent: <span>Badge</span>,
        hoverActions: <button type="button">Action</button>,
      })

      const endContentWrapper = screen.getByTestId(SELECTOR_END_CONTENT_TEST_ID)

      expect(endContentWrapper.className).toContain('group-hover/selector:hidden')
    })

    it('does not add group-hover/selector:hidden when hoverActions is absent', async () => {
      await prepare({
        endContent: <span>Badge</span>,
      })

      const endContentWrapper = screen.getByTestId(SELECTOR_END_CONTENT_TEST_ID)

      expect(endContentWrapper.className).not.toContain('group-hover/selector:hidden')
    })
  })

  describe('hoverActions', () => {
    it('renders hoverActions zone with correct CSS classes', async () => {
      await prepare({
        hoverActions: <button type="button">Edit</button>,
      })

      const hoverZone = screen.getByTestId(SELECTOR_HOVER_ACTIONS_TEST_ID)

      expect(hoverZone).toBeInTheDocument()
      expect(hoverZone.className).toContain('group-hover/selector:flex')
    })

    it('does not render hoverActions zone when not provided', async () => {
      await prepare()

      expect(screen.queryByTestId(SELECTOR_HOVER_ACTIONS_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders both endContent and hoverActions zones simultaneously', async () => {
      await prepare({
        endContent: <span data-test="default-content">Default</span>,
        hoverActions: (
          <button data-test="hover-action" type="button">
            Edit
          </button>
        ),
      })

      expect(screen.getByTestId('default-content')).toBeInTheDocument()
      expect(screen.getByTestId('hover-action')).toBeInTheDocument()
    })
  })

  describe('click behavior', () => {
    it('triggers onClick when clicked', async () => {
      const user = userEvent.setup()
      const onClickMock = jest.fn()

      await prepare({ onClick: onClickMock })

      await user.click(screen.getByRole('button'))

      expect(onClickMock).toHaveBeenCalledTimes(1)
    })

    it('does not trigger onClick when disabled', async () => {
      const user = userEvent.setup()
      const onClickMock = jest.fn()

      await prepare({ onClick: onClickMock, disabled: true })

      await user.click(screen.getByRole('button'))

      expect(onClickMock).not.toHaveBeenCalled()
    })

    it('shows loading spinner during async onClick', async () => {
      let resolveClick: () => void = () => {}

      const asyncClick = () =>
        new Promise<void>((resolve) => {
          resolveClick = resolve
        })

      await prepare({ onClick: asyncClick })

      await act(async () => {
        screen.getByRole('button').click()
      })

      // Loading spinner should be visible
      expect(screen.getByTestId('processing/medium')).toBeInTheDocument()

      // endContent should be hidden during loading
      await act(async () => {
        resolveClick()
      })
    })

    it('does not trigger selector onClick when clicking a button in hoverActions', async () => {
      const user = userEvent.setup()
      const selectorClick = jest.fn()
      const actionClick = jest.fn()

      await prepare({
        onClick: selectorClick,
        hoverActions: <SelectorActions actions={[{ icon: 'pen', onClick: actionClick }]} />,
      })

      const penIcon = screen.getByTestId('pen/medium')
      const actionButton = penIcon.closest('button') as HTMLElement

      await user.click(actionButton)

      expect(actionClick).toHaveBeenCalledTimes(1)
      expect(selectorClick).not.toHaveBeenCalled()
    })

    it('hides endContent and hoverActions during loading', async () => {
      let resolveClick: () => void = () => {}

      const asyncClick = () =>
        new Promise<void>((resolve) => {
          resolveClick = resolve
        })

      await prepare({
        onClick: asyncClick,
        endContent: <span data-test="end">End</span>,
        hoverActions: (
          <button data-test="hover" type="button">
            Hover
          </button>
        ),
      })

      const selectorButton = screen.getByRole('button', { name: /Test title/i })

      await act(async () => {
        selectorButton.click()
      })

      // During loading, endContent and hoverActions should not be rendered
      expect(screen.queryByTestId('end')).not.toBeInTheDocument()
      expect(screen.queryByTestId('hover')).not.toBeInTheDocument()

      await act(async () => {
        resolveClick()
      })
    })
  })

  describe('selected state', () => {
    it('applies selected styles', async () => {
      await prepare({ selected: true })

      const button = screen.getByRole('button')

      expect(button.className).toContain('border-blue-600')
      expect(button.className).toContain('bg-blue-100')
    })

    it('applies default styles when not selected', async () => {
      await prepare({ selected: false })

      const button = screen.getByRole('button')

      expect(button.className).toContain('border-grey-400')
      expect(button.className).toContain('bg-white')
    })
  })

  describe('titleFirst', () => {
    it('renders title before subtitle by default', async () => {
      await prepare()

      const textContainer = screen.getByText('Test title').parentElement

      expect(textContainer?.className).toContain('flex-col')
      expect(textContainer?.className).not.toContain('flex-col-reverse')
    })

    it('renders subtitle before title when titleFirst is false', async () => {
      await prepare({ titleFirst: false })

      const textContainer = screen.getByText('Test title').parentElement

      expect(textContainer?.className).toContain('flex-col-reverse')
    })
  })

  describe('disabled with endContent', () => {
    it('still renders endContent when disabled', async () => {
      await prepare({
        disabled: true,
        onClick: jest.fn(),
        endContent: <span data-test="disabled-end">Badge</span>,
      })

      expect(screen.getByTestId('disabled-end')).toBeInTheDocument()
      expect(screen.getByTestId(SELECTOR_END_CONTENT_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('fullWidth', () => {
    it('applies full width class by default', async () => {
      await prepare()

      const button = screen.getByRole('button')

      expect(button.className).toContain('w-full')
    })

    it('applies constrained width when fullWidth is false', async () => {
      await prepare({ fullWidth: false })

      const button = screen.getByRole('button')

      expect(button.className).toContain('min-w-full')
      expect(button.className).toContain('md:min-w-[calc(50%-32px)]')
    })
  })

  describe('states', () => {
    it('sets tabIndex to 0 when clickable', async () => {
      await prepare({ onClick: jest.fn() })

      expect(screen.getByRole('button')).toHaveAttribute('tabindex', '0')
    })

    it('sets tabIndex to -1 when not clickable', async () => {
      await prepare()

      expect(screen.getByRole('button')).toHaveAttribute('tabindex', '-1')
    })

    it('sets tabIndex to -1 when disabled', async () => {
      await prepare({ onClick: jest.fn(), disabled: true })

      expect(screen.getByRole('button')).toHaveAttribute('tabindex', '-1')
    })
  })
})

describe('SelectorActions', () => {
  afterEach(cleanup)

  it('renders action buttons with specified icons', async () => {
    const onClickMock = jest.fn()

    await act(() =>
      render(
        <SelectorActions
          actions={[
            { icon: 'pen', onClick: onClickMock },
            { icon: 'trash', onClick: onClickMock },
          ]}
        />,
      ),
    )

    expect(screen.getByTestId('pen/medium')).toBeInTheDocument()
    expect(screen.getByTestId('trash/medium')).toBeInTheDocument()
  })

  it('uses dots-horizontal as default icon', async () => {
    await act(() => render(<SelectorActions actions={[{ onClick: jest.fn() }]} />))

    expect(screen.getByTestId('dots-horizontal/medium')).toBeInTheDocument()
  })

  it('stops propagation on click', async () => {
    const user = userEvent.setup()
    const actionClick = jest.fn()
    const parentClick = jest.fn()

    await act(() =>
      render(
        // eslint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/no-static-element-interactions
        <div onClick={parentClick}>
          <SelectorActions actions={[{ icon: 'pen', onClick: actionClick }]} />
        </div>,
      ),
    )

    const penIcon = screen.getByTestId('pen/medium')
    const button = penIcon.closest('button') as HTMLElement

    await user.click(button)

    expect(actionClick).toHaveBeenCalledTimes(1)
    expect(parentClick).not.toHaveBeenCalled()
  })

  it('renders disabled action buttons', async () => {
    await act(() =>
      render(<SelectorActions actions={[{ icon: 'pen', onClick: jest.fn(), disabled: true }]} />),
    )

    const penIcon = screen.getByTestId('pen/medium')
    const button = penIcon.closest('button') as HTMLElement

    expect(button).toBeDisabled()
  })

  it('renders tooltip when tooltipCopy is provided', async () => {
    const user = userEvent.setup()

    await act(() =>
      render(
        <SelectorActions
          actions={[{ icon: 'pen', tooltipCopy: 'Edit item', onClick: jest.fn() }]}
        />,
      ),
    )

    const penIcon = screen.getByTestId('pen/medium')
    const button = penIcon.closest('button') as HTMLElement

    await user.hover(button)

    await waitFor(() => {
      expect(screen.getByRole('tooltip')).toHaveTextContent('Edit item')
    })
  })

  it('does not render tooltip when tooltipCopy is absent', async () => {
    await act(() => render(<SelectorActions actions={[{ icon: 'pen', onClick: jest.fn() }]} />))

    expect(screen.queryByRole('tooltip')).not.toBeInTheDocument()
  })
})
