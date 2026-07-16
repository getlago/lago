import { act, renderHook } from '@testing-library/react'

import type { BillingItemsPayload } from '~/core/serializers/serializeQuoteBillingItems'
import type { SubscriptionPricingState } from '~/core/serializers/serializeQuotePlanBillingItems'
import { render } from '~/test-utils'

import { useSubscriptionPricingDrawer } from '../useSubscriptionPricingDrawer'

const mockDrawerOpen = jest.fn()
const mockDrawerClose = jest.fn()

// State the mocked content component hydrates into the hook's stateRef on render.
// `null` keeps the ref empty (exercises the early-return branch in handleSave).
let mockInjectedState: SubscriptionPricingState | null = null

jest.mock('~/components/drawers/useDrawer', () => ({
  useFormDrawer: () => ({ open: mockDrawerOpen, close: mockDrawerClose }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

// Mock SubscriptionPricingContent — on render it hydrates the shared stateRef
// so the drawer's submit handler has a subscription state to serialize.
jest.mock(
  '~/components/designSystem/RichTextEditor/PricingBlock/SubscriptionPricingContent',
  () => ({
    SubscriptionPricingContent: ({
      stateRef,
    }: {
      stateRef?: { current: SubscriptionPricingState | null }
    }) => {
      if (stateRef) {
        stateRef.current = mockInjectedState
      }

      return null
    },
  }),
)

describe('useSubscriptionPricingDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockInjectedState = null
  })

  it('returns the expected interface', () => {
    const { result } = renderHook(() => useSubscriptionPricingDrawer(undefined))

    expect(result.current).toHaveProperty('onPricingCommand')
    expect(result.current).toHaveProperty('isPricingDisabled')
    expect(result.current).toHaveProperty('entities')
    expect(result.current).toHaveProperty('syncEntitiesWithBlocks')
  })

  it('opens the drawer when onPricingCommand is called', () => {
    const { result } = renderHook(() => useSubscriptionPricingDrawer(undefined))

    const mockOnSave = jest.fn()

    act(() => {
      result.current.onPricingCommand({ onSave: mockOnSave })
    })

    expect(mockDrawerOpen).toHaveBeenCalledTimes(1)
  })

  it('isPricingDisabled returns false when no entities', () => {
    const { result } = renderHook(() => useSubscriptionPricingDrawer(undefined))

    expect(result.current.isPricingDisabled()).toBe(false)
  })

  it('hydrates entities from initial billingItems with plans', () => {
    const initialBillingItems: BillingItemsPayload = {
      addons: [],
      plans: [
        {
          type: 'plan',
          id: 'plan_123',
          payload: {
            position: 1,
            code: 'enterprise',
            name: 'Enterprise Plan',
            description: '',
            subscription_external_id: null,
            subscription_name: null,
            billing_time: 'anniversary',
            start_date: '2023-07-26',
            end_date: null,
            payment_method_id: null,
            invoice_custom_footer: null,
          },
          overrides: {},
        },
      ],
    }

    const { result } = renderHook(() => useSubscriptionPricingDrawer(initialBillingItems))

    expect(result.current.entities).toHaveProperty('plan_123')
    expect(result.current.entities.plan_123.entityType).toBe('plan')
    expect(result.current.entities.plan_123.name).toBe('Enterprise Plan')
  })

  it('syncEntitiesWithBlocks removes orphaned entities', () => {
    const initialBillingItems: BillingItemsPayload = {
      addons: [],
      plans: [
        {
          type: 'plan',
          id: 'plan_123',
          payload: {
            position: 1,
            code: 'enterprise',
            name: 'Enterprise Plan',
            description: '',
            subscription_external_id: null,
            subscription_name: null,
            billing_time: 'anniversary',
            start_date: '2023-07-26',
            end_date: null,
            payment_method_id: null,
            invoice_custom_footer: null,
          },
          overrides: {},
        },
      ],
    }

    const { result } = renderHook(() => useSubscriptionPricingDrawer(initialBillingItems))

    // Block with different entity — plan_123 becomes orphaned
    let billingItems: BillingItemsPayload | null = null

    act(() => {
      billingItems = result.current.syncEntitiesWithBlocks([
        { pricingType: 'plan', entityIds: ['plan_other'] },
      ])
    })

    expect(billingItems).not.toBeNull()
    expect(result.current.entities).not.toHaveProperty('plan_123')
  })

  it('saves the subscription and closes the drawer when the form is submitted', () => {
    mockInjectedState = {
      planId: 'plan_123',
      planCode: 'enterprise',
      planName: 'Enterprise Plan',
      planDescription: '',
      subscriptionSettings: {
        externalId: '',
        subscriptionName: '',
        billingTime: 'anniversary',
        startDate: '2023-07-26',
        endDate: '2024-07-26',
      },
      invoicingSettings: { paymentMethodId: '', invoiceCustomFooter: '' },
      overrides: {},
    }

    const onSave = jest.fn()
    const onDatesChange = jest.fn()

    const { result } = renderHook(() => useSubscriptionPricingDrawer(undefined, { onDatesChange }))

    act(() => {
      result.current.onPricingCommand({ onSave })
    })

    const openArgs = mockDrawerOpen.mock.calls[0][0]

    // Render the drawer children so the mocked content hydrates the state ref
    render(openArgs.children)

    act(() => {
      openArgs.form.submit()
    })

    expect(onSave).toHaveBeenCalledWith(
      { pricingType: 'plan', entityIds: ['plan_123'] },
      expect.objectContaining({
        plan_123: expect.objectContaining({ entityId: 'plan_123', entityType: 'plan' }),
      }),
      // The drawer owns only the `plans` key; `addons` is normalized in by the
      // save funnel (savePricingBlock), not by this drawer.
      expect.objectContaining({ plans: expect.any(Array) }),
    )
    expect(onDatesChange).toHaveBeenCalledWith('2023-07-26', '2024-07-26')
    expect(result.current.entities).toHaveProperty('plan_123')
    expect(mockDrawerClose).toHaveBeenCalledTimes(1)
  })

  it('preserves existing coupons in the payload when saving a plan', () => {
    // Regression: coupons live alongside plans in billingItems. Saving a plan
    // must not overwrite billingItems and drop a previously-added coupon.
    mockInjectedState = {
      planId: 'plan_123',
      planCode: 'enterprise',
      planName: 'Enterprise Plan',
      planDescription: '',
      subscriptionSettings: {
        externalId: '',
        subscriptionName: '',
        billingTime: 'anniversary',
        startDate: '2023-07-26',
        endDate: '',
      },
      invoicingSettings: { paymentMethodId: '', invoiceCustomFooter: '' },
      overrides: {},
    }

    const existingCoupon = {
      type: 'coupon',
      id: 'cpn_1',
      localId: 'local-cpn-1',
      payload: {},
      overrides: {},
    } as unknown as NonNullable<BillingItemsPayload['coupons']>[number]

    const initialBillingItems: BillingItemsPayload = {
      addons: [],
      coupons: [existingCoupon],
    }

    const onSave = jest.fn()

    const { result } = renderHook(() => useSubscriptionPricingDrawer(initialBillingItems))

    act(() => {
      result.current.onPricingCommand({ onSave })
    })

    const openArgs = mockDrawerOpen.mock.calls[0][0]

    render(openArgs.children)

    act(() => {
      openArgs.form.submit()
    })

    expect(onSave).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      expect.objectContaining({ plans: expect.any(Array), coupons: [existingCoupon] }),
    )
  })

  it('syncEntitiesWithBlocks preserves existing coupons when pruning an orphaned plan', () => {
    const existingCoupon = {
      type: 'coupon',
      id: 'cpn_1',
      localId: 'local-cpn-1',
      payload: {},
      overrides: {},
    } as unknown as NonNullable<BillingItemsPayload['coupons']>[number]

    const initialBillingItems: BillingItemsPayload = {
      addons: [],
      plans: [
        {
          type: 'plan',
          id: 'plan_123',
          payload: {
            position: 1,
            code: 'enterprise',
            name: 'Enterprise Plan',
            description: '',
            subscription_external_id: null,
            subscription_name: null,
            billing_time: 'anniversary',
            start_date: '2023-07-26',
            end_date: null,
            payment_method_id: null,
            invoice_custom_footer: null,
          },
          overrides: {},
        },
      ],
      coupons: [existingCoupon],
    }

    const { result } = renderHook(() => useSubscriptionPricingDrawer(initialBillingItems))

    let billingItems: BillingItemsPayload | null = null

    act(() => {
      billingItems = result.current.syncEntitiesWithBlocks([
        { pricingType: 'plan', entityIds: ['plan_other'] },
      ])
    })

    expect(billingItems).toEqual(expect.objectContaining({ plans: [], coupons: [existingCoupon] }))
  })

  it('does not save or close the drawer when no subscription state is set', () => {
    mockInjectedState = null

    const onSave = jest.fn()

    const { result } = renderHook(() => useSubscriptionPricingDrawer(undefined))

    act(() => {
      result.current.onPricingCommand({ onSave })
    })

    const openArgs = mockDrawerOpen.mock.calls[0][0]

    render(openArgs.children)

    act(() => {
      openArgs.form.submit()
    })

    expect(onSave).not.toHaveBeenCalled()
    expect(mockDrawerClose).not.toHaveBeenCalled()
  })
})
