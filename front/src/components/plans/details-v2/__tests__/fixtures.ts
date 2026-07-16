import {
  ChargeModelEnum,
  CommitmentTypeEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  PlanDetailsV2Fragment,
  PlanInterval,
  PrivilegeValueTypeEnum,
} from '~/generated/graphql'

export const PLAN_DETAILS_V2_FIXTURE_ID = 'plan_1'

type FixedCharge = NonNullable<PlanDetailsV2Fragment['fixedCharges']>[number]

export const buildFixedChargeFixture = (overrides: Partial<FixedCharge> = {}): FixedCharge => ({
  __typename: 'FixedCharge',
  id: 'fc_default',
  invoiceDisplayName: null,
  chargeModel: FixedChargeChargeModelEnum.Standard,
  units: '1',
  payInAdvance: false,
  prorated: false,
  properties: { amount: '49.99', graduatedRanges: null, volumeRanges: null },
  addOn: { __typename: 'AddOn', id: 'addon_1', name: 'Onboarding', code: 'onboarding' },
  taxes: [],
  ...overrides,
})

type UsageCharge = NonNullable<PlanDetailsV2Fragment['charges']>[number]

export const buildUsageChargeFixture = (overrides: Partial<UsageCharge> = {}): UsageCharge => ({
  __typename: 'Charge',
  id: 'ch_default',
  chargeModel: ChargeModelEnum.Standard,
  invoiceDisplayName: null,
  invoiceable: true,
  payInAdvance: false,
  prorated: false,
  minAmountCents: '0',
  regroupPaidFees: null,
  properties: { amount: '10', graduatedRanges: null, volumeRanges: null } as never,
  filters: [],
  appliedPricingUnit: null,
  taxes: [],
  billableMetric: {
    __typename: 'BillableMetric',
    id: 'bm_default',
    name: 'API calls',
    code: 'api_calls',
    aggregationType: 'count_agg',
    recurring: false,
    filters: [],
  } as never,
  ...overrides,
})

export const planDetailsV2Fixture: PlanDetailsV2Fragment & { __typename: 'Plan' } = {
  __typename: 'Plan',
  id: PLAN_DETAILS_V2_FIXTURE_ID,
  name: 'Pro',
  code: 'pro',
  description: null,
  interval: PlanInterval.Monthly,
  amountCurrency: CurrencyEnum.Usd,
  amountCents: '1000',
  payInAdvance: false,
  trialPeriod: 0,
  invoiceDisplayName: null,
  hasOverriddenPlans: false,
  subscriptionsCount: 0,
  billFixedChargesMonthly: false,
  billChargesMonthly: false,
  taxes: [],
  fixedCharges: [],
  charges: [],
  minimumCommitment: {
    __typename: 'Commitment',
    amountCents: 5000,
    commitmentType: CommitmentTypeEnum.MinimumCommitment,
    invoiceDisplayName: null,
    taxes: [],
  },
  usageThresholds: [
    {
      __typename: 'UsageThreshold',
      id: 'ut-1',
      amountCents: 10000,
      recurring: false,
      thresholdDisplayName: null,
    },
  ],
  entitlements: [
    {
      __typename: 'PlanEntitlement',
      code: 'seats',
      name: 'Seats',
      privileges: [
        {
          __typename: 'PlanEntitlementPrivilegeObject',
          code: 'max_seats',
          name: null,
          value: '10',
          valueType: PrivilegeValueTypeEnum.Integer,
          config: { __typename: 'PrivilegeConfigObject', selectOptions: null },
        },
      ],
    },
  ],
}
