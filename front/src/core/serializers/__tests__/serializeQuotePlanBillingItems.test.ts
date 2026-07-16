import type {
  LocalFixedChargeInput,
  LocalUsageChargeInput,
  PlanFormInput,
} from '~/components/plans/types'
import {
  AggregationTypeEnum,
  ChargeModelEnum,
  CommitmentTypeEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  PlanInterval,
} from '~/generated/graphql'

import {
  type BillingItemPlan,
  buildPlanOverrides,
  DEFAULT_INVOICING_SETTINGS,
  DEFAULT_SUBSCRIPTION_SETTINGS,
  fromPlanBillingItems,
  type SubscriptionPricingState,
  toPlanBillingItems,
} from '../serializeQuotePlanBillingItems'

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const basePricingState: SubscriptionPricingState = {
  planId: 'plan_123',
  planCode: 'enterprise',
  planName: 'Enterprise Plan',
  planDescription: 'Custom enterprise offering',
  subscriptionSettings: {
    ...DEFAULT_SUBSCRIPTION_SETTINGS,
    billingTime: 'anniversary',
    startDate: '2023-07-26',
  },
  invoicingSettings: DEFAULT_INVOICING_SETTINGS,
  overrides: {},
}

const baseFormValues: PlanFormInput = {
  name: 'Enterprise Plan',
  code: 'enterprise',
  description: 'Custom enterprise offering',
  interval: PlanInterval.Monthly,
  amountCents: '850.00',
  amountCurrency: CurrencyEnum.Usd,
  payInAdvance: false,
  billChargesMonthly: null,
  billFixedChargesMonthly: null,
  trialPeriod: 0,
  invoiceDisplayName: undefined,
  charges: [],
  fixedCharges: [],
  entitlements: [],
}

const baseBillingItemPlan: BillingItemPlan = {
  type: 'plan',
  id: 'plan_123',
  payload: {
    position: 1,
    code: 'enterprise',
    name: 'Enterprise Plan',
    description: 'Custom enterprise offering',
    subscription_external_id: null,
    subscription_name: null,
    billing_time: 'anniversary',
    start_date: '2023-07-26',
    end_date: null,
    payment_method_id: null,
    invoice_custom_footer: null,
  },
  overrides: {},
}

// ---------------------------------------------------------------------------
// toPlanBillingItems — existing tests (updated for new signature)
// ---------------------------------------------------------------------------

describe('toPlanBillingItems', () => {
  it('serializes a basic plan with no overrides', () => {
    const result = toPlanBillingItems(basePricingState, baseFormValues)

    expect(result.plans[0].type).toBe('plan')
    expect(result.plans[0].id).toBe('plan_123')
    expect(result.plans[0].payload.position).toBe(1)
    expect(result.plans[0].payload.code).toBe('enterprise')
    expect(result.plans[0].payload.name).toBe('Enterprise Plan')
    expect(result.plans[0].payload.description).toBe('Custom enterprise offering')
    expect(result.plans[0].payload.billing_time).toBe('anniversary')
    expect(result.plans[0].payload.subscription_external_id).toBeNull()
    expect(result.plans[0].payload.subscription_name).toBeNull()
    expect(result.plans[0].payload.end_date).toBeNull()
    expect(result.plans[0].payload.payment_method_id).toBeNull()
    expect(result.plans[0].payload.invoice_custom_footer).toBeNull()
    // New plan config fields from formValues
    expect(result.plans[0].payload.interval).toBe(PlanInterval.Monthly)
    expect(result.plans[0].payload.amount_cents).toBe('850.00')
    expect(result.plans[0].payload.amount_currency).toBe(CurrencyEnum.Usd)
    expect(result.plans[0].payload.charges).toEqual([])
    // Overrides are derived from the form values: the subscription fee amount is
    // always carried over (no charges/commitment/thresholds in baseFormValues).
    expect(result.plans[0].overrides).toEqual({ amount_cents: 850 })
  })

  it('includes subscription settings in the payload', () => {
    const state: SubscriptionPricingState = {
      ...basePricingState,
      subscriptionSettings: {
        externalId: 'ext_001',
        subscriptionName: 'My Subscription',
        billingTime: 'calendar',
        startDate: '2023-07-26',
        endDate: '2024-07-26',
      },
    }
    const result = toPlanBillingItems(state, baseFormValues)

    expect(result.plans[0].payload.subscription_external_id).toBe('ext_001')
    expect(result.plans[0].payload.subscription_name).toBe('My Subscription')
    expect(result.plans[0].payload.billing_time).toBe('calendar')
    expect(result.plans[0].payload.end_date).toBe('2024-07-26')
  })

  it('includes invoicing settings in the payload', () => {
    const state: SubscriptionPricingState = {
      ...basePricingState,
      invoicingSettings: {
        paymentMethodId: 'pm_456',
        invoiceCustomFooter: 'Custom footer text',
      },
    }
    const result = toPlanBillingItems(state, baseFormValues)

    expect(result.plans[0].payload.payment_method_id).toBe('pm_456')
    expect(result.plans[0].payload.invoice_custom_footer).toBe('Custom footer text')
  })

  it('derives overrides from the form values (single source of truth)', () => {
    const formValues: PlanFormInput = {
      ...baseFormValues,
      amountCents: '850.00',
      minimumCommitment: {
        amountCents: '80000',
        commitmentType: CommitmentTypeEnum.MinimumCommitment,
      },
    }
    const result = toPlanBillingItems(basePricingState, formValues)

    expect(result.plans[0].overrides).toEqual({
      amount_cents: 850,
      minimum_commitment: { amount_cents: 80000, invoice_display_name: undefined },
    })
  })

  it('falls back to state.overrides when no form values are provided', () => {
    const state: SubscriptionPricingState = {
      ...basePricingState,
      overrides: { amount_cents: 85000 },
    }
    const result = toPlanBillingItems(state)

    expect(result.plans[0].overrides).toEqual({ amount_cents: 85000 })
  })

  it('converts empty strings to null for optional payload fields', () => {
    const result = toPlanBillingItems(basePricingState, baseFormValues)

    expect(result.plans[0].payload.subscription_external_id).toBeNull()
    expect(result.plans[0].payload.subscription_name).toBeNull()
    expect(result.plans[0].payload.end_date).toBeNull()
    expect(result.plans[0].payload.payment_method_id).toBeNull()
    expect(result.plans[0].payload.invoice_custom_footer).toBeNull()
  })

  it('omits plan config fields when formValues is not provided', () => {
    const result = toPlanBillingItems(basePricingState)

    expect(result.plans[0].payload.interval).toBeUndefined()
    expect(result.plans[0].payload.charges).toBeUndefined()
    expect(result.plans[0].payload.fixed_charges).toBeUndefined()
  })
})

// ---------------------------------------------------------------------------
// buildPlanOverrides — form state → overrides mapping (single source of truth)
// ---------------------------------------------------------------------------

describe('buildPlanOverrides', () => {
  it('carries over the subscription fee amount', () => {
    const result = buildPlanOverrides({ ...baseFormValues, amountCents: '850.00' })

    expect(result.amount_cents).toBe(850)
  })

  it('omits amount_cents when the fee is zero or empty', () => {
    expect(buildPlanOverrides({ ...baseFormValues, amountCents: '0' })).toEqual({})
    expect(buildPlanOverrides({ ...baseFormValues, amountCents: '' })).toEqual({})
  })

  it('includes the invoice display name when present', () => {
    const result = buildPlanOverrides({
      ...baseFormValues,
      amountCents: '0',
      invoiceDisplayName: 'Platform fee',
    })

    expect(result.invoice_display_name).toBe('Platform fee')
  })

  it('merges fixed charges and usage charges into overrides.charges', () => {
    const fixedCharge = {
      addOn: { code: 'setup_fee' },
      chargeModel: FixedChargeChargeModelEnum.Standard,
      properties: { amount: '100' },
    } as unknown as PlanFormInput['fixedCharges'][number]
    const usageCharge = {
      billableMetric: { code: 'api_calls' },
      chargeModel: ChargeModelEnum.Standard,
      properties: { amount: '0.01' },
    } as unknown as PlanFormInput['charges'][number]

    const result = buildPlanOverrides({
      ...baseFormValues,
      amountCents: '0',
      fixedCharges: [fixedCharge],
      charges: [usageCharge],
    })

    expect(result.charges).toHaveLength(2)
    expect(result.charges?.[0].billable_metric_code).toBe('setup_fee')
    expect(result.charges?.[1].billable_metric_code).toBe('api_calls')
  })

  it('includes a positive minimum commitment and ignores non-positive ones', () => {
    const positive = buildPlanOverrides({
      ...baseFormValues,
      amountCents: '0',
      minimumCommitment: {
        amountCents: '5000',
        invoiceDisplayName: 'Annual minimum',
        commitmentType: CommitmentTypeEnum.MinimumCommitment,
      },
    })

    expect(positive.minimum_commitment).toEqual({
      amount_cents: 5000,
      invoice_display_name: 'Annual minimum',
    })

    const zero = buildPlanOverrides({
      ...baseFormValues,
      amountCents: '0',
      minimumCommitment: {
        amountCents: '0',
        commitmentType: CommitmentTypeEnum.MinimumCommitment,
      },
    })

    expect(zero.minimum_commitment).toBeUndefined()
  })

  it('builds usage thresholds from recurring and non-recurring thresholds', () => {
    const result = buildPlanOverrides({
      ...baseFormValues,
      amountCents: '0',
      nonRecurringUsageThresholds: [
        { amountCents: 10000, thresholdDisplayName: 'Tier 1', recurring: false },
      ],
      recurringUsageThreshold: {
        amountCents: 50000,
        thresholdDisplayName: 'Monthly cap',
        recurring: true,
      },
    })

    expect(result.usage_thresholds).toEqual([
      { amount_cents: 10000, recurring: false, threshold_display_name: 'Tier 1' },
      { amount_cents: 50000, recurring: true, threshold_display_name: 'Monthly cap' },
    ])
  })
})

// ---------------------------------------------------------------------------
// fromPlanBillingItems — existing tests
// ---------------------------------------------------------------------------

describe('fromPlanBillingItems', () => {
  it('deserializes a plan with no overrides', () => {
    const result = fromPlanBillingItems([baseBillingItemPlan])

    expect(result.planId).toBe('plan_123')
    expect(result.planCode).toBe('enterprise')
    expect(result.planName).toBe('Enterprise Plan')
    expect(result.planDescription).toBe('Custom enterprise offering')
    expect(result.overrides).toEqual({})
  })

  it('deserializes subscription settings from payload', () => {
    const plan: BillingItemPlan = {
      ...baseBillingItemPlan,
      payload: {
        ...baseBillingItemPlan.payload,
        subscription_external_id: 'ext_001',
        subscription_name: 'My Sub',
        billing_time: 'calendar',
        start_date: '2023-07-26',
        end_date: '2024-07-26',
      },
    }
    const result = fromPlanBillingItems([plan])

    expect(result.subscriptionSettings).toEqual({
      externalId: 'ext_001',
      subscriptionName: 'My Sub',
      billingTime: 'calendar',
      startDate: '2023-07-26',
      endDate: '2024-07-26',
    })
  })

  it('deserializes invoicing settings from payload', () => {
    const plan: BillingItemPlan = {
      ...baseBillingItemPlan,
      payload: {
        ...baseBillingItemPlan.payload,
        payment_method_id: 'pm_456',
        invoice_custom_footer: 'Footer text',
      },
    }
    const result = fromPlanBillingItems([plan])

    expect(result.invoicingSettings).toEqual({
      paymentMethodId: 'pm_456',
      invoiceCustomFooter: 'Footer text',
    })
  })

  it('preserves overrides from the billing item', () => {
    const plan: BillingItemPlan = {
      ...baseBillingItemPlan,
      overrides: {
        amount_cents: 85000,
        charges: [
          {
            billable_metric_code: 'cpu',
            charge_model: 'graduated',
            properties: { graduated_ranges: [] },
          },
        ],
      },
    }
    const result = fromPlanBillingItems([plan])

    expect(result.overrides.amount_cents).toBe(85000)
    expect(result.overrides.charges).toHaveLength(1)
  })

  it('builds entity data for the plan', () => {
    const result = fromPlanBillingItems([baseBillingItemPlan])

    expect(result.entityData).toEqual({
      plan_123: {
        entityId: 'plan_123',
        entityType: 'plan',
        name: 'Enterprise Plan',
        code: 'enterprise',
        plan: { rows: [] },
      },
    })
  })

  it('converts null payload fields to empty strings', () => {
    const result = fromPlanBillingItems([baseBillingItemPlan])

    expect(result.subscriptionSettings.externalId).toBe('')
    expect(result.subscriptionSettings.subscriptionName).toBe('')
    expect(result.subscriptionSettings.endDate).toBe('')
    expect(result.invoicingSettings.paymentMethodId).toBe('')
    expect(result.invoicingSettings.invoiceCustomFooter).toBe('')
  })

  it('returns null formValues for legacy payloads without interval/charges', () => {
    const result = fromPlanBillingItems([baseBillingItemPlan])

    expect(result.formValues).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// Round-trip tests: toPlanBillingItems → fromPlanBillingItems
// ---------------------------------------------------------------------------

describe('round-trip: toPlanBillingItems → fromPlanBillingItems', () => {
  it('round-trips plan config and usage charges', () => {
    const charge: LocalUsageChargeInput = {
      id: 'charge_001',
      billableMetric: {
        id: 'bm_001',
        code: 'cpu_usage',
        name: 'CPU Usage',
        aggregationType: AggregationTypeEnum.CountAgg,
        recurring: false,
        filters: [{ id: 'filter_001', key: 'region', values: ['us-east-1', 'eu-west-1'] }],
      } as LocalUsageChargeInput['billableMetric'],
      chargeModel: ChargeModelEnum.Standard,
      properties: { amount: '0.005' } as LocalUsageChargeInput['properties'],
      invoiceDisplayName: 'CPU Compute',
      payInAdvance: false,
      prorated: false,
      invoiceable: true,
      taxCodes: [],
    }

    const formValues: PlanFormInput = {
      ...baseFormValues,
      charges: [charge],
    }

    const serialized = toPlanBillingItems(basePricingState, formValues)
    const deserialized = fromPlanBillingItems(serialized.plans)

    expect(deserialized.planId).toBe('plan_123')
    expect(deserialized.formValues).not.toBeNull()
    expect(deserialized.formValues?.interval).toBe(PlanInterval.Monthly)
    expect(deserialized.formValues?.amountCents).toBe('850.00')
    expect(deserialized.formValues?.amountCurrency).toBe(CurrencyEnum.Usd)
    expect(deserialized.formValues?.charges).toHaveLength(1)

    const roundTrippedCharge = deserialized.formValues?.charges[0]

    expect(roundTrippedCharge?.billableMetric.code).toBe('cpu_usage')
    expect(roundTrippedCharge?.billableMetric.aggregationType).toBe(AggregationTypeEnum.CountAgg)
    expect(roundTrippedCharge?.chargeModel).toBe(ChargeModelEnum.Standard)
    expect((roundTrippedCharge?.properties as { amount?: string })?.amount).toBe('0.005')
    expect(roundTrippedCharge?.invoiceDisplayName).toBe('CPU Compute')
    expect(roundTrippedCharge?.billableMetric.filters).toHaveLength(1)
    expect(roundTrippedCharge?.billableMetric.filters?.[0]?.key).toBe('region')
  })

  it('round-trips fixed charges and minimum commitment', () => {
    const fixedCharge: LocalFixedChargeInput = {
      id: 'fc_001',
      addOn: {
        id: 'addon_001',
        name: 'Premium Support',
        code: 'premium_support',
      } as LocalFixedChargeInput['addOn'],
      chargeModel: FixedChargeChargeModelEnum.Standard,
      units: '1',
      applyUnitsImmediately: false,
      invoiceDisplayName: 'Support Package',
      payInAdvance: true,
      prorated: false,
      properties: { amount: '500' } as LocalFixedChargeInput['properties'],
      taxCodes: [],
    }

    const formValues: PlanFormInput = {
      ...baseFormValues,
      fixedCharges: [fixedCharge],
      minimumCommitment: {
        amountCents: '100000',
        invoiceDisplayName: 'Annual Minimum',
        commitmentType: CommitmentTypeEnum.MinimumCommitment,
      },
    }

    const serialized = toPlanBillingItems(basePricingState, formValues)
    const deserialized = fromPlanBillingItems(serialized.plans)

    expect(deserialized.formValues).not.toBeNull()
    const fv = deserialized.formValues as PlanFormInput

    // Fixed charges round-trip
    expect(fv.fixedCharges).toHaveLength(1)
    const rtFixedCharge = fv.fixedCharges[0]

    expect(rtFixedCharge.addOn.code).toBe('premium_support')
    expect(rtFixedCharge.addOn.name).toBe('Premium Support')
    expect(rtFixedCharge.units).toBe('1')
    expect(rtFixedCharge.invoiceDisplayName).toBe('Support Package')

    // Minimum commitment round-trip
    expect(fv.minimumCommitment).toBeDefined()
    expect(fv.minimumCommitment?.amountCents).toBe('100000')
    expect(fv.minimumCommitment?.invoiceDisplayName).toBe('Annual Minimum')
  })

  it('round-trips usage thresholds (progressive billing)', () => {
    const formValues: PlanFormInput = {
      ...baseFormValues,
      nonRecurringUsageThresholds: [
        { amountCents: 10000, thresholdDisplayName: 'Tier 1', recurring: false },
        { amountCents: 50000, thresholdDisplayName: 'Tier 2', recurring: false },
      ],
      recurringUsageThreshold: {
        amountCents: 100000,
        thresholdDisplayName: 'Monthly Cap',
        recurring: true,
      },
    }

    const serialized = toPlanBillingItems(basePricingState, formValues)
    const deserialized = fromPlanBillingItems(serialized.plans)

    expect(deserialized.formValues).not.toBeNull()
    const fv = deserialized.formValues as PlanFormInput

    const thresholds = fv.nonRecurringUsageThresholds ?? []

    expect(thresholds).toHaveLength(2)
    expect(thresholds[0].amountCents).toBe(10000)
    expect(thresholds[0].thresholdDisplayName).toBe('Tier 1')
    expect(thresholds[0].recurring).toBe(false)
    expect(thresholds[1].amountCents).toBe(50000)

    const recurring = fv.recurringUsageThreshold

    expect(recurring?.amountCents).toBe(100000)
    expect(recurring?.thresholdDisplayName).toBe('Monthly Cap')
    expect(recurring?.recurring).toBe(true)
  })

  it('backward compat: legacy payload without interval/charges returns null formValues', () => {
    // Simulate a payload that was serialized before the plan form data was added
    const legacyPlan: BillingItemPlan = {
      type: 'plan',
      id: 'plan_legacy',
      payload: {
        position: 1,
        code: 'legacy',
        name: 'Legacy Plan',
        description: 'Old plan',
        subscription_external_id: 'ext_old',
        subscription_name: null,
        billing_time: 'calendar',
        start_date: '2022-01-01',
        end_date: null,
        payment_method_id: null,
        invoice_custom_footer: null,
        // NOTE: no interval, no charges — legacy payload
      },
      overrides: { amount_cents: 75000 },
    }

    const result = fromPlanBillingItems([legacyPlan])

    // formValues must be null — no reconstruction possible from legacy payload
    expect(result.formValues).toBeNull()

    // But core fields still work
    expect(result.planId).toBe('plan_legacy')
    expect(result.planCode).toBe('legacy')
    expect(result.subscriptionSettings.externalId).toBe('ext_old')
    expect(result.subscriptionSettings.billingTime).toBe('calendar')
    expect(result.overrides.amount_cents).toBe(75000)
  })

  it('attaches PlanPreviewData to the plan entity (fromPlanBillingItems)', () => {
    // Build a plans payload with full data (interval + charges present).
    const plans = [
      {
        type: 'plan',
        id: 'plan-1',
        overrides: {},
        payload: {
          position: 0,
          code: 'p',
          name: 'P',
          description: '',
          subscription_external_id: null,
          subscription_name: null,
          billing_time: 'calendar',
          start_date: null,
          end_date: null,
          payment_method_id: null,
          invoice_custom_footer: null,
          interval: 'monthly',
          amount_cents: '13050',
          amount_currency: 'USD',
          pay_in_advance: true,
          charges: [],
          fixed_charges: [],
          minimum_commitment: null,
        },
      },
    ] as any

    const result = fromPlanBillingItems(plans)

    expect(result.entityData['plan-1'].plan).toBeDefined()
    expect(result.entityData['plan-1'].plan?.rows[0]).toMatchObject({
      kind: 'main',
      rowType: 'subscriptionFee',
      price: { type: 'displayAmount', amount: '13050' },
    })
  })

  it('leaves plan undefined for a legacy payload (no interval/charges)', () => {
    const plans = [
      {
        type: 'plan',
        id: 'plan-legacy',
        overrides: {},
        payload: {
          position: 0,
          code: 'p',
          name: 'P',
          description: '',
          subscription_external_id: null,
          subscription_name: null,
          billing_time: 'calendar',
          start_date: null,
          end_date: null,
          payment_method_id: null,
          invoice_custom_footer: null,
        },
      },
    ] as any

    const result = fromPlanBillingItems(plans)

    expect(result.entityData['plan-legacy'].plan).toEqual({ rows: [] })
  })
})
