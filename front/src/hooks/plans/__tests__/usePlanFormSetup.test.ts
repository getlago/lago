import { renderHook } from '@testing-library/react'

import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { CurrencyEnum } from '~/generated/graphql'

import { usePlanFormSetup } from '../usePlanFormSetup'

// --- Mocks ---

const mockReset = jest.fn()
const mockSetFieldValue = jest.fn()

const mockForm = {
  reset: mockReset,
  setFieldValue: mockSetFieldValue,
  store: {
    subscribe: jest.fn(() => jest.fn()),
    getState: () => ({ values: { charges: [], billChargesMonthly: false, interval: 'monthly' } }),
  },
}

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: (config: Record<string, unknown>) => {
    // Capture defaultValues for assertions
    capturedDefaultValues = config.defaultValues as Record<string, unknown>
    capturedOnSubmit = config.onSubmit as (() => void) | undefined

    return mockForm
  },
}))

let capturedDefaultValues: Record<string, unknown> | undefined
let capturedOnSubmit: (() => void) | undefined

const mockBuildDefaultValues = jest.fn().mockReturnValue({ name: 'default-plan' })

jest.mock('../usePlanForm', () => ({
  buildDefaultValues: (...args: unknown[]) => mockBuildDefaultValues(...args),
}))

const mockFromPlanBillingItems = jest.fn()

jest.mock('~/core/serializers/serializeQuotePlanBillingItems', () => ({
  fromPlanBillingItems: (...args: unknown[]) => mockFromPlanBillingItems(...args),
}))

const mockUseGetSinglePlanQuery = jest.fn()
const mockUseGetSubscriptionForQuotePricingQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetSinglePlanQuery: (...args: unknown[]) => mockUseGetSinglePlanQuery(...args),
  useGetSubscriptionForQuotePricingQuery: (...args: unknown[]) =>
    mockUseGetSubscriptionForQuotePricingQuery(...args),
  LagoApiError: { NotFound: 'not_found' },
  CurrencyEnum: { Usd: 'USD', Eur: 'EUR' },
}))

jest.mock('~/formValidation/planFormSchema', () => ({
  planFormSchema: jest.fn(),
}))

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
  useStore: (_store: unknown, selector: (state: Record<string, unknown>) => unknown) =>
    selector({ values: { charges: [], billChargesMonthly: false, interval: 'monthly' } }),
}))

jest.mock('~/components/plans/utils', () => ({
  isPlanIntervalAnnual: jest.fn(() => false),
}))

// --- Helpers ---

const mockPlan = {
  id: 'plan-123',
  amountCurrency: 'USD',
  parent: null,
}

const mockSubscription = {
  id: 'sub-1',
  name: 'My Subscription',
  externalId: 'ext-sub-1',
  subscriptionAt: '2026-01-01',
  endingAt: '2026-12-31',
  billingTime: 'anniversary',
  plan: {
    id: 'child-plan-1',
    parent: { id: 'parent-plan-1' },
  },
}

// --- Tests ---

describe('usePlanFormSetup', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedDefaultValues = undefined
    capturedOnSubmit = undefined

    mockUseGetSinglePlanQuery.mockReturnValue({ data: undefined, loading: false, error: undefined })
    mockUseGetSubscriptionForQuotePricingQuery.mockReturnValue({ data: undefined })
  })

  describe('GIVEN no initialization source is provided', () => {
    describe('WHEN the hook is rendered', () => {
      it('THEN should return the form and loading as false', () => {
        const { result } = renderHook(() => usePlanFormSetup({}))

        expect(result.current.form).toBe(mockForm)
        expect(result.current.loading).toBe(false)
        expect(result.current.formReady).toBe(false)
      })

      it('THEN should skip both GraphQL queries', () => {
        renderHook(() => usePlanFormSetup({}))

        expect(mockUseGetSinglePlanQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
        expect(mockUseGetSubscriptionForQuotePricingQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
      })
    })
  })

  describe('GIVEN a planIdToFetch (case 4)', () => {
    describe('WHEN the plan query returns data', () => {
      it('THEN should use the fetched plan and mark formReady', () => {
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: { plan: mockPlan },
          loading: false,
          error: undefined,
        })

        const { result } = renderHook(() => usePlanFormSetup({ planIdToFetch: 'plan-123' }))

        expect(result.current.plan).toEqual(mockPlan)
        expect(result.current.formReady).toBe(true)
        expect(result.current.resolvedPlanId).toBe('plan-123')
      })

      it('THEN should call buildDefaultValues with the plan', () => {
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: { plan: mockPlan },
          loading: false,
          error: undefined,
        })

        renderHook(() =>
          usePlanFormSetup({
            planIdToFetch: 'plan-123',
            initialCurrency: CurrencyEnum.Eur,
            formType: FORM_TYPE_ENUM.edition,
          }),
        )

        expect(mockBuildDefaultValues).toHaveBeenCalledWith(
          mockPlan,
          FORM_TYPE_ENUM.edition,
          CurrencyEnum.Eur,
          false,
        )
      })
    })

    describe('WHEN the plan query is loading', () => {
      it('THEN should return loading as true', () => {
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: undefined,
          loading: true,
          error: undefined,
        })

        const { result } = renderHook(() => usePlanFormSetup({ planIdToFetch: 'plan-123' }))

        expect(result.current.loading).toBe(true)
      })
    })
  })

  describe('GIVEN a billingItemPlan (case 2)', () => {
    const billingItemPlan = {
      id: 'plan-from-billing',
      payload: { name: 'Test Plan', code: 'test' },
      overrides: {},
    }

    describe('WHEN deserialized billing data has form values', () => {
      it('THEN should use formValues from billing items and skip plan query', () => {
        const mockDeserialized = {
          formValues: { name: 'Deserialized Plan' },
          subscriptionSettings: { externalId: 'ext-1' },
          invoicingSettings: { paymentMethodId: 'pm-1' },
        }

        mockFromPlanBillingItems.mockReturnValue(mockDeserialized)

        const { result } = renderHook(() =>
          usePlanFormSetup({ billingItemPlan: billingItemPlan as never }),
        )

        expect(mockFromPlanBillingItems).toHaveBeenCalledWith([billingItemPlan])
        expect(result.current.formReady).toBe(true)
        expect(result.current.subscriptionSettings).toEqual(mockDeserialized.subscriptionSettings)
        expect(result.current.invoicingSettings).toEqual(mockDeserialized.invoicingSettings)
        expect(capturedDefaultValues).toEqual(mockDeserialized.formValues)
      })

      it('THEN should skip the plan query', () => {
        mockFromPlanBillingItems.mockReturnValue({
          formValues: { name: 'Plan' },
          subscriptionSettings: {},
          invoicingSettings: {},
        })

        renderHook(() => usePlanFormSetup({ billingItemPlan: billingItemPlan as never }))

        expect(mockUseGetSinglePlanQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
      })
    })
  })

  describe('GIVEN a subscriptionId (case 3)', () => {
    describe('WHEN the subscription query returns data with a parent plan', () => {
      it('THEN should resolve to the parent plan ID', () => {
        mockUseGetSubscriptionForQuotePricingQuery.mockReturnValue({
          data: { subscription: mockSubscription },
        })
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        const { result } = renderHook(() => usePlanFormSetup({ subscriptionId: 'sub-1' }))

        expect(result.current.resolvedPlanId).toBe('parent-plan-1')
      })

      it('THEN should extract subscription settings from the query', () => {
        mockUseGetSubscriptionForQuotePricingQuery.mockReturnValue({
          data: { subscription: mockSubscription },
        })
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        const { result } = renderHook(() => usePlanFormSetup({ subscriptionId: 'sub-1' }))

        expect(result.current.subscriptionSettings).toEqual({
          externalId: 'ext-sub-1',
          subscriptionName: 'My Subscription',
          billingTime: 'anniversary',
          startDate: '2026-01-01',
          endDate: '2026-12-31',
        })
      })

      it('THEN should skip the plan query since subscriptionPlan is available', () => {
        mockUseGetSubscriptionForQuotePricingQuery.mockReturnValue({
          data: { subscription: mockSubscription },
        })
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        renderHook(() => usePlanFormSetup({ subscriptionId: 'sub-1' }))

        expect(mockUseGetSinglePlanQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
      })
    })

    describe('WHEN the subscription has no parent plan (no overrides)', () => {
      it('THEN should use the plan own ID as resolvedPlanId', () => {
        const subscriptionWithoutParent = {
          ...mockSubscription,
          plan: { id: 'direct-plan', parent: null },
        }

        mockUseGetSubscriptionForQuotePricingQuery.mockReturnValue({
          data: { subscription: subscriptionWithoutParent },
        })
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        const { result } = renderHook(() => usePlanFormSetup({ subscriptionId: 'sub-1' }))

        expect(result.current.resolvedPlanId).toBe('direct-plan')
      })
    })

    describe('WHEN the subscription query has not loaded yet', () => {
      it('THEN should return loading as true', () => {
        mockUseGetSubscriptionForQuotePricingQuery.mockReturnValue({ data: undefined })
        mockUseGetSinglePlanQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        const { result } = renderHook(() => usePlanFormSetup({ subscriptionId: 'sub-1' }))

        expect(result.current.loading).toBe(true)
      })
    })
  })

  describe('GIVEN billingItemPlan takes priority over subscriptionId', () => {
    describe('WHEN both billingItemPlan and subscriptionId are provided', () => {
      it('THEN should skip the subscription query', () => {
        const billingItemPlan = {
          id: 'plan-billing',
          payload: {},
          overrides: {},
        }

        mockFromPlanBillingItems.mockReturnValue({
          formValues: { name: 'From Billing' },
          subscriptionSettings: {},
          invoicingSettings: {},
        })

        renderHook(() =>
          usePlanFormSetup({
            billingItemPlan: billingItemPlan as never,
            subscriptionId: 'sub-1',
          }),
        )

        expect(mockUseGetSubscriptionForQuotePricingQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
      })
    })
  })

  describe('GIVEN an onSubmit callback', () => {
    describe('WHEN the hook initializes', () => {
      it('THEN should pass onSubmit to useAppForm', () => {
        const mockOnSubmit = jest.fn()

        renderHook(() => usePlanFormSetup({ onSubmit: mockOnSubmit }))

        expect(capturedOnSubmit).toBeDefined()
      })
    })
  })

  describe('GIVEN default currency resolution', () => {
    describe('WHEN initialCurrency is provided', () => {
      it('THEN should use initialCurrency', () => {
        renderHook(() => usePlanFormSetup({ initialCurrency: CurrencyEnum.Eur }))

        expect(mockBuildDefaultValues).toHaveBeenCalledWith(
          undefined,
          FORM_TYPE_ENUM.creation,
          CurrencyEnum.Eur,
          false,
        )
      })
    })

    describe('WHEN no initialCurrency and no plan data', () => {
      it('THEN should default to USD', () => {
        renderHook(() => usePlanFormSetup({}))

        expect(mockBuildDefaultValues).toHaveBeenCalledWith(
          undefined,
          FORM_TYPE_ENUM.creation,
          CurrencyEnum.Usd,
          false,
        )
      })
    })
  })

  describe('GIVEN the hook returns error from plan query', () => {
    describe('WHEN the plan query errors', () => {
      it('THEN should expose the error', () => {
        const queryError = new Error('Plan not found')

        mockUseGetSinglePlanQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: queryError,
        })

        const { result } = renderHook(() => usePlanFormSetup({ planIdToFetch: 'bad-id' }))

        expect(result.current.error).toBe(queryError)
      })
    })
  })
})
