import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'

import { CurrencyEnum, ThresholdInput } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import AlertThresholds from '../Thresholds'

const getMockThresholds = (): ThresholdInput[] => [
  {
    code: 'threshold1',
    value: '100',
    recurring: false,
  },
]

const getMockThresholdsWithRecurring = (): ThresholdInput[] => [
  {
    code: 'threshold1',
    value: '100',
    recurring: false,
  },
  {
    code: 'threshold2',
    value: '200',
    recurring: false,
  },
  {
    code: 'recurring1',
    value: '300',
    recurring: true,
  },
]

const defaultProps = {
  currency: CurrencyEnum.Usd,
  setThresholds: jest.fn(),
  setThresholdValue: jest.fn(),
}

const renderComponent = async (thresholds: ThresholdInput[], props = {}) => {
  const combinedProps = {
    ...defaultProps,
    thresholds,
    shouldHandleUnits: false,
    ...props,
  }

  let result

  await act(async () => {
    result = render(
      <AllTheProviders>
        <AlertThresholds {...combinedProps} />
      </AllTheProviders>,
    )
  })

  return result
}

describe('AlertThresholds Component', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('addThreshold method behavior', () => {
    it('should add a non-recurring threshold when clicking add button', async () => {
      const setThresholds = jest.fn()

      await renderComponent(getMockThresholds(), { setThresholds })

      // Find the add button by its text
      const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

      await act(async () => {
        fireEvent.click(addButton)
      })

      // Verify setThresholds was called - the exact structure might vary
      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(2) // Original + new threshold
      expect(callArgs[1]).toEqual({
        code: '',
        value: '',
        recurring: false,
      })
    })

    it('should add a recurring threshold when toggling switch', async () => {
      const setThresholds = jest.fn()

      await renderComponent(getMockThresholds(), { setThresholds })

      // Find and click the recurring threshold switch
      const recurringSwitch = screen.getByTestId('add-new-recurring-threshold-switch')

      await act(async () => {
        fireEvent.click(recurringSwitch)
      })

      // Verify setThresholds was called with recurring threshold
      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(2) // Original + recurring threshold
      expect(callArgs[1]).toEqual({
        code: '',
        value: '',
        recurring: true,
      })
    })

    it('should remove recurring threshold when toggling switch off', async () => {
      const setThresholds = jest.fn()

      await renderComponent(getMockThresholdsWithRecurring(), { setThresholds })

      // Find and click the recurring threshold switch to turn it off
      const recurringSwitch = screen.getByTestId('add-new-recurring-threshold-switch')

      await act(async () => {
        fireEvent.click(recurringSwitch)
      })

      // Verify setThresholds was called with the recurring threshold removed
      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(2) // Only non-recurring thresholds
      expect(callArgs.every((t: ThresholdInput) => !t.recurring)).toBe(true)
    })

    it('should add non-recurring threshold at end when no recurring threshold exists', async () => {
      const setThresholds = jest.fn()
      const thresholds = [
        { code: 'test1', value: '100', recurring: false },
        { code: 'test2', value: '200', recurring: false },
      ]

      await renderComponent(thresholds, { setThresholds })

      const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

      await act(async () => {
        fireEvent.click(addButton)
      })

      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(3)
      expect(callArgs[2]).toEqual({
        code: '',
        value: '',
        recurring: false,
      })
    })

    it('should add non-recurring threshold before recurring threshold', async () => {
      const setThresholds = jest.fn()
      const thresholds = [
        { code: 'test1', value: '100', recurring: false },
        { code: 'test2', value: '200', recurring: false },
        { code: 'recurring', value: '300', recurring: true },
      ]

      await renderComponent(thresholds, { setThresholds })

      const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

      await act(async () => {
        fireEvent.click(addButton)
      })

      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(4)
      expect(callArgs[2]).toEqual({
        code: '',
        value: '',
        recurring: false,
      })
      expect(callArgs[3].recurring).toBe(true) // Recurring should still be last
    })

    it('should handle edge case when recurring is at index 0', async () => {
      const setThresholds = jest.fn()
      const thresholds = [{ code: 'recurring', value: '100', recurring: true }]

      await renderComponent(thresholds, { setThresholds })

      const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

      await act(async () => {
        fireEvent.click(addButton)
      })

      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(2)
      expect(callArgs[1]).toEqual({
        code: '',
        value: '',
        recurring: false,
      })
    })

    it('should handle empty threshold array', async () => {
      const setThresholds = jest.fn()
      const thresholds: ThresholdInput[] = []

      await renderComponent(thresholds, { setThresholds })

      const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

      await act(async () => {
        fireEvent.click(addButton)
      })

      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(1)
      expect(callArgs[0]).toEqual({
        code: '',
        value: '',
        recurring: false,
      })
    })

    it('should insert non-recurring threshold at correct position', async () => {
      const setThresholds = jest.fn()
      const thresholds = [
        { code: 'first', value: '100', recurring: false },
        { code: 'second', value: '200', recurring: false },
        { code: 'third', value: '300', recurring: false },
        { code: 'recurring', value: '400', recurring: true },
      ]

      await renderComponent(thresholds, { setThresholds })

      const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

      await act(async () => {
        fireEvent.click(addButton)
      })

      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs).toHaveLength(5)
      // New threshold should be inserted at index 3 (before recurring at index 4)
      expect(callArgs[3]).toEqual({
        code: '',
        value: '',
        recurring: false,
      })
      expect(callArgs[4].recurring).toBe(true) // Recurring should still be last
    })

    it('should maintain order of existing thresholds when adding new one', async () => {
      const setThresholds = jest.fn()
      const thresholds = [
        { code: 'first', value: '100', recurring: false },
        { code: 'second', value: '200', recurring: false },
        { code: 'recurring', value: '300', recurring: true },
      ]

      await renderComponent(thresholds, { setThresholds })

      const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

      await act(async () => {
        fireEvent.click(addButton)
      })

      expect(setThresholds).toHaveBeenCalled()
      const callArgs = setThresholds.mock.calls[0][0]

      expect(callArgs[0].code).toBe('first')
      expect(callArgs[1].code).toBe('second')
      expect(callArgs[2].code).toBe('') // New threshold
      expect(callArgs[3].code).toBe('recurring')
    })
  })

  describe('Component rendering', () => {
    it('should render the add threshold button', async () => {
      await renderComponent(getMockThresholds())

      // Look for button with correct text
      await waitFor(() => {
        const addButton = screen.getByTestId('add-new-non-recurring-threshold-button')

        expect(addButton).toBeInTheDocument()
      })
    })

    it('should render the recurring threshold switch', async () => {
      await renderComponent(getMockThresholds())

      await waitFor(() => {
        expect(screen.getByTestId('add-new-recurring-threshold-switch')).toBeInTheDocument()
      })
    })

    it('should show threshold input fields', async () => {
      await renderComponent(getMockThresholds())

      // Check that value and code input fields exist
      await waitFor(() => {
        const valueInput = screen.getByDisplayValue('100')
        const codeInput = screen.getByDisplayValue('threshold1')

        expect(valueInput).toBeInTheDocument()
        expect(codeInput).toBeInTheDocument()
      })
    })

    it('should show recurring threshold when it exists', async () => {
      await renderComponent(getMockThresholdsWithRecurring())

      // The recurring threshold value should be displayed
      await waitFor(() => {
        const recurringValueInput = screen.getByDisplayValue('300')

        expect(recurringValueInput).toBeInTheDocument()
      })
    })
  })
})
