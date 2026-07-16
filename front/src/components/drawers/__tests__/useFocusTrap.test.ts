import { act, renderHook } from '@testing-library/react'

import { FOCUSABLE_SELECTOR, focusFirstInput, useFocusTrap } from '../useFocusTrap'

let container: HTMLDivElement
let closeButton: HTMLButtonElement

beforeEach(() => {
  container = document.createElement('div')
  closeButton = document.createElement('button')
  closeButton.textContent = 'Close'
  container.appendChild(closeButton)
  document.body.appendChild(container)
})

afterEach(() => {
  document.body.removeChild(container)
})

const createDefaultParams = (overrides?: Partial<Parameters<typeof useFocusTrap>[0]>) => ({
  containerRef: { current: container },
  isActive: false,
  onEntered: undefined as (() => void) | undefined,
  closeButtonRef: { current: closeButton },
  ...overrides,
})

describe('useFocusTrap', () => {
  describe('FOCUSABLE_SELECTOR', () => {
    it('should match standard focusable elements', () => {
      const elements = [
        Object.assign(document.createElement('a'), { href: '#' }),
        document.createElement('button'),
        document.createElement('input'),
        document.createElement('select'),
        document.createElement('textarea'),
      ]

      elements.forEach((el) => container.appendChild(el))

      const matched = container.querySelectorAll(FOCUSABLE_SELECTOR)

      // close button + 5 elements
      expect(matched).toHaveLength(6)
    })

    it('should NOT match disabled elements', () => {
      const disabledButton = document.createElement('button')

      disabledButton.disabled = true
      container.appendChild(disabledButton)

      const disabledInput = document.createElement('input')

      disabledInput.disabled = true
      container.appendChild(disabledInput)

      const matched = container.querySelectorAll(FOCUSABLE_SELECTOR)

      // Only the close button
      expect(matched).toHaveLength(1)
    })

    it('should NOT match elements with tabindex="-1"', () => {
      const div = document.createElement('div')

      div.setAttribute('tabindex', '-1')
      container.appendChild(div)

      const matched = container.querySelectorAll(FOCUSABLE_SELECTOR)

      expect(matched).toHaveLength(1)
    })
  })

  describe('handleOpening', () => {
    it('should capture document.activeElement as the trigger element', () => {
      const trigger = document.createElement('button')

      trigger.textContent = 'Trigger'
      document.body.appendChild(trigger)
      trigger.focus()

      expect(document.activeElement).toBe(trigger)

      const { result } = renderHook(() => useFocusTrap(createDefaultParams()))

      act(() => {
        result.current.handleOpening()
      })

      // Verify capture by closing — focus should restore to trigger
      act(() => {
        result.current.handleClosing()
      })

      expect(document.activeElement).toBe(trigger)

      document.body.removeChild(trigger)
    })

    it('should overwrite the previously captured trigger on subsequent calls', () => {
      const firstTrigger = document.createElement('button')

      firstTrigger.textContent = 'First'
      document.body.appendChild(firstTrigger)

      const secondTrigger = document.createElement('button')

      secondTrigger.textContent = 'Second'
      document.body.appendChild(secondTrigger)

      const { result } = renderHook(() => useFocusTrap(createDefaultParams()))

      firstTrigger.focus()

      act(() => {
        result.current.handleOpening()
      })

      secondTrigger.focus()

      act(() => {
        result.current.handleOpening()
      })

      act(() => {
        result.current.handleClosing()
      })

      expect(document.activeElement).toBe(secondTrigger)

      document.body.removeChild(firstTrigger)
      document.body.removeChild(secondTrigger)
    })
  })

  describe('handleEntered', () => {
    it('should call onEntered callback', () => {
      const onEntered = jest.fn()
      const { result } = renderHook(() => useFocusTrap(createDefaultParams({ onEntered })))

      act(() => {
        result.current.handleEntered()
      })

      expect(onEntered).toHaveBeenCalledTimes(1)
    })

    it('should pass the drawer container to onEntered for scoped lookups', () => {
      const onEntered = jest.fn()
      const { result } = renderHook(() => useFocusTrap(createDefaultParams({ onEntered })))

      act(() => {
        result.current.handleEntered()
      })

      expect(onEntered).toHaveBeenCalledWith(container)
    })

    it('should focus the close button when onEntered does not move focus inside', async () => {
      const onEntered = jest.fn()
      const { result } = renderHook(() => useFocusTrap(createDefaultParams({ onEntered })))

      act(() => {
        result.current.handleEntered()
      })

      // queueMicrotask needs to flush
      await act(async () => {
        await Promise.resolve()
      })

      expect(document.activeElement).toBe(closeButton)
    })

    it('should focus the close button when no onEntered is provided', async () => {
      const { result } = renderHook(() =>
        useFocusTrap(createDefaultParams({ onEntered: undefined })),
      )

      act(() => {
        result.current.handleEntered()
      })

      await act(async () => {
        await Promise.resolve()
      })

      expect(document.activeElement).toBe(closeButton)
    })

    it('should NOT override focus when onEntered moves focus inside the container', async () => {
      const input = document.createElement('input')

      container.appendChild(input)

      const onEntered = () => {
        input.focus()
      }

      const { result } = renderHook(() => useFocusTrap(createDefaultParams({ onEntered })))

      act(() => {
        result.current.handleEntered()
      })

      await act(async () => {
        await Promise.resolve()
      })

      expect(document.activeElement).toBe(input)
    })
  })

  describe('focusFirstInput', () => {
    it('should focus the first editable input within the container', () => {
      const input = document.createElement('input')

      container.appendChild(input)

      expect(focusFirstInput(container)).toBe(true)
      expect(document.activeElement).toBe(input)
    })

    it('should skip hidden inputs and focus the first visible one', () => {
      const hidden = document.createElement('input')

      hidden.type = 'hidden'

      const text = document.createElement('input')

      container.append(hidden, text)

      focusFirstInput(container)

      expect(document.activeElement).toBe(text)
    })

    it('should honor a custom selector', () => {
      const first = document.createElement('input')
      const target = document.createElement('input')

      target.className = 'target'
      container.append(first, target)

      focusFirstInput(container, '.target')

      expect(document.activeElement).toBe(target)
    })

    it('should return false and stay a no-op when nothing matches', () => {
      expect(focusFirstInput(container, '.no-match')).toBe(false)
    })

    it('should return false for a null container', () => {
      expect(focusFirstInput(null)).toBe(false)
    })
  })

  describe('handleClosing', () => {
    it('should restore focus to the captured trigger element', () => {
      const trigger = document.createElement('button')

      trigger.textContent = 'Trigger'
      document.body.appendChild(trigger)
      trigger.focus()

      const { result } = renderHook(() => useFocusTrap(createDefaultParams()))

      act(() => {
        result.current.handleOpening()
      })

      // Move focus elsewhere
      closeButton.focus()

      act(() => {
        result.current.handleClosing()
      })

      expect(document.activeElement).toBe(trigger)

      document.body.removeChild(trigger)
    })

    it('should not throw when trigger element has been removed from DOM', () => {
      const trigger = document.createElement('button')

      document.body.appendChild(trigger)
      trigger.focus()

      const { result } = renderHook(() => useFocusTrap(createDefaultParams()))

      act(() => {
        result.current.handleOpening()
      })

      // Remove trigger from DOM before closing
      document.body.removeChild(trigger)

      expect(() => {
        act(() => {
          result.current.handleClosing()
        })
      }).not.toThrow()
    })

    it('should clear the trigger reference after restoring', () => {
      const trigger = document.createElement('button')

      document.body.appendChild(trigger)
      trigger.focus()

      const { result } = renderHook(() => useFocusTrap(createDefaultParams()))

      act(() => {
        result.current.handleOpening()
      })

      act(() => {
        result.current.handleClosing()
      })

      expect(document.activeElement).toBe(trigger)

      // Move focus elsewhere, then call handleClosing again — should do nothing
      closeButton.focus()

      act(() => {
        result.current.handleClosing()
      })

      // Focus stays on close button (no trigger to restore to)
      expect(document.activeElement).toBe(closeButton)

      document.body.removeChild(trigger)
    })
  })

  describe('focus trapping (Tab/Shift+Tab)', () => {
    let input: HTMLInputElement
    let saveButton: HTMLButtonElement

    beforeEach(() => {
      input = document.createElement('input')
      saveButton = document.createElement('button')
      saveButton.textContent = 'Save'
      container.appendChild(input)
      container.appendChild(saveButton)
    })

    const dispatchTab = (shiftKey = false) => {
      const event = new KeyboardEvent('keydown', {
        key: 'Tab',
        shiftKey,
        bubbles: true,
        cancelable: true,
      })

      document.dispatchEvent(event)

      return event
    }

    it('should wrap focus from last to first element on Tab', () => {
      renderHook(() => useFocusTrap(createDefaultParams({ isActive: true })))

      // Focus the last element
      saveButton.focus()

      const event = dispatchTab()

      expect(event.defaultPrevented).toBe(true)
      expect(document.activeElement).toBe(closeButton)
    })

    it('should wrap focus from first to last element on Shift+Tab', () => {
      renderHook(() => useFocusTrap(createDefaultParams({ isActive: true })))

      // Focus the first element
      closeButton.focus()

      const event = dispatchTab(true)

      expect(event.defaultPrevented).toBe(true)
      expect(document.activeElement).toBe(saveButton)
    })

    it('should NOT intercept Tab when focus is on a middle element', () => {
      renderHook(() => useFocusTrap(createDefaultParams({ isActive: true })))

      // Focus the middle element
      input.focus()

      const event = dispatchTab()

      expect(event.defaultPrevented).toBe(false)
    })

    it('should NOT trap focus when isActive is false', () => {
      renderHook(() => useFocusTrap(createDefaultParams({ isActive: false })))

      saveButton.focus()

      const event = dispatchTab()

      expect(event.defaultPrevented).toBe(false)
    })

    it('should deactivate trapping when isActive changes from true to false', () => {
      const { rerender } = renderHook(
        ({ isActive }) => useFocusTrap(createDefaultParams({ isActive })),
        { initialProps: { isActive: true } },
      )

      saveButton.focus()

      let event = dispatchTab()

      expect(event.defaultPrevented).toBe(true)

      // Deactivate
      rerender({ isActive: false })

      saveButton.focus()

      event = dispatchTab()

      expect(event.defaultPrevented).toBe(false)
    })

    it('should reactivate trapping when isActive returns to true', () => {
      const { rerender } = renderHook(
        ({ isActive }) => useFocusTrap(createDefaultParams({ isActive })),
        { initialProps: { isActive: true } },
      )

      // Deactivate then reactivate
      rerender({ isActive: false })
      rerender({ isActive: true })

      saveButton.focus()

      const event = dispatchTab()

      expect(event.defaultPrevented).toBe(true)
      expect(document.activeElement).toBe(closeButton)
    })
  })
})
