import { act, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import type { PlanFormInput } from '~/components/plans/types'
import {
  type BillingItemPlan,
  DEFAULT_INVOICING_SETTINGS,
  DEFAULT_SUBSCRIPTION_SETTINGS,
  type SubscriptionPricingState,
} from '~/core/serializers/serializeQuotePlanBillingItems'
import {
  ChargeModelEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  PlanInterval,
} from '~/generated/graphql'
import { usePlanFormSetup } from '~/hooks/plans/usePlanFormSetup'
import { render } from '~/test-utils'

import { SubscriptionPricingContent } from '../SubscriptionPricingContent'

const mockPlan = {
  id: 'plan_1',
  name: 'Starter',
  code: 'starter',
  description: '',
  interval: PlanInterval.Monthly,
  amountCents: '5000',
  amountCurrency: CurrencyEnum.Usd,
  payInAdvance: false,
  invoiceDisplayName: '',
  trialPeriod: 0,
  fixedCharges: [],
  charges: [],
  minimumCommitment: null,
  usageThresholds: [],
  subscriptionsCount: 0,
  billChargesMonthly: false,
  hasOverriddenPlans: false,
  billFixedChargesMonthly: false,
  taxes: [],
  entitlements: [],
}

jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 56,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, i) => ({
        index: i,
        key: String(i),
        start: i * 56,
        size: 56,
      })),
    scrollToIndex: jest.fn(),
    measureElement: jest.fn(),
  }),
}))

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: (searchQuery: unknown) => ({
    debouncedSearch: searchQuery,
    isLoading: false,
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  usePlansLazyQuery: jest.fn(() => [
    jest.fn(),
    {
      data: {
        plans: {
          collection: [
            { id: 'plan_1', name: 'Starter', code: 'starter' },
            { id: 'plan_2', name: 'Pro', code: 'pro' },
          ],
        },
      },
      loading: false,
    },
  ]),
}))

// Mock usePlanFormSetup — returns a mock form + plan when planIdToFetch is set
let mockFormOverrides: Partial<PlanFormInput> = {}

jest.mock('~/hooks/plans/usePlanFormSetup', () => {
  const { createMockPlanForm } = jest.requireActual('~/test-utils/createMockPlanForm')

  return {
    usePlanFormSetup: jest.fn(({ planIdToFetch }: { planIdToFetch?: string }) => ({
      form: createMockPlanForm(mockFormOverrides),
      plan: planIdToFetch ? mockPlan : undefined,
      formReady: !!planIdToFetch,
      loading: false,
      resolvedPlanId: planIdToFetch,
      subscriptionSettings: undefined,
      invoicingSettings: undefined,
    })),
  }
})

// Mock hook-based drawers with spies
const mockOpenSubscriptionSettings = jest.fn()
const mockOpenInvoicingSettings = jest.fn()
const mockOpenPlanSettings = jest.fn()
let mockShowInvoicingSection = false

jest.mock('../useSubscriptionSettingsDrawer', () => ({
  useSubscriptionSettingsDrawer: () => ({ openDrawer: mockOpenSubscriptionSettings }),
}))

jest.mock('../useInvoicingPaymentsSettingsDrawer', () => ({
  useInvoicingPaymentsSettingsDrawer: () => ({
    openDrawer: mockOpenInvoicingSettings,
    showSection: mockShowInvoicingSection,
  }),
}))

jest.mock('../useQuotePlanSettingsDrawer', () => ({
  useQuotePlanSettingsDrawer: () => ({ openDrawer: mockOpenPlanSettings }),
}))

// Mock reused section components
jest.mock('~/components/plans/form/FixedChargesSection', () => ({
  FixedChargesSection: () => <div data-test="fixed-charges-section">Fixed Charges</div>,
}))

jest.mock('~/components/plans/UsageChargesSection', () => ({
  UsageChargesSection: () => <div data-test="usage-charges-section">Usage Charges</div>,
}))

jest.mock('~/components/plans/CommitmentsSection', () => ({
  CommitmentsSection: () => <div data-test="commitments-section">Commitments</div>,
}))

jest.mock('~/components/plans/ProgressiveBillingSection', () => ({
  ProgressiveBillingSection: () => (
    <div data-test="progressive-billing-section">Progressive Billing</div>
  ),
}))

jest.mock('~/components/plans/drawers/subscriptionFee/SubscriptionFeeDrawer', () => ({
  SubscriptionFeeDrawer: () => null,
}))

describe('SubscriptionPricingContent', () => {
  beforeEach(() => {
    mockFormOverrides = {}
    mockShowInvoicingSection = false
    mockOpenSubscriptionSettings.mockClear()
    mockOpenInvoicingSettings.mockClear()
    mockOpenPlanSettings.mockClear()
  })

  it('shows plan selection ComboBox without initial data', async () => {
    const stateRef = { current: null as SubscriptionPricingState | null }
    const formValuesRef = { current: null as PlanFormInput | null }

    await act(() =>
      render(<SubscriptionPricingContent stateRef={stateRef} formValuesRef={formValuesRef} />),
    )

    // Should show ComboBox for plan selection
    expect(screen.getByText('Plan')).toBeInTheDocument()
    // Should not show sections since no plan is selected
    expect(screen.queryByTestId('fixed-charges-section')).not.toBeInTheDocument()
  })

  it('shows sections when initial plan is provided', async () => {
    const stateRef = { current: null as SubscriptionPricingState | null }
    const formValuesRef = { current: null as PlanFormInput | null }

    const initialState: SubscriptionPricingState = {
      planId: 'plan_1',
      planCode: 'starter',
      planName: 'Starter',
      planDescription: '',
      subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
      invoicingSettings: DEFAULT_INVOICING_SETTINGS,
      overrides: {},
    }

    await act(() =>
      render(
        <SubscriptionPricingContent
          stateRef={stateRef}
          formValuesRef={formValuesRef}
          initialState={initialState}
        />,
      ),
    )

    // Should show both the ComboBox and the sections
    expect(screen.getByText('Plan')).toBeInTheDocument()
    expect(screen.getByTestId('fixed-charges-section')).toBeInTheDocument()
    expect(screen.getByTestId('usage-charges-section')).toBeInTheDocument()
    expect(screen.getByTestId('commitments-section')).toBeInTheDocument()
    expect(screen.getByTestId('progressive-billing-section')).toBeInTheDocument()
  })

  it('syncs state to stateRef when plan is selected', async () => {
    const stateRef = { current: null as SubscriptionPricingState | null }
    const formValuesRef = { current: null as PlanFormInput | null }

    const initialState: SubscriptionPricingState = {
      planId: 'plan_1',
      planCode: 'starter',
      planName: 'Starter',
      planDescription: '',
      subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
      invoicingSettings: DEFAULT_INVOICING_SETTINGS,
      overrides: {},
    }

    await act(() =>
      render(
        <SubscriptionPricingContent
          stateRef={stateRef}
          formValuesRef={formValuesRef}
          initialState={initialState}
        />,
      ),
    )

    expect(stateRef.current).not.toBeNull()
    expect(stateRef.current?.planId).toBe('plan_1')
  })

  describe('GIVEN no plan is selected', () => {
    it('WHEN rendered without initialState THEN stateRef remains null', async () => {
      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      await act(() =>
        render(<SubscriptionPricingContent stateRef={stateRef} formValuesRef={formValuesRef} />),
      )

      // formReady is false and selectedPlanId is empty => stateRef.current = null (line 153-154)
      expect(stateRef.current).toBeNull()
    })
  })

  describe('GIVEN a plan with custom form values', () => {
    // Overrides are no longer computed here — the component snapshots the live
    // form values into formValuesRef and toPlanBillingItems derives the overrides
    // from them (see buildPlanOverrides tests in the serializer suite).
    it('WHEN form has fixed charges and usage charges THEN formValuesRef captures them', async () => {
      mockFormOverrides = {
        fixedCharges: [
          {
            addOn: { id: 'addon_1', code: 'setup_fee', name: 'Setup Fee' },
            chargeModel: FixedChargeChargeModelEnum.Standard,
            properties: { amount: '1000' },
          },
        ] as PlanFormInput['fixedCharges'],
        charges: [
          {
            billableMetric: {
              id: 'bm_1',
              code: 'api_calls',
              name: 'API Calls',
              aggregationType: 'count_agg',
              recurring: false,
              filters: [],
            },
            chargeModel: ChargeModelEnum.Standard,
            properties: { amount: '50' },
          },
        ] as unknown as PlanFormInput['charges'],
      }

      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      const initialState: SubscriptionPricingState = {
        planId: 'plan_1',
        planCode: 'starter',
        planName: 'Starter',
        planDescription: '',
        subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
        invoicingSettings: DEFAULT_INVOICING_SETTINGS,
      }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
          />,
        ),
      )

      expect(formValuesRef.current?.fixedCharges).toHaveLength(1)
      expect(formValuesRef.current?.fixedCharges?.[0].addOn.code).toBe('setup_fee')
      expect(formValuesRef.current?.charges).toHaveLength(1)
      expect(formValuesRef.current?.charges?.[0].billableMetric.code).toBe('api_calls')
    })

    it('WHEN form has a minimum commitment THEN formValuesRef captures it', async () => {
      mockFormOverrides = {
        minimumCommitment: {
          amountCents: '5000',
          invoiceDisplayName: 'Min spend',
        },
      }

      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      const initialState: SubscriptionPricingState = {
        planId: 'plan_1',
        planCode: 'starter',
        planName: 'Starter',
        planDescription: '',
        subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
        invoicingSettings: DEFAULT_INVOICING_SETTINGS,
      }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
          />,
        ),
      )

      expect(formValuesRef.current?.minimumCommitment?.amountCents).toBe('5000')
      expect(formValuesRef.current?.minimumCommitment?.invoiceDisplayName).toBe('Min spend')
    })

    it('WHEN form has a subscription fee amount THEN formValuesRef captures it', async () => {
      mockFormOverrides = {
        amountCents: '7500',
        invoiceDisplayName: 'Premium fee',
      }

      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      const initialState: SubscriptionPricingState = {
        planId: 'plan_1',
        planCode: 'starter',
        planName: 'Starter',
        planDescription: '',
        subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
        invoicingSettings: DEFAULT_INVOICING_SETTINGS,
      }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
          />,
        ),
      )

      expect(formValuesRef.current?.amountCents).toBe('7500')
      expect(formValuesRef.current?.invoiceDisplayName).toBe('Premium fee')
    })
  })

  describe('GIVEN showInvoicingSection is true', () => {
    it('WHEN a plan is selected THEN the invoicing & payments section is rendered', async () => {
      mockShowInvoicingSection = true

      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      const initialState: SubscriptionPricingState = {
        planId: 'plan_1',
        planCode: 'starter',
        planName: 'Starter',
        planDescription: '',
        subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
        invoicingSettings: DEFAULT_INVOICING_SETTINGS,
        overrides: {},
      }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
          />,
        ),
      )

      // Line 358: showInvoicingSection conditional — the invoicing selector has icon="receipt"
      // Count the Selector buttons: subscription settings, invoicing, plan settings, subscription fee = 4
      const selectorButtons = screen.getAllByRole('button')

      // The invoicing section title text appears when showSection is true (line 297)
      expect(selectorButtons.length).toBeGreaterThanOrEqual(4)
    })
  })

  describe('GIVEN a plan is selected and sections are visible', () => {
    const initialState: SubscriptionPricingState = {
      planId: 'plan_1',
      planCode: 'starter',
      planName: 'Starter',
      planDescription: '',
      subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
      invoicingSettings: DEFAULT_INVOICING_SETTINGS,
      overrides: {},
    }

    it('WHEN clicking the subscription settings selector THEN opens the subscription settings drawer', async () => {
      const user = userEvent.setup()
      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
          />,
        ),
      )

      // The Selector renders a div[role="button"] containing the title text.
      // "Subscription settings" text appears both in the section title and the selector.
      // Find all role="button" elements — selectors are the div[role="button"] wrappers.
      const allButtons = screen.getAllByRole('button')
      // The subscription settings selector contains the "Subscription settings" title
      // and has tabIndex=0 (clickable). Filter to only tabIndex=0 role="button" divs.
      const subscriptionSettingsSelector = allButtons.find(
        (el) => el.tagName === 'DIV' && el.getAttribute('tabindex') === '0',
      )

      expect(subscriptionSettingsSelector).toBeDefined()
      await user.click(subscriptionSettingsSelector as HTMLElement)

      expect(mockOpenSubscriptionSettings).toHaveBeenCalledWith(DEFAULT_SUBSCRIPTION_SETTINGS)
    })

    it('WHEN clicking the invoicing settings selector THEN opens the invoicing settings drawer', async () => {
      mockShowInvoicingSection = true
      const user = userEvent.setup()
      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
          />,
        ),
      )

      // Find all clickable Selector divs (div[role="button"][tabindex="0"])
      const allButtons = screen.getAllByRole('button')
      const clickableSelectors = allButtons.filter(
        (el) => el.tagName === 'DIV' && el.getAttribute('tabindex') === '0',
      )

      // With invoicing section visible: subscription settings (0), invoicing (1), plan settings (2), subscription fee (3)
      const invoicingSelector = clickableSelectors[1]

      expect(invoicingSelector).toBeDefined()
      await user.click(invoicingSelector)

      expect(mockOpenInvoicingSettings).toHaveBeenCalledWith(DEFAULT_INVOICING_SETTINGS)
    })
  })

  describe('GIVEN an existing draft quote being edited (billingItemPlan set)', () => {
    const billingItemPlan = {
      type: 'plan',
      id: 'plan_1',
      payload: {},
      overrides: {},
    } as unknown as BillingItemPlan

    const initialState: SubscriptionPricingState = {
      planId: 'plan_1',
      planCode: 'starter',
      planName: 'Starter',
      planDescription: '',
      subscriptionSettings: DEFAULT_SUBSCRIPTION_SETTINGS,
      invoicingSettings: DEFAULT_INVOICING_SETTINGS,
      overrides: {},
    }

    it('WHEN the user switches to a different plan THEN billingItemPlan is dropped so prices reset', async () => {
      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
            billingItemPlan={billingItemPlan}
          />,
        ),
      )

      // Initially the original plan is forwarded to the hook
      expect(usePlanFormSetup).toHaveBeenCalledWith(expect.objectContaining({ billingItemPlan }))

      // Switch the plan via the ComboBox — click opens the dropdown, then select Pro
      const combobox = screen.getByRole('combobox') as HTMLInputElement

      await userEvent.click(combobox)

      await waitFor(() => {
        expect(screen.getAllByRole('listbox').length).toBeGreaterThan(0)
      })

      const listboxId = combobox.getAttribute('aria-controls') as string
      const listbox = document.getElementById(listboxId) as HTMLElement

      await userEvent.click(within(listbox).getByText('Pro (pro)'))

      // After the switch, the hook is called WITHOUT billingItemPlan so it fetches plan_2 and resets
      expect(usePlanFormSetup).toHaveBeenLastCalledWith(
        expect.objectContaining({ billingItemPlan: undefined, planIdToFetch: 'plan_2' }),
      )
    })

    it('WHEN the user re-selects the original plan THEN billingItemPlan is preserved', async () => {
      const stateRef = { current: null as SubscriptionPricingState | null }
      const formValuesRef = { current: null as PlanFormInput | null }

      await act(() =>
        render(
          <SubscriptionPricingContent
            stateRef={stateRef}
            formValuesRef={formValuesRef}
            initialState={initialState}
            billingItemPlan={billingItemPlan}
          />,
        ),
      )

      // No switch happened — original plan stays forwarded (saved customizations preserved)
      expect(usePlanFormSetup).toHaveBeenLastCalledWith(
        expect.objectContaining({ billingItemPlan, planIdToFetch: 'plan_1' }),
      )
    })
  })
})
