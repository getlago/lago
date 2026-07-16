import { renderHook } from '@testing-library/react'

import { CurrencyEnum, PremiumIntegrationTypeEnum } from '~/generated/graphql'

import { useSubscriptionProgressiveBillingTab } from '../useSubscriptionProgressiveBillingTab'

const mockHasOrganizationPremiumAddon = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
  }),
}))

const createMockSubscription = (overrides?: {
  id?: string
  progressiveBillingDisabled?: boolean
  usageThresholds?: Array<{
    id: string
    recurring: boolean
    amountCents: string
    thresholdDisplayName: string | null
  }>
  plan?: {
    id: string
    amountCurrency: CurrencyEnum
    applicableUsageThresholds: Array<{
      id: string
      recurring: boolean
      amountCents: string
      thresholdDisplayName: string | null
    }>
  }
}) => ({
  id: 'subscription-123',
  progressiveBillingDisabled: false,
  usageThresholds: [
    {
      id: 'threshold-1',
      amountCents: '10000',
      recurring: false,
      thresholdDisplayName: 'Non-recurring 1',
    },
    {
      id: 'threshold-2',
      amountCents: '20000',
      recurring: true,
      thresholdDisplayName: 'Recurring 1',
    },
  ],
  plan: {
    id: 'plan-123',
    amountCurrency: CurrencyEnum.Usd,
    applicableUsageThresholds: [
      {
        id: 'plan-threshold-1',
        amountCents: '5000',
        recurring: false,
        thresholdDisplayName: 'Plan non-recurring',
      },
      {
        id: 'plan-threshold-2',
        amountCents: '15000',
        recurring: true,
        thresholdDisplayName: 'Plan recurring',
      },
    ],
  },
  ...overrides,
})

describe('useSubscriptionProgressiveBillingTab', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasOrganizationPremiumAddon.mockReturnValue(true)
  })

  describe('currency', () => {
    it('returns currency from subscription plan', () => {
      const subscription = createMockSubscription({
        plan: {
          id: 'plan-123',
          amountCurrency: CurrencyEnum.Eur,
          applicableUsageThresholds: [],
        },
      })

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.currency).toBe(CurrencyEnum.Eur)
    })

    it('defaults to USD when no subscription', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTab({ subscription: null }),
      )

      expect(result.current.currency).toBe(CurrencyEnum.Usd)
    })

    it('returns JPY currency when subscription plan uses JPY', () => {
      const subscription = createMockSubscription({
        plan: {
          id: 'plan-123',
          amountCurrency: CurrencyEnum.Jpy,
          applicableUsageThresholds: [],
        },
      })

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.currency).toBe(CurrencyEnum.Jpy)
    })
  })

  describe('hasPremiumIntegration', () => {
    it('returns true when organization has progressive billing addon', () => {
      mockHasOrganizationPremiumAddon.mockReturnValue(true)

      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTab({ subscription: createMockSubscription() }),
      )

      expect(result.current.hasPremiumIntegration).toBe(true)
      expect(mockHasOrganizationPremiumAddon).toHaveBeenCalledWith(
        PremiumIntegrationTypeEnum.ProgressiveBilling,
      )
    })

    it('returns false when organization does not have progressive billing addon', () => {
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTab({ subscription: createMockSubscription() }),
      )

      expect(result.current.hasPremiumIntegration).toBe(false)
    })
  })

  describe('threshold filtering', () => {
    it('returns all subscription thresholds', () => {
      const subscription = createMockSubscription()

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.subscriptionThresholds).toHaveLength(2)
    })

    it('filters non-recurring subscription thresholds', () => {
      const subscription = createMockSubscription()

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.nonRecurringSubscriptionThresholds).toHaveLength(1)
      expect(result.current.nonRecurringSubscriptionThresholds[0].thresholdDisplayName).toBe(
        'Non-recurring 1',
      )
    })

    it('filters recurring subscription thresholds', () => {
      const subscription = createMockSubscription()

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.recurringSubscriptionThresholds).toHaveLength(1)
      expect(result.current.recurringSubscriptionThresholds[0].thresholdDisplayName).toBe(
        'Recurring 1',
      )
    })

    it('filters non-recurring plan thresholds', () => {
      const subscription = createMockSubscription()

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.nonRecurringPlanThresholds).toHaveLength(1)
      expect(result.current.nonRecurringPlanThresholds[0].thresholdDisplayName).toBe(
        'Plan non-recurring',
      )
    })

    it('filters recurring plan thresholds', () => {
      const subscription = createMockSubscription()

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.recurringPlanThresholds).toHaveLength(1)
      expect(result.current.recurringPlanThresholds[0].thresholdDisplayName).toBe('Plan recurring')
    })

    it('returns empty arrays when subscription is null', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTab({ subscription: null }),
      )

      expect(result.current.subscriptionThresholds).toHaveLength(0)
      expect(result.current.nonRecurringSubscriptionThresholds).toHaveLength(0)
      expect(result.current.recurringSubscriptionThresholds).toHaveLength(0)
      expect(result.current.nonRecurringPlanThresholds).toHaveLength(0)
      expect(result.current.recurringPlanThresholds).toHaveLength(0)
    })

    it('returns empty arrays when subscription has no thresholds', () => {
      const subscription = createMockSubscription({
        usageThresholds: [],
        plan: {
          id: 'plan-123',
          amountCurrency: CurrencyEnum.Usd,
          applicableUsageThresholds: [],
        },
      })

      const { result } = renderHook(() => useSubscriptionProgressiveBillingTab({ subscription }))

      expect(result.current.subscriptionThresholds).toHaveLength(0)
      expect(result.current.nonRecurringSubscriptionThresholds).toHaveLength(0)
      expect(result.current.recurringSubscriptionThresholds).toHaveLength(0)
      expect(result.current.nonRecurringPlanThresholds).toHaveLength(0)
      expect(result.current.recurringPlanThresholds).toHaveLength(0)
    })
  })
})
