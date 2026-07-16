import { LocalPricingUnitType, PlanFormInput } from '~/components/plans/types'
import {
  AggregationTypeEnum,
  ChargeModelEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  PlanInterval,
  PlanOverridesInput,
  RegroupPaidFeesEnum,
} from '~/generated/graphql'
import { buildPlanOverridesInput, cleanPlanValues } from '~/hooks/customer/useAddSubscription'

describe('cleanPlanValues', () => {
  // Mock plan form input with all the fields that exist in the form but should be cleaned
  const mockPlanFormInput: PlanFormInput = {
    name: 'Test Plan',
    code: 'PLAN_CODE',
    description: 'Test Description',
    interval: PlanInterval.Monthly,
    entitlements: [],
    amountCents: '1000',
    amountCurrency: CurrencyEnum.Usd,
    trialPeriod: 7,
    invoiceDisplayName: 'Test Invoice Display Name',
    payInAdvance: true,
    billChargesMonthly: false,
    billFixedChargesMonthly: false,
    taxCodes: ['TAX001', 'TAX002'],
    taxes: [
      {
        id: 'tax-1',
        name: 'Tax 1',
        code: 'TAX001',
        rate: 0.1,
      },
    ],
    cascadeUpdates: true,
    nonRecurringUsageThresholds: [
      {
        amountCents: 1000,
        recurring: false,
        thresholdDisplayName: 'Non-recurring threshold',
      },
    ],
    recurringUsageThreshold: {
      amountCents: 5000,
      recurring: true,
      thresholdDisplayName: 'Recurring threshold',
    },
    fixedCharges: [
      {
        id: 'fixed-charge-1',
        invoiceDisplayName: 'Fixed Charge 1',
        payInAdvance: true,
        prorated: false,
        chargeModel: FixedChargeChargeModelEnum.Standard,
        addOn: {
          id: 'add-on-1',
          name: 'Add On 1',
          code: 'ADD_ON_1',
        },
      },
      {
        id: 'fixed-charge-2',
        invoiceDisplayName: 'Fixed Charge 2',
        payInAdvance: false,
        prorated: true,
        chargeModel: FixedChargeChargeModelEnum.Graduated,
        addOn: {
          id: 'add-on-2',
          name: 'Add On 2',
          code: 'ADD_ON_2',
        },
      },
    ],
    charges: [
      {
        id: 'charge-1',
        billableMetric: {
          id: 'metric-1',
          name: 'Metric 1',
          code: 'METRIC_1',
          aggregationType: AggregationTypeEnum.CountAgg,
          recurring: false,
        },
        chargeModel: ChargeModelEnum.Standard,
        invoiceDisplayName: 'Charge 1',
        minAmountCents: '100',
        payInAdvance: true,
        invoiceable: true,
        prorated: false,
        regroupPaidFees: RegroupPaidFeesEnum.Invoice,
        properties: {
          amount: '10.00',
          rate: '0.05',
        },
        appliedPricingUnit: {
          code: CurrencyEnum.Usd,
          conversionRate: '2.5',
          shortName: 'USD',
          type: LocalPricingUnitType.Fiat,
        },
        taxCodes: ['TAX003'],
        taxes: [
          {
            id: 'tax-3',
            name: 'Tax 3',
            code: 'TAX003',
            rate: 0.05,
          },
        ],
        filters: [],
      },
    ],
  }

  const mockPlanOverrides = mockPlanFormInput as unknown as PlanOverridesInput

  it('should clean plan values and preserve taxCodes', () => {
    const result = cleanPlanValues(mockPlanOverrides)

    // Should preserve valid PlanOverridesInput fields
    expect(result.name).toBe('Test Plan')
    expect(result.description).toBe('Test Description')
    expect(result.amountCents).toBe('1000')
    expect(result.trialPeriod).toBe(7)
    expect(result.invoiceDisplayName).toBe('Test Invoice Display Name')
    expect(result.taxCodes).toEqual(['TAX001', 'TAX002']) // Should be preserved for creation

    // Should remove plan-level fields not in PlanOverridesInput
    expect(result.code).toBeUndefined()
    expect(result.interval).toBeUndefined()
    expect(result.taxes).toBeUndefined()
    expect(result.payInAdvance).toBeUndefined()
    expect(result.billChargesMonthly).toBeUndefined()
    expect(result.billFixedChargesMonthly).toBeUndefined()
    expect(result.cascadeUpdates).toBeUndefined()
    expect(result.entitlements).toBeUndefined()
    expect(result.usageThresholds).toBeUndefined()

    // Should clean charges
    expect(result.charges).toHaveLength(1)
    const cleanedCharge = result.charges?.[0]

    // Should preserve valid charge fields
    expect(cleanedCharge?.id).toBe('charge-1')
    expect(cleanedCharge?.invoiceDisplayName).toBe('Charge 1')
    expect(cleanedCharge?.minAmountCents).toBe('100')
    expect(cleanedCharge?.properties).toEqual({
      amount: '10.00',
      rate: '0.05',
    })
    expect(cleanedCharge?.taxCodes).toEqual(['TAX003'])
    //   appliedPricingUnit should only contain conversionRate
    expect(cleanedCharge?.appliedPricingUnit).toEqual({ conversionRate: 2.5 })

    // Should remove charge fields not in ChargeOverridesInput
    expect(cleanedCharge?.taxes).toBeUndefined()
    expect(cleanedCharge?.payInAdvance).toBeUndefined()
    expect(cleanedCharge?.billableMetric).toBeUndefined()
    expect(cleanedCharge?.chargeModel).toBeUndefined()
    expect(cleanedCharge?.invoiceable).toBeUndefined()
    expect(cleanedCharge?.prorated).toBeUndefined()
    expect(cleanedCharge?.regroupPaidFees).toBeUndefined()

    // Should clean fixed charges
    expect(result.fixedCharges).toHaveLength(2)
    const cleanedFixedCharge = result.fixedCharges?.[0]

    expect(cleanedFixedCharge?.id).toBe('fixed-charge-1')
    expect(cleanedFixedCharge?.invoiceDisplayName).toBe('Fixed Charge 1')
    expect(cleanedFixedCharge?.payInAdvance).toBeUndefined()
    expect(cleanedFixedCharge?.prorated).toBeUndefined()
    expect(cleanedFixedCharge?.chargeModel).toBeUndefined()
  })

  describe('edge cases', () => {
    it('should handle empty plan values', () => {
      const emptyPlanValues: PlanOverridesInput = {}
      const result = cleanPlanValues(emptyPlanValues)

      expect(result).toEqual({
        code: undefined,
        interval: undefined,
        taxCodes: undefined,
        taxes: undefined,
        payInAdvance: undefined,
        billChargesMonthly: undefined,
        billFixedChargesMonthly: undefined,
        cascadeUpdates: undefined,
        entitlements: undefined,
        usageThresholds: undefined,
        charges: undefined,
        fixedCharges: undefined,
      })
    })

    it('should handle plan values with empty charges array', () => {
      const planWithEmptyCharges: PlanOverridesInput = {
        name: 'Test Plan',
        charges: [],
      }
      const result = cleanPlanValues(planWithEmptyCharges)

      expect(result.charges).toEqual([])
      expect(result.name).toBe('Test Plan')
    })

    it('should handle charge with string conversion rate', () => {
      const planWithStringConversionRate: PlanOverridesInput = {
        charges: [
          {
            billableMetricId: 'metric-1',
            appliedPricingUnit: {
              conversionRate: 3.14159,
            },
          },
        ],
      }
      const result = cleanPlanValues(planWithStringConversionRate)

      expect(result.charges?.[0]?.appliedPricingUnit?.conversionRate).toBe(3.14159)
    })

    it('should handle charge without appliedPricingUnit', () => {
      const planWithoutPricingUnit: PlanOverridesInput = {
        charges: [
          {
            billableMetricId: 'metric-1',
          },
        ],
      }
      const result = cleanPlanValues(planWithoutPricingUnit)

      expect(result.charges?.[0]?.appliedPricingUnit).toBeUndefined()
    })
  })
})

describe('buildPlanOverridesInput', () => {
  const buildBaseValues = (): PlanFormInput =>
    ({
      name: 'Standard with Fixed Charges',
      code: 'PLAN_CODE',
      description: '',
      interval: PlanInterval.Monthly,
      entitlements: [],
      amountCents: '10',
      amountCurrency: CurrencyEnum.Usd,
      trialPeriod: 0,
      payInAdvance: true,
      billChargesMonthly: false,
      billFixedChargesMonthly: false,
      taxes: [],
      minimumCommitment: {},
      charges: [],
      fixedCharges: [
        {
          id: 'fixed-charge-1',
          units: '1',
          invoiceDisplayName: 'Fixed Charge 1',
          payInAdvance: false,
          prorated: false,
          chargeModel: FixedChargeChargeModelEnum.Standard,
          properties: { amount: '12' },
          taxes: [],
          addOn: { id: 'add-on-1', name: 'Add On 1', code: 'ADD_ON_1' },
        },
        {
          id: 'fixed-charge-2',
          units: '5',
          invoiceDisplayName: 'Fixed Charge 2',
          payInAdvance: false,
          prorated: false,
          chargeModel: FixedChargeChargeModelEnum.Standard,
          properties: { amount: '20' },
          taxes: [],
          addOn: { id: 'add-on-2', name: 'Add On 2', code: 'ADD_ON_2' },
        },
      ],
    }) as unknown as PlanFormInput

  const clone = (values: PlanFormInput): PlanFormInput =>
    JSON.parse(JSON.stringify(values)) as PlanFormInput

  it('sends only the changed fixed charge id + units when nothing else changed', () => {
    const baseline = buildBaseValues()
    const current = clone(baseline)

    // Only the first fixed charge's units changed
    ;(current.fixedCharges[0] as { units: string }).units = '3'

    const result = buildPlanOverridesInput(current, baseline)

    expect(result).toEqual({
      fixedCharges: [{ id: 'fixed-charge-1', units: '3' }],
    })
  })

  it('only includes the fixed charges whose units actually changed', () => {
    const baseline = buildBaseValues()
    const current = clone(baseline)

    // Both still present, but only the second one's units moved
    ;(current.fixedCharges[1] as { units: string }).units = '9'

    const result = buildPlanOverridesInput(current, baseline)

    expect(result).toEqual({
      fixedCharges: [{ id: 'fixed-charge-2', units: '9' }],
    })
  })

  it('treats drawer-added applyUnitsImmediately as noise, not a real change', () => {
    // The edit drawer writes the whole charge back, augmenting it with
    // `applyUnitsImmediately: false` — a field the untouched baseline charge
    // (pulled raw from the plan) never has. That asymmetry must not be read as
    // a non-units change.
    const baseline = buildBaseValues()
    const current = clone(baseline)

    ;(current.fixedCharges[0] as { units: string }).units = '99'
    ;(current.fixedCharges[0] as { applyUnitsImmediately: boolean }).applyUnitsImmediately = false

    const result = buildPlanOverridesInput(current, baseline)

    expect(result).toEqual({
      fixedCharges: [{ id: 'fixed-charge-1', units: '99' }],
    })
  })

  it('normalizes an empty invoiceDisplayName against an absent one', () => {
    const baseline = buildBaseValues()
    // Baseline charge has no invoiceDisplayName at all

    delete (baseline.fixedCharges[0] as { invoiceDisplayName?: string }).invoiceDisplayName
    const current = clone(baseline)

    ;(current.fixedCharges[0] as { units: string }).units = '99'
    // The drawer initializes the field to an empty string
    ;(current.fixedCharges[0] as { invoiceDisplayName: string }).invoiceDisplayName = ''

    const result = buildPlanOverridesInput(current, baseline)

    expect(result).toEqual({
      fixedCharges: [{ id: 'fixed-charge-1', units: '99' }],
    })
  })

  it('sends the full payload when a non-fixed-charge field also changed', () => {
    const baseline = buildBaseValues()
    const current = clone(baseline)

    ;(current.fixedCharges[0] as { units: string }).units = '3'
    current.amountCents = '20'

    const result = buildPlanOverridesInput(current, baseline)

    // Falls back to the full cleaned payload, not the minimal units-only one
    // (amountCents is serialized to cents: '20' USD → 2000)
    expect(result.amountCents).toBe(2000)
    expect(result.fixedCharges).toHaveLength(2)
    expect(result.fixedCharges?.[0]).toMatchObject({ id: 'fixed-charge-1', units: '3' })
  })

  it('sends the full payload when a fixed charge field other than units changed', () => {
    const baseline = buildBaseValues()
    const current = clone(baseline)

    ;(current.fixedCharges[0] as { units: string }).units = '3'
    ;(current.fixedCharges[0] as { invoiceDisplayName: string }).invoiceDisplayName = 'Renamed'

    const result = buildPlanOverridesInput(current, baseline)

    expect(result.fixedCharges).toHaveLength(2)
    expect(result.fixedCharges?.[0]).toMatchObject({ invoiceDisplayName: 'Renamed' })
  })

  it('sends the full payload when no baseline is available', () => {
    const current = buildBaseValues()

    const result = buildPlanOverridesInput(current, undefined)

    expect(result.fixedCharges).toHaveLength(2)
    expect(result.amountCents).toBe(1000)
  })
})
