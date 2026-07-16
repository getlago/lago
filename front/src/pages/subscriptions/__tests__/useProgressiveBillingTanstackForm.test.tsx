import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'

import {
  CurrencyEnum,
  UpdateSubscriptionProgressiveBillingDocument,
  UseSubscriptionForProgressiveBillingFormFragment,
} from '~/generated/graphql'

import {
  DEFAULT_PROGRESSIVE_BILLING,
  useProgressiveBillingTanstackForm,
} from '../useProgressiveBillingTanstackForm'

// Mock the scrollToFirstInputError function
jest.mock('~/core/form/scrollToFirstInputError', () => ({
  scrollToFirstInputError: jest.fn(),
}))

const createMockSubscription = (
  overrides?: Partial<UseSubscriptionForProgressiveBillingFormFragment>,
): UseSubscriptionForProgressiveBillingFormFragment | undefined => {
  if (overrides === undefined) return undefined

  return {
    progressiveBillingDisabled: false,
    usageThresholds: [
      { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: 'Threshold 1' },
      { id: '2', amountCents: '200', recurring: false, thresholdDisplayName: 'Threshold 2' },
    ],
    plan: {
      applicableUsageThresholds: [],
    },
    ...overrides,
  }
}

const createUpdateMutationMock = (
  expectedInput: {
    id: string
    progressiveBillingDisabled: boolean
    usageThresholds: Array<{
      amountCents: number
      thresholdDisplayName?: string
      recurring: boolean
    }>
  },
  resultId = 'subscription-1',
): MockedResponse => ({
  request: {
    query: UpdateSubscriptionProgressiveBillingDocument,
    variables: { input: expectedInput },
  },
  result: {
    data: {
      updateSubscription: {
        id: resultId,
        progressiveBillingDisabled: expectedInput.progressiveBillingDisabled,
        usageThresholds: expectedInput.usageThresholds.map((t) => ({
          ...t,
          thresholdDisplayName: t.thresholdDisplayName || null,
        })),
      },
    },
  },
})

interface WrapperProps {
  children: React.ReactNode
}

const createWrapper = (mocks: MockedResponse[] = []) => {
  const Wrapper = ({ children }: WrapperProps) => (
    <MockedProvider mocks={mocks} addTypename={false}>
      {children}
    </MockedProvider>
  )

  return Wrapper
}

describe('useProgressiveBillingTanstackForm', () => {
  const mockOnSuccess = jest.fn()
  const subscriptionId = 'subscription-1'

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('initial values', () => {
    it('returns default values when subscription is undefined', async () => {
      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription: undefined,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.progressiveBillingDisabled).toBe(false)
      expect(result.current.nonRecurringThresholds).toEqual([DEFAULT_PROGRESSIVE_BILLING])
      expect(result.current.hasRecurring).toBe(false)
      expect(result.current.recurringThreshold).toEqual({
        amountCents: '',
        thresholdDisplayName: '',
        recurring: true,
      })
    })

    it('initializes with subscription data when provided', async () => {
      const subscription = createMockSubscription({
        progressiveBillingDisabled: false,
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: 'First' },
          { id: '2', amountCents: '500', recurring: true, thresholdDisplayName: 'Recurring' },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.progressiveBillingDisabled).toBe(false)
      // 100 cents -> '1' USD (deserialized)
      expect(result.current.nonRecurringThresholds).toEqual([
        { amountCents: '1', thresholdDisplayName: 'First', recurring: false },
      ])
      expect(result.current.hasRecurring).toBe(true)
      // 500 cents -> '5' USD (deserialized)
      expect(result.current.recurringThreshold).toEqual({
        amountCents: '5',
        thresholdDisplayName: 'Recurring',
        recurring: true,
      })
    })

    it('initializes progressiveBillingDisabled when subscription has it enabled', async () => {
      const subscription = createMockSubscription({
        progressiveBillingDisabled: true,
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.progressiveBillingDisabled).toBe(true)
    })

    it('initializes with plan thresholds when subscription thresholds are empty', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [],
        plan: {
          applicableUsageThresholds: [
            {
              id: '1',
              amountCents: '300',
              recurring: false,
              thresholdDisplayName: 'Plan Threshold',
            },
            {
              id: '2',
              amountCents: '1000',
              recurring: true,
              thresholdDisplayName: 'Plan Recurring',
            },
          ],
        },
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      // Should use plan thresholds when subscription thresholds are empty
      // 300 cents -> '3' USD (deserialized)
      expect(result.current.nonRecurringThresholds).toEqual([
        { amountCents: '3', thresholdDisplayName: 'Plan Threshold', recurring: false },
      ])
      expect(result.current.hasRecurring).toBe(true)
      // 1000 cents -> '10' USD (deserialized)
      expect(result.current.recurringThreshold).toEqual({
        amountCents: '10',
        thresholdDisplayName: 'Plan Recurring',
        recurring: true,
      })
    })
  })

  describe('handleAddThreshold', () => {
    it('adds a new threshold with incremented amount', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: null },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.nonRecurringThresholds).toHaveLength(1)

      await act(async () => {
        result.current.handleAddThreshold()
      })

      expect(result.current.nonRecurringThresholds).toHaveLength(2)
      // 100 cents -> '1' USD (deserialized) + 1 = '2'
      expect(result.current.nonRecurringThresholds[1]).toEqual({
        amountCents: '2',
        thresholdDisplayName: '',
        recurring: false,
      })
    })

    it('handles adding threshold when last amount is not a number', async () => {
      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription: undefined,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      // Default has amountCents: '1'
      await act(async () => {
        result.current.handleAddThreshold()
      })

      expect(result.current.nonRecurringThresholds).toHaveLength(2)
      expect(result.current.nonRecurringThresholds[1].amountCents).toBe('2')
    })
  })

  describe('handleDeleteThreshold', () => {
    it('removes threshold at specified index', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: 'First' },
          { id: '2', amountCents: '200', recurring: false, thresholdDisplayName: 'Second' },
          { id: '3', amountCents: '300', recurring: false, thresholdDisplayName: 'Third' },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.nonRecurringThresholds).toHaveLength(3)

      await act(async () => {
        result.current.handleDeleteThreshold(1)
      })

      expect(result.current.nonRecurringThresholds).toHaveLength(2)
      expect(result.current.nonRecurringThresholds[0].thresholdDisplayName).toBe('First')
      expect(result.current.nonRecurringThresholds[1].thresholdDisplayName).toBe('Third')
    })

    it('resets to default when deleting last threshold', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '500', recurring: false, thresholdDisplayName: 'Only' },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.nonRecurringThresholds).toHaveLength(1)

      await act(async () => {
        result.current.handleDeleteThreshold(0)
      })

      expect(result.current.nonRecurringThresholds).toHaveLength(1)
      expect(result.current.nonRecurringThresholds[0]).toEqual(DEFAULT_PROGRESSIVE_BILLING)
    })
  })

  describe('isDirty', () => {
    it('is false initially', async () => {
      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription: undefined,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.isDirty).toBe(false)
    })

    it('becomes true after modifying form', async () => {
      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription: undefined,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      await act(async () => {
        result.current.handleAddThreshold()
      })

      expect(result.current.isDirty).toBe(true)
    })
  })

  describe('validation', () => {
    it('allows submission when thresholds are in ascending order', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: null },
          { id: '2', amountCents: '200', recurring: false, thresholdDisplayName: null },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      // Form should be submittable with valid ascending order
      expect(result.current.form.state.canSubmit).toBe(true)
    })

    it('skips validation when progressiveBillingDisabled is true', async () => {
      const subscription = createMockSubscription({
        progressiveBillingDisabled: true,
        usageThresholds: [],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      // Even with empty thresholds, form should be submittable when progressive billing is disabled
      expect(result.current.form.state.canSubmit).toBe(true)
    })

    it('initializes form with correct nonRecurringThresholds values', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: 'First' },
          { id: '2', amountCents: '200', recurring: false, thresholdDisplayName: 'Second' },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      // Should correctly initialize the form state (deserialized from cents)
      expect(result.current.nonRecurringThresholds).toHaveLength(2)
      // 100 cents -> '1' USD (deserialized)
      expect(result.current.nonRecurringThresholds[0].amountCents).toBe('1')
      // 200 cents -> '2' USD (deserialized)
      expect(result.current.nonRecurringThresholds[1].amountCents).toBe('2')
    })
  })

  describe('form submission', () => {
    // Note: amountCents from API is in cents (e.g., '100' = 100 cents = $1.00 USD)
    // Form displays deserialized values (e.g., '1' for $1.00)
    // On submit, values are serialized back to cents (e.g., '1' -> 100)

    it('submits with correct data when progressive billing is enabled', async () => {
      const subscription = createMockSubscription({
        progressiveBillingDisabled: false,
        // 100 cents from API
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: 'Test' },
        ],
      })

      const mocks = [
        createUpdateMutationMock({
          id: subscriptionId,
          progressiveBillingDisabled: false,
          // Serialized back to 100 cents (number)
          usageThresholds: [{ amountCents: 100, thresholdDisplayName: 'Test', recurring: false }],
        }),
      ]

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper(mocks) },
      )

      await act(() => Promise.resolve())

      await act(async () => {
        await result.current.form.handleSubmit()
      })

      await waitFor(() => {
        expect(mockOnSuccess).toHaveBeenCalled()
      })
    })

    it('submits with thresholds preserved when progressive billing is disabled', async () => {
      const subscription = createMockSubscription({
        progressiveBillingDisabled: true,
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: 'Test' },
        ],
      })

      const mocks = [
        createUpdateMutationMock({
          id: subscriptionId,
          progressiveBillingDisabled: true,
          usageThresholds: [{ amountCents: 100, thresholdDisplayName: 'Test', recurring: false }],
        }),
      ]

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper(mocks) },
      )

      await act(() => Promise.resolve())

      await act(async () => {
        await result.current.form.handleSubmit()
      })

      await waitFor(() => {
        expect(mockOnSuccess).toHaveBeenCalled()
      })
    })

    it('includes recurring threshold when hasRecurring is true', async () => {
      const subscription = createMockSubscription({
        progressiveBillingDisabled: false,
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: null },
          { id: '2', amountCents: '500', recurring: true, thresholdDisplayName: 'Recurring' },
        ],
      })

      const mocks = [
        createUpdateMutationMock({
          id: subscriptionId,
          progressiveBillingDisabled: false,
          usageThresholds: [
            { amountCents: 100, recurring: false },
            { amountCents: 500, thresholdDisplayName: 'Recurring', recurring: true },
          ],
        }),
      ]

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper(mocks) },
      )

      await act(() => Promise.resolve())

      await act(async () => {
        await result.current.form.handleSubmit()
      })

      await waitFor(() => {
        expect(mockOnSuccess).toHaveBeenCalled()
      })
    })
  })

  describe('form values', () => {
    // Note: Form values are deserialized from cents to display values
    // 100 cents -> '1' USD, 200 cents -> '2' USD, etc.

    it('exposes nonRecurringThresholds from form state', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: 'A' },
          { id: '2', amountCents: '200', recurring: false, thresholdDisplayName: 'B' },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(result.current.nonRecurringThresholds).toHaveLength(2)
      // 100 cents -> '1' USD (deserialized)
      expect(result.current.nonRecurringThresholds[0].amountCents).toBe('1')
      // 200 cents -> '2' USD (deserialized)
      expect(result.current.nonRecurringThresholds[1].amountCents).toBe('2')
    })

    it('exposes hasRecurring from form state', async () => {
      const subscriptionWithRecurring = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '500', recurring: true, thresholdDisplayName: null },
        ],
      })

      const { result: resultWithRecurring } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription: subscriptionWithRecurring,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(resultWithRecurring.current.hasRecurring).toBe(true)

      const subscriptionWithoutRecurring = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '100', recurring: false, thresholdDisplayName: null },
        ],
      })

      const { result: resultWithoutRecurring } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription: subscriptionWithoutRecurring,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      expect(resultWithoutRecurring.current.hasRecurring).toBe(false)
    })

    it('exposes recurringThreshold from form state', async () => {
      const subscription = createMockSubscription({
        usageThresholds: [
          { id: '1', amountCents: '1000', recurring: true, thresholdDisplayName: 'Monthly' },
        ],
      })

      const { result } = renderHook(
        () =>
          useProgressiveBillingTanstackForm({
            subscriptionId,
            subscription,
            currency: CurrencyEnum.Usd,
            onSuccess: mockOnSuccess,
          }),
        { wrapper: createWrapper() },
      )

      await act(() => Promise.resolve())

      // 1000 cents -> '10' USD (deserialized)
      expect(result.current.recurringThreshold.amountCents).toBe('10')
      expect(result.current.recurringThreshold.thresholdDisplayName).toBe('Monthly')
      expect(result.current.recurringThreshold.recurring).toBe(true)
    })
  })
})
