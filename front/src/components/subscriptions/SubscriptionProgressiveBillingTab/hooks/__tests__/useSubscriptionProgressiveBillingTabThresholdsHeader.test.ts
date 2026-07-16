import { act, renderHook } from '@testing-library/react'

import { useSubscriptionProgressiveBillingTabThresholdsHeader } from '../useSubscriptionProgressiveBillingTabThresholdsHeader'

// Get mocked useParams from test-utils mock
const { useParams } = jest.requireMock('react-router-dom')

const mockNavigate = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  useParams: jest.fn(() => ({})),
  generatePath: jest.fn((path: string, params: Record<string, string>) => {
    let result = path

    Object.entries(params).forEach(([key, value]) => {
      result = result.replace(`:${key}`, value)
    })

    return result
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockHasPermissions = jest.fn()

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

const mockSwitchMutation = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useSwitchProgressiveBillingDisabledValueMutation: () => [mockSwitchMutation, { loading: false }],
}))

const createMockSubscription = (overrides?: {
  id?: string
  progressiveBillingDisabled?: boolean
  usageThresholds?: Array<{ id: string }>
  plan?: {
    id: string
    applicableUsageThresholds: Array<{ id: string }>
  }
}) => ({
  id: 'subscription-123',
  progressiveBillingDisabled: false,
  usageThresholds: [{ id: 'threshold-1' }],
  plan: {
    id: 'plan-123',
    applicableUsageThresholds: [{ id: 'plan-threshold-1' }],
  },
  ...overrides,
})

describe('useSubscriptionProgressiveBillingTabThresholdsHeader', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
    useParams.mockReturnValue({})
  })

  describe('canEditSubscription', () => {
    it('returns true when user has subscriptionsUpdate permission', () => {
      mockHasPermissions.mockReturnValue(true)

      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      expect(result.current.canEditSubscription).toBe(true)
      expect(mockHasPermissions).toHaveBeenCalledWith(['subscriptionsUpdate'])
    })

    it('returns false when user lacks subscriptionsUpdate permission', () => {
      mockHasPermissions.mockReturnValue(false)

      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      expect(result.current.canEditSubscription).toBe(false)
    })
  })

  describe('hasSubscriptionThresholds', () => {
    it('returns true when subscription has thresholds', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      expect(result.current.hasSubscriptionThresholds).toBe(true)
    })

    it('returns false when subscription has no thresholds', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription({ usageThresholds: [] }),
        }),
      )

      expect(result.current.hasSubscriptionThresholds).toBe(false)
    })

    it('returns false when subscription is null', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({ subscription: null }),
      )

      expect(result.current.hasSubscriptionThresholds).toBe(false)
    })
  })

  describe('shouldDisplayOverriddenBadge', () => {
    it('returns true when subscription has thresholds', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      expect(result.current.shouldDisplayOverriddenBadge).toBe(true)
    })

    it('returns true when progressive billing is disabled and plan has thresholds', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription({
            progressiveBillingDisabled: true,
            usageThresholds: [],
          }),
        }),
      )

      expect(result.current.shouldDisplayOverriddenBadge).toBe(true)
    })

    it('returns false when no subscription thresholds and progressive billing is enabled', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription({
            progressiveBillingDisabled: false,
            usageThresholds: [],
          }),
        }),
      )

      expect(result.current.shouldDisplayOverriddenBadge).toBe(false)
    })

    it('returns false when progressive billing disabled but plan has no thresholds', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription({
            progressiveBillingDisabled: true,
            usageThresholds: [],
            plan: { id: 'plan-123', applicableUsageThresholds: [] },
          }),
        }),
      )

      expect(result.current.shouldDisplayOverriddenBadge).toBe(false)
    })
  })

  describe('tooltipTitle', () => {
    it('returns tooltip with subscription thresholds context when thresholds exist', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      expect(result.current.tooltipTitle).toBe('text_1769642763701xwuflld9biu')
    })

    it('returns tooltip with plan context when no subscription thresholds', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription({ usageThresholds: [] }),
        }),
      )

      expect(result.current.tooltipTitle).toBe('text_17696427637012io81h0jc2w')
    })
  })

  describe('navigateToEditForm', () => {
    it('navigates to customer subscription edit route when customerId is present', () => {
      useParams.mockReturnValue({ customerId: 'customer-123' })

      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      act(() => {
        result.current.navigateToEditForm()
      })

      expect(mockNavigate).toHaveBeenCalledWith(expect.stringContaining('customer-123'))
    })

    it('navigates to plan subscription edit route when planId is present', () => {
      useParams.mockReturnValue({ planId: 'plan-456' })

      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      act(() => {
        result.current.navigateToEditForm()
      })

      expect(mockNavigate).toHaveBeenCalledWith(expect.stringContaining('plan-456'))
    })
  })

  describe('toggleProgressiveBilling', () => {
    it('calls mutation with toggled progressiveBillingDisabled value', async () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription({ progressiveBillingDisabled: false }),
        }),
      )

      await act(async () => {
        await result.current.toggleProgressiveBilling()
      })

      expect(mockSwitchMutation).toHaveBeenCalledWith({
        variables: {
          input: {
            id: 'subscription-123',
            progressiveBillingDisabled: true,
          },
        },
      })
    })

    it('does not call mutation when subscription is null', async () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({ subscription: null }),
      )

      await act(async () => {
        await result.current.toggleProgressiveBilling()
      })

      expect(mockSwitchMutation).not.toHaveBeenCalled()
    })
  })

  describe('resetDialogRef', () => {
    it('returns a ref object', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      expect(result.current.resetDialogRef).toHaveProperty('current')
    })
  })

  describe('translate', () => {
    it('returns translate function', () => {
      const { result } = renderHook(() =>
        useSubscriptionProgressiveBillingTabThresholdsHeader({
          subscription: createMockSubscription(),
        }),
      )

      expect(typeof result.current.translate).toBe('function')
    })
  })
})
