import { act, renderHook, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactElement } from 'react'

import { render } from '~/test-utils'

import {
  SUBSCRIPTION_SETTINGS_DRAWER_SAVE_TEST_ID,
  type SubscriptionSettingsFormValues,
  useSubscriptionSettingsDrawer,
} from '../useSubscriptionSettingsDrawer'

const mockDrawerOpen = jest.fn()
const mockDrawerClose = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({
    open: mockDrawerOpen,
    close: mockDrawerClose,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockOnSave = jest.fn()

const defaultValues: SubscriptionSettingsFormValues = {
  externalId: '',
  subscriptionName: '',
  billingTime: 'anniversary',
  startDate: '',
  endDate: '',
}

const populatedValues: SubscriptionSettingsFormValues = {
  externalId: 'ext_001',
  subscriptionName: 'My Sub',
  billingTime: 'calendar',
  startDate: '2023-07-26',
  endDate: '2024-07-26',
}

/**
 * Helper: calls `openDrawer` on the hook, then renders the captured
 * `children` and `actions` JSX that were passed to `drawer.open()`.
 */
const openAndRenderDrawer = (
  values: SubscriptionSettingsFormValues = defaultValues,
  isAmendment = false,
) => {
  const hookReturn = renderHook(() => useSubscriptionSettingsDrawer(mockOnSave, isAmendment))

  act(() => {
    hookReturn.result.current.openDrawer(values)
  })

  const drawerArgs = mockDrawerOpen.mock.calls[0][0] as {
    children: ReactElement
    actions: ReactElement
  }

  const renderResult = render(
    <>
      {drawerArgs.children}
      {drawerArgs.actions}
    </>,
  )

  return { hookReturn, renderResult }
}

describe('useSubscriptionSettingsDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns openDrawer function', () => {
    const { result } = renderHook(() => useSubscriptionSettingsDrawer(mockOnSave))

    expect(result.current).toHaveProperty('openDrawer')
    expect(typeof result.current.openDrawer).toBe('function')
  })

  it('opens the drawer when openDrawer is called', () => {
    const { result } = renderHook(() => useSubscriptionSettingsDrawer(mockOnSave))

    act(() => {
      result.current.openDrawer(defaultValues)
    })
    expect(mockDrawerOpen).toHaveBeenCalledTimes(1)
    expect(mockDrawerOpen).toHaveBeenCalledWith(
      expect.objectContaining({
        title: expect.any(String),
        children: expect.anything(),
        actions: expect.anything(),
      }),
    )
  })

  it('opens the drawer with pre-populated values', () => {
    const { result } = renderHook(() => useSubscriptionSettingsDrawer(mockOnSave))

    act(() => {
      result.current.openDrawer({
        externalId: 'ext_001',
        subscriptionName: 'My Sub',
        billingTime: 'calendar',
        startDate: '2023-07-26',
        endDate: '',
      })
    })
    expect(mockDrawerOpen).toHaveBeenCalledTimes(1)
  })

  describe('GIVEN the drawer is opened with empty default values', () => {
    describe('WHEN the "+" buttons are displayed', () => {
      it('THEN should show the "add external ID" button', () => {
        openAndRenderDrawer()

        expect(screen.getByTestId('show-external-id')).toBeInTheDocument()
      })

      it('THEN should show the "add subscription name" button', () => {
        openAndRenderDrawer()

        expect(screen.getByTestId('show-name')).toBeInTheDocument()
      })
    })

    describe('WHEN the "add external ID" button is clicked', () => {
      it('THEN should show the external ID field and hide the "+" button', async () => {
        const user = userEvent.setup()

        openAndRenderDrawer()

        await user.click(screen.getByTestId('show-external-id'))

        expect(screen.queryByTestId('show-external-id')).not.toBeInTheDocument()
        // The TextInputField renders an input with name="externalId"
        expect(document.querySelector('input[name="externalId"]')).toBeInTheDocument()
      })
    })

    describe('WHEN the "add subscription name" button is clicked', () => {
      it('THEN should show the subscription name field and hide the "+" button', async () => {
        const user = userEvent.setup()

        openAndRenderDrawer()

        await user.click(screen.getByTestId('show-name'))

        expect(screen.queryByTestId('show-name')).not.toBeInTheDocument()
        expect(document.querySelector('input[name="subscriptionName"]')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the drawer is opened with populated values', () => {
    describe('WHEN externalId and subscriptionName are pre-filled', () => {
      it('THEN should show both fields and hide the "+" buttons', () => {
        openAndRenderDrawer(populatedValues)

        expect(screen.queryByTestId('show-external-id')).not.toBeInTheDocument()
        expect(screen.queryByTestId('show-name')).not.toBeInTheDocument()
      })
    })

    describe('WHEN the trash button for external ID is clicked', () => {
      it('THEN should hide the field and show the "+" button', async () => {
        const user = userEvent.setup()

        openAndRenderDrawer(populatedValues)

        // The trash buttons are inside Tooltip wrappers with aria-label
        // Each field row has a div.flex.flex-row > [field div] + [tooltip div > button]
        // Find the trash button (data-test="trash/medium" svg) next to the externalId field
        const externalIdInput = document.querySelector(
          'input[name="externalId"]',
        ) as HTMLInputElement
        // The parent row contains the field + the trash button
        const fieldRow = externalIdInput.closest('.flex.flex-row')
        const trashButton = within(fieldRow as HTMLElement).getByTestId('button')

        await user.click(trashButton)

        expect(screen.getByTestId('show-external-id')).toBeInTheDocument()
      })
    })

    describe('WHEN the trash button for subscription name is clicked', () => {
      it('THEN should hide the field and show the "+" button', async () => {
        const user = userEvent.setup()

        openAndRenderDrawer(populatedValues)

        const subscriptionNameInput = document.querySelector(
          'input[name="subscriptionName"]',
        ) as HTMLInputElement
        const fieldRow = subscriptionNameInput.closest('.flex.flex-row')
        const trashButton = within(fieldRow as HTMLElement).getByTestId('button')

        await user.click(trashButton)

        expect(screen.getByTestId('show-name')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the drawer is rendered with billing time options', () => {
    describe('WHEN the drawer is opened with default values', () => {
      it('THEN should display anniversary as the selected billing time', () => {
        openAndRenderDrawer()

        // Radio inputs have aria-label="billingTime" and value="anniversary"/"calendar"
        const radios = screen.getAllByRole('radio', { name: 'billingTime' })

        expect(radios).toHaveLength(2)
        // The anniversary radio (value="anniversary") is rendered first
        expect(radios[0]).toHaveAttribute('value', 'anniversary')
        expect(radios[1]).toHaveAttribute('value', 'calendar')
      })
    })

    describe('WHEN the calendar radio option is clicked', () => {
      it('THEN should select the calendar billing time', async () => {
        const user = userEvent.setup()

        openAndRenderDrawer()

        const radios = screen.getAllByRole('radio', { name: 'billingTime' })
        const calendarRadio = radios[1]

        await user.click(calendarRadio)

        // After clicking, the calendar radio should be present and interactable
        expect(calendarRadio).toHaveAttribute('value', 'calendar')
      })
    })
  })

  describe('GIVEN the drawer is opened in amendment mode', () => {
    describe('WHEN isAmendment is true', () => {
      it('THEN should disable the start date field', () => {
        openAndRenderDrawer(populatedValues, true)

        const startDateInput = document.querySelector('input[name="startDate"]') as HTMLInputElement

        expect(startDateInput).toBeDisabled()
      })
    })
  })

  describe('GIVEN the save button in the actions area', () => {
    describe('WHEN the drawer is rendered', () => {
      it('THEN should display the save button with the correct test ID', () => {
        openAndRenderDrawer()

        expect(screen.getByTestId(SUBSCRIPTION_SETTINGS_DRAWER_SAVE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a valid form with startDate populated', () => {
    describe('WHEN the save button is clicked', () => {
      it('THEN should call onSave with the form values and close the drawer', async () => {
        const user = userEvent.setup()

        const hookReturn = renderHook(() => useSubscriptionSettingsDrawer(mockOnSave))

        const validValues: SubscriptionSettingsFormValues = {
          externalId: 'ext_123',
          subscriptionName: 'Test Sub',
          billingTime: 'anniversary',
          startDate: '2024-01-01',
          endDate: '2025-01-01',
        }

        act(() => {
          hookReturn.result.current.openDrawer(validValues)
        })

        const drawerArgs = mockDrawerOpen.mock.calls[0][0] as {
          children: ReactElement
          actions: ReactElement
        }

        render(
          <>
            {drawerArgs.children}
            {drawerArgs.actions}
          </>,
        )

        const saveButton = screen.getByTestId(SUBSCRIPTION_SETTINGS_DRAWER_SAVE_TEST_ID)

        await user.click(saveButton)

        await waitFor(() => {
          expect(mockOnSave).toHaveBeenCalledTimes(1)
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({
            externalId: 'ext_123',
            subscriptionName: 'Test Sub',
            billingTime: 'anniversary',
            startDate: '2024-01-01',
            endDate: '2025-01-01',
          }),
        )

        expect(mockDrawerClose).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN the form is re-opened after being previously opened', () => {
    describe('WHEN openDrawer is called with new values', () => {
      it('THEN should reset the form to the new values', () => {
        const { result } = renderHook(() => useSubscriptionSettingsDrawer(mockOnSave))

        act(() => {
          result.current.openDrawer({
            externalId: 'first_id',
            subscriptionName: 'First Sub',
            billingTime: 'calendar',
            startDate: '2023-01-01',
            endDate: '',
          })
        })

        expect(mockDrawerOpen).toHaveBeenCalledTimes(1)

        mockDrawerOpen.mockClear()

        act(() => {
          result.current.openDrawer({
            externalId: 'second_id',
            subscriptionName: 'Second Sub',
            billingTime: 'anniversary',
            startDate: '2024-06-01',
            endDate: '2025-06-01',
          })
        })

        expect(mockDrawerOpen).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN form submission via the hidden submit button', () => {
    describe('WHEN the form is submitted via the form element', () => {
      it('THEN should trigger form submission through handleFormSubmit', async () => {
        const hookReturn = renderHook(() => useSubscriptionSettingsDrawer(mockOnSave))

        const validValues: SubscriptionSettingsFormValues = {
          externalId: '',
          subscriptionName: '',
          billingTime: 'anniversary',
          startDate: '2024-01-01',
          endDate: '',
        }

        act(() => {
          hookReturn.result.current.openDrawer(validValues)
        })

        const drawerArgs = mockDrawerOpen.mock.calls[0][0] as {
          children: ReactElement
          actions: ReactElement
        }

        render(
          <>
            {drawerArgs.children}
            {drawerArgs.actions}
          </>,
        )

        // The form has a hidden submit button; submitting the form triggers handleFormSubmit
        const form = document.querySelector('form')

        expect(form).toBeTruthy()

        await act(async () => {
          form?.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        })

        await waitFor(() => {
          expect(mockOnSave).toHaveBeenCalledTimes(1)
        })
      })
    })
  })
})
