import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  BASE_DRAWER_ACTIONS_TEST_ID,
  BASE_DRAWER_BACKDROP_TEST_ID,
  BASE_DRAWER_CLOSE_BUTTON_TEST_ID,
  BASE_DRAWER_CONTENT_TEST_ID,
  BASE_DRAWER_HEADER_TEST_ID,
  BASE_DRAWER_PAPER_TEST_ID,
  BASE_DRAWER_TEST_ID,
  BaseDrawer,
  BaseDrawerProps,
} from '../BaseDrawer'
import { drawerStack } from '../drawerStack'

jest.mock('../drawerStack')

// Mock rAF to fire synchronously so the drawer transitions to 'open' state
beforeEach(() => {
  jest.useFakeTimers()
  jest.spyOn(window, 'requestAnimationFrame').mockImplementation((cb) => {
    cb(0)

    return 0
  })
})

afterEach(() => {
  jest.useRealTimers()
  jest.restoreAllMocks()

  // Clean up drawer stack
  const snapshot = drawerStack.getSnapshot()

  snapshot.forEach((id) => drawerStack.remove(id))
})

const defaultProps: BaseDrawerProps = {
  isOpen: true,
  title: 'Test Drawer',
  children: <div>Drawer content</div>,
  onClose: jest.fn(),
}

describe('BaseDrawer', () => {
  describe('GIVEN the drawer is open', () => {
    describe('WHEN rendered with required props', () => {
      it.each([
        ['container', BASE_DRAWER_TEST_ID],
        ['header', BASE_DRAWER_HEADER_TEST_ID],
        ['content area', BASE_DRAWER_CONTENT_TEST_ID],
        ['backdrop', BASE_DRAWER_BACKDROP_TEST_ID],
      ])('THEN should display the %s', (_, testId) => {
        render(<BaseDrawer {...defaultProps} />)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })

      it('THEN should render a dialog element', () => {
        render(<BaseDrawer {...defaultProps} />)

        expect(screen.getByRole('dialog')).toBeInTheDocument()
      })

      it('THEN should render the title text', () => {
        render(<BaseDrawer {...defaultProps} />)

        const header = screen.getByTestId(BASE_DRAWER_HEADER_TEST_ID)

        expect(header).toHaveTextContent('Test Drawer')
      })

      it('THEN should render children content', () => {
        render(<BaseDrawer {...defaultProps} />)

        const content = screen.getByTestId(BASE_DRAWER_CONTENT_TEST_ID)

        expect(content).toHaveTextContent('Drawer content')
      })
    })

    describe('WHEN actions are provided', () => {
      it('THEN should display the actions bar', () => {
        render(<BaseDrawer {...defaultProps} actions={<button>Save</button>} />)

        expect(screen.getByTestId(BASE_DRAWER_ACTIONS_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN no actions are provided', () => {
      it('THEN should not display the actions bar', () => {
        render(<BaseDrawer {...defaultProps} />)

        expect(screen.queryByTestId(BASE_DRAWER_ACTIONS_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the drawer is closed', () => {
    describe('WHEN isOpen is false', () => {
      it('THEN should not render anything', () => {
        render(<BaseDrawer {...defaultProps} isOpen={false} />)

        expect(screen.queryByTestId(BASE_DRAWER_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the drawer receives a ReactNode title', () => {
    describe('WHEN a custom element is passed as title', () => {
      it('THEN should render the custom title element', () => {
        render(
          <BaseDrawer
            {...defaultProps}
            title={<span data-test="custom-title">Custom Title</span>}
          />,
        )

        expect(screen.getByTestId('custom-title')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user interacts with the drawer', () => {
    describe('WHEN the ESC key is pressed', () => {
      it('THEN should call onClose', async () => {
        const onClose = jest.fn()
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        render(<BaseDrawer {...defaultProps} onClose={onClose} />)

        await user.keyboard('{Escape}')

        expect(onClose).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the backdrop is clicked', () => {
      it('THEN should call onClose', async () => {
        const onClose = jest.fn()
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        render(<BaseDrawer {...defaultProps} onClose={onClose} />)

        const backdrop = screen.getByTestId(BASE_DRAWER_BACKDROP_TEST_ID)

        await user.click(backdrop)

        expect(onClose).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN a form prop is provided', () => {
    describe('WHEN the drawer has a form', () => {
      it('THEN should wrap content in a form element', () => {
        const submit = jest.fn()

        render(<BaseDrawer {...defaultProps} form={{ id: 'test-form', submit }} />)

        const form = document.getElementById('test-form') as HTMLFormElement

        expect(form).toBeInTheDocument()
        expect(form.tagName).toBe('FORM')
      })

      it('THEN should call form.submit on form submission', () => {
        const submit = jest.fn()

        render(
          <BaseDrawer
            {...defaultProps}
            form={{ id: 'test-form', submit }}
            actions={<button type="submit">Submit</button>}
          />,
        )

        const form = document.getElementById('test-form') as HTMLFormElement

        act(() => {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        })

        expect(submit).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the drawer is closing', () => {
    describe('WHEN isOpen changes to false after being open', () => {
      it('THEN should call onExited after the transition', async () => {
        const onExited = jest.fn()

        const { rerender } = render(<BaseDrawer {...defaultProps} onExited={onExited} />)

        // Drawer is open, now close it
        rerender(<BaseDrawer {...defaultProps} isOpen={false} onExited={onExited} />)

        // Advance past the fallback timeout (DRAWER_TRANSITION_DURATION + 100)
        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(onExited).toHaveBeenCalled()
        })
      })
    })
  })

  describe('GIVEN focus management', () => {
    const fireTransitionEnd = () => {
      const paper = screen.getByTestId(BASE_DRAWER_PAPER_TEST_ID)

      act(() => {
        const event = new Event('transitionend', { bubbles: true })

        Object.defineProperty(event, 'propertyName', { value: 'transform' })
        Object.defineProperty(event, 'target', { value: paper })
        paper.dispatchEvent(event)
      })
    }

    describe('WHEN the drawer opens without onEntered', () => {
      it('THEN should focus the close button as fallback', async () => {
        render(<BaseDrawer {...defaultProps} />)

        fireTransitionEnd()

        await waitFor(() => {
          const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

          expect(closeButton).toHaveFocus()
        })
      })
    })

    describe('WHEN the drawer opens with onEntered that moves focus inside', () => {
      it('THEN should NOT override the focus set by onEntered', async () => {
        const onEntered = () => {
          const input = document.querySelector('[data-test="custom-input"]') as HTMLElement

          input?.focus()
        }

        render(
          <BaseDrawer {...defaultProps} onEntered={onEntered}>
            <input data-test="custom-input" />
          </BaseDrawer>,
        )

        fireTransitionEnd()

        await waitFor(() => {
          const input = screen.getByTestId('custom-input')

          expect(input).toHaveFocus()
        })
      })
    })

    describe('WHEN the drawer opens with onEntered that does NOT move focus', () => {
      it('THEN should focus the close button as fallback', async () => {
        const onEntered = jest.fn() // no-op, does not move focus

        render(<BaseDrawer {...defaultProps} onEntered={onEntered} />)

        fireTransitionEnd()

        await waitFor(() => {
          expect(onEntered).toHaveBeenCalled()

          const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

          expect(closeButton).toHaveFocus()
        })
      })
    })

    describe('WHEN Tab is pressed at the last focusable element', () => {
      it('THEN should wrap focus to the first focusable element', async () => {
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        render(
          <BaseDrawer {...defaultProps} actions={<button data-test="save-button">Save</button>}>
            <input data-test="input-field" />
          </BaseDrawer>,
        )

        fireTransitionEnd()

        // Focus the last focusable element (Save button in actions)
        const saveButton = screen.getByTestId('save-button')

        act(() => {
          saveButton.focus()
        })

        await user.tab()

        // Should wrap to the close button (first focusable element)
        const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        expect(closeButton).toHaveFocus()
      })
    })

    describe('WHEN Shift+Tab is pressed at the first focusable element', () => {
      it('THEN should wrap focus to the last focusable element', async () => {
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        render(
          <BaseDrawer {...defaultProps} actions={<button data-test="save-button">Save</button>}>
            <input data-test="input-field" />
          </BaseDrawer>,
        )

        fireTransitionEnd()

        // Focus the close button (first focusable element)
        const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        act(() => {
          closeButton.focus()
        })

        await user.tab({ shift: true })

        // Should wrap to the save button (last focusable element)
        const saveButton = screen.getByTestId('save-button')

        expect(saveButton).toHaveFocus()
      })
    })

    describe('WHEN two drawers are stacked', () => {
      it('THEN the topmost drawer should receive focus, not the one below', async () => {
        const onCloseFirst = jest.fn()
        const onCloseSecond = jest.fn()

        const { rerender } = render(
          <>
            <BaseDrawer isOpen={true} title="First Drawer" onClose={onCloseFirst}>
              <input data-test="first-drawer-input" />
            </BaseDrawer>
            <BaseDrawer isOpen={false} title="Second Drawer" onClose={onCloseSecond}>
              <input data-test="second-drawer-input" />
            </BaseDrawer>
          </>,
        )

        // Fire transitionEnd for first drawer
        const papers = screen.getAllByTestId(BASE_DRAWER_PAPER_TEST_ID)

        act(() => {
          const event = new Event('transitionend', { bubbles: true })

          Object.defineProperty(event, 'propertyName', { value: 'transform' })
          Object.defineProperty(event, 'target', { value: papers[0] })
          papers[0].dispatchEvent(event)
        })

        // First drawer's close button should have focus
        const closeButtons = screen.getAllByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        await waitFor(() => {
          expect(closeButtons[0]).toHaveFocus()
        })

        // Now open the second drawer on top
        rerender(
          <>
            <BaseDrawer isOpen={true} title="First Drawer" onClose={onCloseFirst}>
              <input data-test="first-drawer-input" />
            </BaseDrawer>
            <BaseDrawer isOpen={true} title="Second Drawer" onClose={onCloseSecond}>
              <input data-test="second-drawer-input" />
            </BaseDrawer>
          </>,
        )

        // Fire transitionEnd for second drawer
        const updatedPapers = screen.getAllByTestId(BASE_DRAWER_PAPER_TEST_ID)

        act(() => {
          const event = new Event('transitionend', { bubbles: true })

          Object.defineProperty(event, 'propertyName', { value: 'transform' })
          Object.defineProperty(event, 'target', { value: updatedPapers[1] })
          updatedPapers[1].dispatchEvent(event)
        })

        // Second drawer's close button should now have focus (topmost)
        const updatedCloseButtons = screen.getAllByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        await waitFor(() => {
          expect(updatedCloseButtons[1]).toHaveFocus()
        })
      })
    })

    describe('WHEN the drawer closes', () => {
      it('THEN should restore focus to the element that was focused before opening', async () => {
        // Render with drawer closed first, focus the trigger, then open
        const { rerender } = render(
          <>
            <button data-test="trigger-button">Open drawer</button>
            <BaseDrawer {...defaultProps} isOpen={false} />
          </>,
        )

        const triggerButton = screen.getByTestId('trigger-button')

        act(() => {
          triggerButton.focus()
        })

        expect(triggerButton).toHaveFocus()

        // Open the drawer
        rerender(
          <>
            <button data-test="trigger-button">Open drawer</button>
            <BaseDrawer {...defaultProps} isOpen={true} />
          </>,
        )

        fireTransitionEnd()

        // Verify focus moved into the drawer
        const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        await waitFor(() => {
          expect(closeButton).toHaveFocus()
        })

        // Close the drawer
        rerender(
          <>
            <button data-test="trigger-button">Open drawer</button>
            <BaseDrawer {...defaultProps} isOpen={false} />
          </>,
        )

        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(triggerButton).toHaveFocus()
        })
      })
    })
  })
})
