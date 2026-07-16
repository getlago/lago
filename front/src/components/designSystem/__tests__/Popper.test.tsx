import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { render } from '~/test-utils'

import { isPopperGroupTracked, Popper } from '../Popper'

async function prepare({
  children,
  opener,
  props,
}: {
  children?: React.ReactNode
  opener?: React.ReactElement
  props?: Record<string, any>
} = {}) {
  await act(() =>
    render(
      <Popper
        opener={opener}
        maxHeight={props?.maxHeight}
        minWidth={props?.minWidth}
        PopperProps={props?.PopperProps}
        enableFlip={props?.enableFlip}
        displayInDialog={props?.displayInDialog}
        onClickAway={props?.onClickAway}
      >
        {children}
      </Popper>,
    ),
  )
}

describe('Popper', () => {
  afterEach(cleanup)

  describe('Basic rendering', () => {
    it('renders the opener element', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div>Popper content</div>,
      })

      expect(screen.queryByTestId('opener-button')).toBeInTheDocument()
      expect(screen.queryByTestId('opener-button')).toHaveTextContent('Click me')
    })

    it('does not show popper content initially', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div data-test="popper-content">Popper content</div>,
      })

      // Content should not be visible initially
      expect(screen.queryByTestId('popper-content')).toBeNull()
    })

    it('matches snapshot with basic props', async () => {
      const { container } = await act(() =>
        render(
          <Popper opener={<button>Open Popper</button>}>
            <div>Simple popper content</div>
          </Popper>,
        ),
      )

      expect(container).toMatchSnapshot()
    })
  })

  describe('Opening and closing', () => {
    it('opens popper when opener is clicked', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div data-test="popper-content">Popper content</div>,
      })

      const opener = screen.getByTestId('opener-button')

      await userEvent.click(opener)

      await waitFor(() => {
        expect(screen.getByTestId('popper-content')).toBeVisible()
      })
    })

    it('closes popper when clicking away', async () => {
      const onClickAway = jest.fn()

      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div data-test="popper-content">Popper content</div>,
        props: { onClickAway },
      })

      // Open the popper
      const opener = screen.getByTestId('opener-button')

      await userEvent.click(opener)

      await waitFor(() => {
        expect(screen.getByTestId('popper-content')).toBeVisible()
      })

      // Click outside to close
      await userEvent.click(document.body)

      await waitFor(() => {
        expect(onClickAway).toHaveBeenCalled()
      })
    })

    it('toggles popper when opener is clicked multiple times', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div data-test="popper-content">Popper content</div>,
      })

      const opener = screen.getByTestId('opener-button')

      // Initially closed
      expect(screen.queryByTestId('popper-content')).toBeNull()

      // Click to open
      await userEvent.click(opener)

      await waitFor(() => {
        expect(screen.getByTestId('popper-content')).toBeVisible()
      })

      // Click again to close
      await userEvent.click(opener)

      await waitFor(() => {
        expect(screen.queryByTestId('popper-content')).toBeNull()
      })
    })
  })

  describe('Render props opener', () => {
    it('works with function-based opener', async () => {
      await prepare({
        // @ts-expect-error - Function-based opener is valid but TypeScript needs explicit cast
        opener: ({ isOpen, onClick }: { isOpen: boolean; onClick: () => void }) => (
          <button data-test="opener-button" onClick={onClick}>
            {isOpen ? 'Close' : 'Open'}
          </button>
        ),
        children: <div data-test="popper-content">Popper content</div>,
      })

      const opener = screen.getByTestId('opener-button')

      // Initially closed
      expect(opener).toHaveTextContent('Open')

      // Click to open
      await userEvent.click(opener)

      await waitFor(() => {
        expect(opener).toHaveTextContent('Close')
        expect(screen.getByTestId('popper-content')).toBeVisible()
      })

      // Click to close
      await userEvent.click(opener)

      await waitFor(() => {
        expect(opener).toHaveTextContent('Open')
      })
    })

    it('matches snapshot with function-based opener', async () => {
      const { container } = await act(() =>
        render(
          <Popper
            opener={({ isOpen, onClick }) => (
              <button onClick={onClick}>{isOpen ? 'Close' : 'Open'}</button>
            )}
          >
            <div>Function opener content</div>
          </Popper>,
        ),
      )

      expect(container).toMatchSnapshot()
    })
  })

  describe('Render props children', () => {
    it('provides closePopper function to children', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        // @ts-expect-error - Function-based children is valid but TypeScript needs explicit type
        children: ({ closePopper }: { closePopper: () => void }) => (
          <div>
            <div data-test="popper-content">Popper content</div>
            <button data-test="close-button" onClick={closePopper}>
              Close
            </button>
          </div>
        ),
      })

      // Open the popper
      const opener = screen.getByTestId('opener-button')

      await userEvent.click(opener)

      await waitFor(() => {
        expect(screen.getByTestId('popper-content')).toBeVisible()
      })

      // Click the close button inside
      const closeButton = screen.getByTestId('close-button')

      await userEvent.click(closeButton)

      await waitFor(() => {
        expect(screen.queryByTestId('popper-content')).toBeNull()
      })
    })
  })

  describe('Imperative handle (ref)', () => {
    it('allows opening popper via ref', async () => {
      const ref = createRef<{ openPopper: () => void; closePopper: () => void }>()

      await act(() =>
        render(
          <Popper ref={ref} opener={<button data-test="opener-button">Click me</button>}>
            <div data-test="popper-content">Popper content</div>
          </Popper>,
        ),
      )

      // Initially closed
      expect(screen.queryByTestId('popper-content')).toBeNull()

      // Open via ref
      act(() => {
        ref.current?.openPopper()
      })

      await waitFor(() => {
        expect(screen.getByTestId('popper-content')).toBeVisible()
      })
    })

    it('allows closing popper via ref', async () => {
      const ref = createRef<{ openPopper: () => void; closePopper: () => void }>()

      await act(() =>
        render(
          <Popper ref={ref} opener={<button data-test="opener-button">Click me</button>}>
            <div data-test="popper-content">Popper content</div>
          </Popper>,
        ),
      )

      // Open via ref
      act(() => {
        ref.current?.openPopper()
      })

      await waitFor(() => {
        expect(screen.getByTestId('popper-content')).toBeVisible()
      })

      // Close via ref
      act(() => {
        ref.current?.closePopper()
      })

      await waitFor(() => {
        expect(screen.queryByTestId('popper-content')).toBeNull()
      })
    })
  })

  describe('Props customization', () => {
    it('applies custom maxHeight as number', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div data-test="popper-content">Popper content</div>,
        props: { maxHeight: 300 },
      })

      const opener = screen.getByTestId('opener-button')

      await userEvent.click(opener)

      await waitFor(() => {
        const content = screen.getByTestId('popper-content')
        const parent = content.parentElement

        expect(parent).toHaveStyle({ maxHeight: '300px' })
      })
    })

    it('applies custom maxHeight as string', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div data-test="popper-content">Popper content</div>,
        props: { maxHeight: '50vh' },
      })

      const opener = screen.getByTestId('opener-button')

      await userEvent.click(opener)

      await waitFor(() => {
        const content = screen.getByTestId('popper-content')
        const parent = content.parentElement

        expect(parent).toHaveStyle({ maxHeight: '50vh' })
      })
    })

    it('uses default maxHeight when not provided', async () => {
      await prepare({
        opener: <button data-test="opener-button">Click me</button>,
        children: <div data-test="popper-content">Popper content</div>,
      })

      const opener = screen.getByTestId('opener-button')

      await userEvent.click(opener)

      await waitFor(() => {
        const content = screen.getByTestId('popper-content')
        const parent = content.parentElement

        expect(parent).toHaveStyle({ maxHeight: '90vh' })
      })
    })

    it('applies custom className', async () => {
      const { container } = await act(() =>
        render(
          <Popper
            className="custom-class"
            opener={<button data-test="opener-button">Click me</button>}
          >
            <div data-test="popper-content">Popper content</div>
          </Popper>,
        ),
      )

      const wrapper = container.querySelector('.custom-class')

      expect(wrapper).toBeInTheDocument()
      expect(wrapper).toHaveClass('custom-class')
    })

    it('renders with displayInDialog prop', async () => {
      const { container } = await act(() =>
        render(
          <Popper opener={<button>Click me</button>} displayInDialog={true}>
            <div>Dialog popper content</div>
          </Popper>,
        ),
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with custom PopperProps', async () => {
      const { container } = await act(() =>
        render(
          <Popper
            opener={<button>Click me</button>}
            PopperProps={{
              placement: 'bottom-end',
              disablePortal: true,
            }}
            maxHeight={400}
            minWidth={200}
            enableFlip={false}
          >
            <div>Custom props content</div>
          </Popper>,
        ),
      )

      expect(container).toMatchSnapshot()
    })
  })

  describe('Complex scenarios', () => {
    it('handles multiple poppers independently', async () => {
      await act(() =>
        render(
          <div>
            <Popper opener={<button data-test="opener-1">Opener 1</button>}>
              <div data-test="content-1">Content 1</div>
            </Popper>
            <Popper opener={<button data-test="opener-2">Opener 2</button>}>
              <div data-test="content-2">Content 2</div>
            </Popper>
          </div>,
        ),
      )

      // Open first popper
      await userEvent.click(screen.getByTestId('opener-1'))

      await waitFor(() => {
        expect(screen.getByTestId('content-1')).toBeVisible()
      })

      // Second should still be closed
      expect(screen.queryByTestId('content-2')).toBeNull()
    })

    it('closes other poppers sharing the same popperGroupName when one opens', async () => {
      await act(() =>
        render(
          <div>
            <Popper
              popperGroupName="test-group"
              opener={<button data-test="opener-1">Opener 1</button>}
            >
              <div data-test="content-1">Content 1</div>
            </Popper>
            <Popper
              popperGroupName="test-group"
              opener={<button data-test="opener-2">Opener 2</button>}
            >
              <div data-test="content-2">Content 2</div>
            </Popper>
          </div>,
        ),
      )

      // Open first popper
      await userEvent.click(screen.getByTestId('opener-1'))
      await waitFor(() => {
        expect(screen.getByTestId('content-1')).toBeVisible()
      })

      // Opening the second popper closes the first (single-open per group)
      await userEvent.click(screen.getByTestId('opener-2'))
      await waitFor(() => {
        expect(screen.getByTestId('content-2')).toBeVisible()
      })
      expect(screen.queryByTestId('content-1')).toBeNull()
    })

    it('drops the registry entry when an open grouped popper unmounts', async () => {
      const { unmount } = await act(() =>
        render(
          <Popper
            popperGroupName="unmount-cleanup-group"
            opener={<button data-test="opener-a">Opener A</button>}
          >
            <div data-test="content-a">Content A</div>
          </Popper>,
        ),
      )

      await userEvent.click(screen.getByTestId('opener-a'))
      await waitFor(() => {
        expect(screen.getByTestId('content-a')).toBeVisible()
      })

      // Open popper is tracked in the group registry.
      expect(isPopperGroupTracked('unmount-cleanup-group')).toBe(true)

      // Unmounting while open must run the cleanup effect and drop the entry —
      // asserting the registry directly (a stale close on an unmounted popper is
      // a DOM no-op, so this is the only way to discriminate the cleanup).
      await act(() => {
        unmount()
      })

      expect(isPopperGroupTracked('unmount-cleanup-group')).toBe(false)
    })

    it('matches snapshot with nested content', async () => {
      const { container } = await act(() =>
        render(
          <Popper opener={<button>Open Menu</button>}>
            <div>
              <ul>
                <li>Item 1</li>
                <li>Item 2</li>
                <li>Item 3</li>
              </ul>
            </div>
          </Popper>,
        ),
      )

      expect(container).toMatchSnapshot()
    })
  })
})
