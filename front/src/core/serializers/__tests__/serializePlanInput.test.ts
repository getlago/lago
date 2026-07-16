import { LocalPricingUnitType, PlanFormInput } from '~/components/plans/types'
import { transformFilterObjectToString } from '~/components/plans/utils'
import { ALL_FILTER_VALUES } from '~/core/constants/form'
import {
  serializeEntitlements,
  serializeFixedChargeProperties,
  serializeMinimumCommitment,
  serializePlanInput,
  serializeProperties,
  serializeUsageThresholds,
} from '~/core/serializers/serializePlanInput'
import {
  AggregationTypeEnum,
  ChargeModelEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  PlanInterval,
  PrivilegeValueTypeEnum,
} from '~/generated/graphql'

describe('serializeMinimumCommitment', () => {
  it('serializes amount to cents and maps tax codes', () => {
    expect(
      serializeMinimumCommitment(
        { amountCents: '50', taxes: [{ code: 'vat' }] } as PlanFormInput['minimumCommitment'],
        CurrencyEnum.Usd,
      ),
    ).toEqual(expect.objectContaining({ amountCents: 5000, taxCodes: ['vat'], taxes: undefined }))
  })
  it('returns {} when empty', () => {
    expect(
      serializeMinimumCommitment({} as PlanFormInput['minimumCommitment'], CurrencyEnum.Usd),
    ).toEqual({})
  })
  it('preserves invoiceDisplayName when provided', () => {
    expect(
      serializeMinimumCommitment(
        {
          amountCents: '50',
          invoiceDisplayName: 'Annual commitment',
          taxes: [],
        } as PlanFormInput['minimumCommitment'],
        CurrencyEnum.Usd,
      ),
    ).toEqual(
      expect.objectContaining({
        invoiceDisplayName: 'Annual commitment',
        amountCents: 5000,
        taxCodes: [],
      }),
    )
  })
  it('maps multiple tax codes in declared order', () => {
    expect(
      serializeMinimumCommitment(
        {
          amountCents: '10',
          taxes: [{ code: 'vat' }, { code: 'gst' }],
        } as PlanFormInput['minimumCommitment'],
        CurrencyEnum.Usd,
      ),
    ).toEqual(expect.objectContaining({ taxCodes: ['vat', 'gst'] }))
  })
  it('strips the source taxes array from the payload', () => {
    const result = serializeMinimumCommitment(
      { amountCents: '50', taxes: [{ code: 'vat' }] } as PlanFormInput['minimumCommitment'],
      CurrencyEnum.Usd,
    )

    expect(result).toHaveProperty('taxes', undefined)
  })
  it('returns {} when commitment is undefined', () => {
    expect(
      serializeMinimumCommitment(
        undefined as unknown as PlanFormInput['minimumCommitment'],
        CurrencyEnum.Usd,
      ),
    ).toEqual({})
  })
})

describe('serializeUsageThresholds', () => {
  it('combines non-recurring + recurring and serializes amounts', () => {
    expect(
      serializeUsageThresholds(
        [{ amountCents: '100', recurring: false }] as PlanFormInput['nonRecurringUsageThresholds'],
        { amountCents: '200', recurring: true } as PlanFormInput['recurringUsageThreshold'],
        CurrencyEnum.Usd,
      ),
    ).toEqual([
      { recurring: false, thresholdDisplayName: null, amountCents: 10000 },
      { recurring: true, thresholdDisplayName: null, amountCents: 20000 },
    ])
  })
  it('returns an empty array when nothing set, so the API clears existing thresholds', () => {
    expect(serializeUsageThresholds(undefined, undefined, CurrencyEnum.Usd)).toEqual([])
  })
  it('returns an empty array when the non-recurring list is empty and recurring is unset', () => {
    expect(
      serializeUsageThresholds(
        [] as unknown as PlanFormInput['nonRecurringUsageThresholds'],
        undefined,
        CurrencyEnum.Usd,
      ),
    ).toEqual([])
  })
  it('serializes only non-recurring thresholds when recurring is undefined', () => {
    expect(
      serializeUsageThresholds(
        [
          { amountCents: '5', recurring: false },
          { amountCents: '15', recurring: false },
        ] as PlanFormInput['nonRecurringUsageThresholds'],
        undefined,
        CurrencyEnum.Usd,
      ),
    ).toEqual([
      { recurring: false, thresholdDisplayName: null, amountCents: 500 },
      { recurring: false, thresholdDisplayName: null, amountCents: 1500 },
    ])
  })
  it('serializes only the recurring threshold when non-recurring list is empty', () => {
    expect(
      serializeUsageThresholds(
        [] as unknown as PlanFormInput['nonRecurringUsageThresholds'],
        { amountCents: '7', recurring: true } as PlanFormInput['recurringUsageThreshold'],
        CurrencyEnum.Usd,
      ),
    ).toEqual([{ recurring: true, thresholdDisplayName: null, amountCents: 700 }])
  })
  it('preserves thresholdDisplayName when set and converts undefined to null', () => {
    expect(
      serializeUsageThresholds(
        [
          { amountCents: '1', recurring: false, thresholdDisplayName: 'First' },
          { amountCents: '2', recurring: false },
        ] as PlanFormInput['nonRecurringUsageThresholds'],
        {
          amountCents: '3',
          recurring: true,
          thresholdDisplayName: 'Repeating',
        } as PlanFormInput['recurringUsageThreshold'],
        CurrencyEnum.Usd,
      ),
    ).toEqual([
      { recurring: false, thresholdDisplayName: 'First', amountCents: 100 },
      { recurring: false, thresholdDisplayName: null, amountCents: 200 },
      { recurring: true, thresholdDisplayName: 'Repeating', amountCents: 300 },
    ])
  })
  it('coerces missing recurring flag to false', () => {
    expect(
      serializeUsageThresholds(
        [{ amountCents: '1' }] as unknown as PlanFormInput['nonRecurringUsageThresholds'],
        undefined,
        CurrencyEnum.Usd,
      ),
    ).toEqual([{ recurring: false, thresholdDisplayName: null, amountCents: 100 }])
  })
})

describe('serializeEntitlements', () => {
  it('strips display-only fields', () => {
    expect(
      serializeEntitlements([
        {
          featureId: 'f1',
          featureName: 'Seats',
          featureCode: 'seats',
          privileges: [
            {
              privilegeCode: 'max',
              privilegeName: 'Max',
              value: '10',
              valueType: 'integer',
              config: {},
              id: 'p1',
            },
          ],
        },
      ] as PlanFormInput['entitlements']),
    ).toEqual([
      {
        featureCode: 'seats',
        featureId: undefined,
        featureName: undefined,
        privileges: [
          {
            privilegeCode: 'max',
            value: '10',
            privilegeName: undefined,
            valueType: undefined,
            config: undefined,
            id: undefined,
          },
        ],
      },
    ])
  })
  it('returns an empty array when input is empty', () => {
    expect(serializeEntitlements([] as PlanFormInput['entitlements'])).toEqual([])
  })
  it('serializes multiple entitlements in declared order', () => {
    const result = serializeEntitlements([
      { featureId: 'f1', featureName: 'Seats', featureCode: 'seats', privileges: [] },
      { featureId: 'f2', featureName: 'API', featureCode: 'api_calls', privileges: [] },
    ] as PlanFormInput['entitlements'])

    expect(result.map((e) => e.featureCode)).toEqual(['seats', 'api_calls'])
  })
  it('preserves privileges array when entitlement has no privileges', () => {
    expect(
      serializeEntitlements([
        { featureId: 'f1', featureName: 'Seats', featureCode: 'seats', privileges: [] },
      ] as PlanFormInput['entitlements']),
    ).toEqual([expect.objectContaining({ featureCode: 'seats', privileges: [] })])
  })
  it('strips display-only privilege fields for every privilege in the list', () => {
    const result = serializeEntitlements([
      {
        featureId: 'f1',
        featureName: 'Seats',
        featureCode: 'seats',
        privileges: [
          {
            privilegeCode: 'max',
            privilegeName: 'Max',
            value: '10',
            valueType: 'integer',
            config: {},
            id: 'p1',
          },
          {
            privilegeCode: 'min',
            privilegeName: 'Min',
            value: '1',
            valueType: 'integer',
            config: {},
            id: 'p2',
          },
        ],
      },
    ] as PlanFormInput['entitlements'])

    expect(result[0].privileges).toEqual([
      expect.objectContaining({
        privilegeCode: 'max',
        value: '10',
        privilegeName: undefined,
        valueType: undefined,
        config: undefined,
        id: undefined,
      }),
      expect.objectContaining({
        privilegeCode: 'min',
        value: '1',
        privilegeName: undefined,
        valueType: undefined,
        config: undefined,
        id: undefined,
      }),
    ])
  })
})

const fullProperty = {
  amount: '1',
  fixedAmount: '2',
  freeUnits: 1,
  freeUnitsPerEvents: 0,
  freeUnitsPerTotalAggregation: '1',
  perTransactionMinAmount: '1',
  packageSize: 12,
  rate: '5',
  graduatedRanges: [
    {
      flatAmount: '1',
      fromValue: 0,
      perUnitAmount: '1',
    },
    {
      flatAmount: '1',
      fromValue: 1,
      perUnitAmount: '1',
    },
  ],
  volumeRanges: [
    {
      flatAmount: '1',
      fromValue: 0,
      perUnitAmount: '1',
    },
    {
      flatAmount: '1',
      fromValue: 1,
      perUnitAmount: '1',
    },
  ],
  graduatedPercentageRanges: [
    {
      fromValue: 0,
      toValue: 1,
      rate: '0',
      flatAmount: '0',
    },
    {
      fromValue: 2,
      toValue: null,
      rate: '10',
      flatAmount: '1',
    },
  ],
  customProperties: JSON.stringify({
    ranges: [
      { from: 0, to: 100, thirdPart: '0.13', firstPart: '0.12' },
      { from: 101, to: 2000, thirdPart: '0.10', firstPart: '0.09' },
      { from: 2001, to: 5000, thirdPart: '0.08', firstPart: '0.07' },
      { from: 5001, to: null, thirdPart: '0.06', firstPart: '0.05' },
    ],
  }),
}

describe('serializeFixedChargeProperties', () => {
  // The full shape getPropertyShape seeds — most fields are usage-only and are
  // NOT valid on FixedChargePropertiesInput.
  const fullShape = {
    amount: '10',
    fixedAmount: '2',
    freeUnits: 5,
    freeUnitsPerEvents: 0,
    rate: '5',
    packageSize: 12,
    pricingGroupKeys: ['region'],
    graduatedRanges: [{ fromValue: 0, toValue: 1, flatAmount: '1', perUnitAmount: '2' }],
    volumeRanges: [{ fromValue: 0, toValue: 1, flatAmount: '3', perUnitAmount: '4' }],
  }

  describe('standard', () => {
    it('keeps only amount and prunes every usage-only field (regression)', () => {
      expect(
        serializeFixedChargeProperties(fullShape, FixedChargeChargeModelEnum.Standard),
      ).toStrictEqual({ amount: '10' })
    })

    it('returns amount: undefined when no amount is set', () => {
      expect(
        serializeFixedChargeProperties({ amount: '' }, FixedChargeChargeModelEnum.Standard),
      ).toStrictEqual({ amount: undefined })
    })

    it('handles null/undefined properties', () => {
      expect(
        serializeFixedChargeProperties(undefined, FixedChargeChargeModelEnum.Standard),
      ).toStrictEqual({ amount: undefined })
      expect(
        serializeFixedChargeProperties(null, FixedChargeChargeModelEnum.Standard),
      ).toStrictEqual({ amount: undefined })
    })
  })

  describe('graduated', () => {
    it('keeps only graduatedRanges (with scientific-notation + fromValue defaults)', () => {
      expect(
        serializeFixedChargeProperties(fullShape, FixedChargeChargeModelEnum.Graduated),
      ).toStrictEqual({
        graduatedRanges: [{ fromValue: 0, toValue: 1, flatAmount: '1', perUnitAmount: '2' }],
      })
    })

    it('defaults a missing flatAmount to "0"', () => {
      expect(
        serializeFixedChargeProperties(
          {
            graduatedRanges: [
              { fromValue: 0, toValue: 1, perUnitAmount: '1', flatAmount: undefined as never },
            ],
          },
          FixedChargeChargeModelEnum.Graduated,
        ),
      ).toStrictEqual({
        graduatedRanges: [{ fromValue: 0, toValue: 1, perUnitAmount: '1', flatAmount: '0' }],
      })
    })

    it('returns graduatedRanges: undefined when none are set', () => {
      expect(
        serializeFixedChargeProperties({ amount: '10' }, FixedChargeChargeModelEnum.Graduated),
      ).toStrictEqual({ graduatedRanges: undefined })
    })
  })

  describe('volume', () => {
    it('keeps only volumeRanges and prunes everything else', () => {
      expect(
        serializeFixedChargeProperties(fullShape, FixedChargeChargeModelEnum.Volume),
      ).toStrictEqual({
        volumeRanges: [{ fromValue: 0, toValue: 1, flatAmount: '3', perUnitAmount: '4' }],
      })
    })

    it('returns volumeRanges: undefined when none are set', () => {
      expect(
        serializeFixedChargeProperties({ amount: '10' }, FixedChargeChargeModelEnum.Volume),
      ).toStrictEqual({ volumeRanges: undefined })
    })
  })
})

describe('serializePlanInput()', () => {
  describe('a plan without charges', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        charges: [],
        fixedCharges: [],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        charges: [],
        fixedCharges: [],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with graduated charge', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Graduated,
            minAmountCents: 100.03,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: fullProperty,
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            minAmountCents: 10003,
            payInAdvance: false,
            chargeModel: 'graduated',
            appliedPricingUnit: undefined,
            filters: [],
            properties: {
              amount: '1',
              fixedAmount: '2',
              freeUnits: undefined,
              freeUnitsPerEvents: 0,
              freeUnitsPerTotalAggregation: '1',
              graduatedRanges: [
                {
                  flatAmount: '1',
                  fromValue: 0,
                  perUnitAmount: '1',
                },
                {
                  flatAmount: '1',
                  fromValue: 1,
                  perUnitAmount: '1',
                },
              ],
              graduatedPercentageRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              rate: '5',
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with graduated percentage charge', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            minAmountCents: 100.03,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: fullProperty,
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            minAmountCents: 10003,
            payInAdvance: false,
            chargeModel: 'graduated_percentage',
            appliedPricingUnit: undefined,
            filters: [],
            properties: {
              amount: '1',
              fixedAmount: '2',
              freeUnits: undefined,
              freeUnitsPerEvents: 0,
              freeUnitsPerTotalAggregation: '1',
              graduatedPercentageRanges: [
                {
                  fromValue: 0,
                  toValue: 1,
                  rate: '0',
                  flatAmount: '0',
                },
                {
                  fromValue: 2,
                  toValue: null,
                  rate: '10',
                  flatAmount: '1',
                },
              ],
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              rate: '5',
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with package charge', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Package,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: fullProperty,
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'package',
            appliedPricingUnit: undefined,
            filters: [],
            minAmountCents: undefined,
            payInAdvance: false,
            properties: {
              amount: '1',
              fixedAmount: '2',
              freeUnits: 1,
              freeUnitsPerEvents: 0,
              freeUnitsPerTotalAggregation: '1',
              graduatedRanges: undefined,
              graduatedPercentageRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              packageSize: 12,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              rate: '5',
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with percentage charge', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Percentage,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: fullProperty,
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'percentage',
            appliedPricingUnit: undefined,
            minAmountCents: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: undefined,
              fixedAmount: '2',
              freeUnits: undefined,
              freeUnitsPerEvents: undefined,
              freeUnitsPerTotalAggregation: '1',
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: '1',
              perTransactionMaxAmount: undefined,
              rate: '5',
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with standard charge', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: fullProperty,
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            appliedPricingUnit: undefined,
            minAmountCents: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: '1',
              fixedAmount: '2',
              freeUnits: undefined,
              freeUnitsPerEvents: 0,
              freeUnitsPerTotalAggregation: '1',
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              rate: '5',
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })

    it('formats correctly the pricingGroupKeys', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: { pricingGroupKeys: ['one', 'two'] },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            appliedPricingUnit: undefined,
            minAmountCents: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: undefined,
              freeUnits: undefined,
              graduatedRanges: undefined,
              pricingGroupKeys: ['one', 'two'],
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })

    it('formats correctly the presentationGroupKeys', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: {
              presentationGroupKeys: [
                { value: 'region', options: { displayInInvoice: 'true' as unknown as boolean } },
                { value: 'country', options: { displayInInvoice: 'false' as unknown as boolean } },
              ],
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            appliedPricingUnit: undefined,
            minAmountCents: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: undefined,
              freeUnits: undefined,
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: [
                { value: 'region', options: { displayInInvoice: true } },
                { value: 'country', options: { displayInInvoice: false } },
              ],
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })

    it('formates correctly the filters', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
              filters: [
                {
                  id: '11234',
                  key: 'key1',
                  values: ['value1'],
                },
                {
                  id: '21234',
                  key: 'key2',
                  values: ['value2'],
                },
              ],
            },
            properties: {},
            filters: [
              {
                properties: {},
                values: [
                  transformFilterObjectToString('parent_key'),
                  transformFilterObjectToString('key1', 'value1'),
                ],
              },
              {
                properties: {},
                values: [
                  transformFilterObjectToString('parent_key'),
                  transformFilterObjectToString('key2', 'value2'),
                ],
              },
            ],
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            minAmountCents: undefined,
            appliedPricingUnit: undefined,
            payInAdvance: false,
            properties: {
              amount: undefined,
              freeUnits: undefined,
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              volumeRanges: undefined,
              customProperties: undefined,
            },
            filters: [
              {
                invoiceDisplayName: null,
                properties: {
                  amount: undefined,
                  freeUnits: undefined,
                  graduatedPercentageRanges: undefined,
                  graduatedRanges: undefined,
                  pricingGroupKeys: undefined,
                  presentationGroupKeys: undefined,
                  packageSize: undefined,
                  perTransactionMaxAmount: undefined,
                  perTransactionMinAmount: undefined,
                  volumeRanges: undefined,
                  customProperties: undefined,
                },
                values: {
                  key1: ['value1'],
                  parent_key: [ALL_FILTER_VALUES],
                },
              },
              {
                invoiceDisplayName: null,
                properties: {
                  amount: undefined,
                  freeUnits: undefined,
                  graduatedPercentageRanges: undefined,
                  graduatedRanges: undefined,
                  pricingGroupKeys: undefined,
                  presentationGroupKeys: undefined,
                  packageSize: undefined,
                  perTransactionMaxAmount: undefined,
                  perTransactionMinAmount: undefined,
                  volumeRanges: undefined,
                  customProperties: undefined,
                },
                values: {
                  key2: ['value2'],
                  parent_key: [ALL_FILTER_VALUES],
                },
              },
            ],
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with volume charge', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Volume,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: fullProperty,
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'volume',
            appliedPricingUnit: undefined,
            minAmountCents: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: '1',
              fixedAmount: '2',
              freeUnits: undefined,
              freeUnitsPerEvents: 0,
              freeUnitsPerTotalAggregation: '1',
              graduatedRanges: undefined,
              graduatedPercentageRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              rate: '5',
              volumeRanges: [
                {
                  flatAmount: '1',
                  fromValue: 0,
                  perUnitAmount: '1',
                },
                {
                  flatAmount: '1',
                  fromValue: 1,
                  perUnitAmount: '1',
                },
              ],
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with custom charge', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Custom,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CustomAgg,
            },
            properties: fullProperty,
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'custom',
            appliedPricingUnit: undefined,
            minAmountCents: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: '1',
              fixedAmount: '2',
              freeUnits: undefined,
              freeUnitsPerEvents: 0,
              freeUnitsPerTotalAggregation: '1',
              graduatedRanges: undefined,
              graduatedPercentageRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              rate: '5',
              volumeRanges: undefined,
              customProperties:
                '{"ranges":[{"from":0,"to":100,"thirdPart":"0.13","firstPart":"0.12"},{"from":101,"to":2000,"thirdPart":"0.10","firstPart":"0.09"},{"from":2001,"to":5000,"thirdPart":"0.08","firstPart":"0.07"},{"from":5001,"to":null,"thirdPart":"0.06","firstPart":"0.05"}]}',
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with usage thresholds', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [
          {
            amountCents: '1',
            thresholdDisplayName: 'Threshold 1',
            recurring: false,
          },
          {
            amountCents: '2',
            recurring: false,
          },
        ],
        recurringUsageThreshold: {
          amountCents: '2',
          recurring: true,
        },
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        charges: [],
        fixedCharges: [],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [
          {
            amountCents: 100,
            thresholdDisplayName: 'Threshold 1',
            recurring: false,
          },
          {
            amountCents: 200,
            recurring: false,
            thresholdDisplayName: null,
          },
          {
            amountCents: 200,
            recurring: true,
            thresholdDisplayName: null,
          },
        ],
        entitlements: [],
      })
    })

    it('strips IDs and extra fields from non-recurring usage thresholds', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [
          {
            id: 'threshold-id-123',
            amountCents: '100',
            thresholdDisplayName: 'Non-recurring threshold',
            recurring: false,
            someExtraField: 'should-be-stripped',
          } as never,
        ],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      // Verify that the serialized threshold only contains the expected fields
      expect(plan.usageThresholds).toStrictEqual([
        {
          amountCents: 10000,
          thresholdDisplayName: 'Non-recurring threshold',
          recurring: false,
        },
      ])
      // Explicitly verify id is NOT present
      expect(plan.usageThresholds?.[0]).not.toHaveProperty('id')
      expect(plan.usageThresholds?.[0]).not.toHaveProperty('someExtraField')
    })

    it('strips IDs and extra fields from recurring usage threshold', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: {
          id: 'recurring-threshold-id-456',
          amountCents: '500',
          thresholdDisplayName: 'Recurring threshold',
          recurring: true,
          anotherExtraField: 'also-stripped',
        } as never,
        entitlements: [],
      })

      // Verify that the serialized threshold only contains the expected fields
      expect(plan.usageThresholds).toStrictEqual([
        {
          amountCents: 50000,
          thresholdDisplayName: 'Recurring threshold',
          recurring: true,
        },
      ])
      // Explicitly verify id is NOT present
      expect(plan.usageThresholds?.[0]).not.toHaveProperty('id')
      expect(plan.usageThresholds?.[0]).not.toHaveProperty('anotherExtraField')
    })

    it('strips IDs from both recurring and non-recurring thresholds when both are present', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [
          {
            id: 'non-rec-1',
            amountCents: '100',
            thresholdDisplayName: 'First',
            recurring: false,
          } as never,
          {
            id: 'non-rec-2',
            amountCents: '200',
            recurring: false,
          } as never,
        ],
        recurringUsageThreshold: {
          id: 'rec-1',
          amountCents: '300',
          thresholdDisplayName: 'Recurring',
          recurring: true,
        } as never,
        entitlements: [],
      })

      expect(plan.usageThresholds).toHaveLength(3)

      // Verify none of the thresholds have IDs
      plan.usageThresholds?.forEach((threshold) => {
        expect(threshold).not.toHaveProperty('id')
        expect(Object.keys(threshold)).toEqual(
          expect.arrayContaining(['amountCents', 'thresholdDisplayName', 'recurring']),
        )
        expect(Object.keys(threshold)).toHaveLength(3)
      })
    })
  })

  describe('a plan with appliedPricingUnit', () => {
    it('returns plan correctly serialized when the appliedPricingUnit is not the default currency', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            appliedPricingUnit: {
              code: 'CR',
              conversionRate: '1.2',
              type: LocalPricingUnitType.Custom,
              shortName: 'CR',
            },
            properties: {},
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            minAmountCents: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: undefined,
              freeUnits: undefined,
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
            appliedPricingUnit: {
              code: 'CR',
              conversionRate: 1.2,
            },
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })

    it('returns plan correctly serialized when the appliedPricingUnit is the default currency', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            appliedPricingUnit: {
              code: CurrencyEnum.Eur,
              shortName: CurrencyEnum.Eur,
              conversionRate: '1',
              type: LocalPricingUnitType.Fiat,
            },
            properties: {},
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            minAmountCents: undefined,
            appliedPricingUnit: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: undefined,
              freeUnits: undefined,
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with entitlements', () => {
    it('returns plan correctly serialized', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [
          {
            featureName: 'Feature 1',
            featureCode: 'feature-1',
            privileges: [
              {
                id: '4567',
                privilegeCode: 'privilege-1',
                privilegeName: 'Privilege 1',
                valueType: PrivilegeValueTypeEnum.Boolean,
                value: 'true',
              },
            ],
          },
        ],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [],
        code: 'my-plan',
        entitlements: [
          {
            featureId: undefined,
            featureName: undefined,
            featureCode: 'feature-1',
            privileges: [
              {
                id: undefined,
                config: undefined,
                privilegeCode: 'privilege-1',
                privilegeName: undefined,
                value: 'true',
                valueType: undefined,
              },
            ],
          },
        ],
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        taxCodes: [],
        trialPeriod: 1,
        usageThresholds: [],
      })
    })
  })

  describe('a plan with minimum commitment', () => {
    it('contains minAmountCents if defined on a charge in arrears', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            minAmountCents: 100,
            payInAdvance: false,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: {},
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            minAmountCents: 10000,
            appliedPricingUnit: undefined,
            payInAdvance: false,
            filters: [],
            properties: {
              amount: undefined,
              freeUnits: undefined,
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })

    it('does not contain minAmountCents if defined on a charge in advance', () => {
      const plan = serializePlanInput({
        amountCents: '1',
        amountCurrency: CurrencyEnum.Eur,
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            minAmountCents: 100,
            payInAdvance: true,
            billableMetric: {
              id: '1234',
              name: 'simpleBM',
              code: 'simple-bm',
              recurring: false,
              aggregationType: AggregationTypeEnum.CountAgg,
            },
            properties: {},
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: PlanInterval.Monthly,
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        nonRecurringUsageThresholds: [],
        recurringUsageThreshold: undefined,
        entitlements: [],
      })

      expect(plan).toStrictEqual({
        amountCents: 100,
        amountCurrency: 'EUR',
        billChargesMonthly: true,
        fixedCharges: [],
        charges: [
          {
            billableMetricId: '1234',
            chargeModel: 'standard',
            minAmountCents: undefined,
            appliedPricingUnit: undefined,
            payInAdvance: true,
            filters: [],
            properties: {
              amount: undefined,
              freeUnits: undefined,
              graduatedRanges: undefined,
              pricingGroupKeys: undefined,
              presentationGroupKeys: undefined,
              graduatedPercentageRanges: undefined,
              packageSize: undefined,
              perTransactionMinAmount: undefined,
              perTransactionMaxAmount: undefined,
              volumeRanges: undefined,
              customProperties: undefined,
            },
            taxCodes: [],
          },
        ],
        code: 'my-plan',
        interval: 'monthly',
        minimumCommitment: {},
        name: 'My plan',
        payInAdvance: true,
        trialPeriod: 1,
        taxCodes: [],
        usageThresholds: [],
        entitlements: [],
      })
    })
  })

  describe('a plan with fixedCharges', () => {
    describe('standard fixed charge', () => {
      it('returns plan correctly serialized', () => {
        const plan = serializePlanInput({
          amountCents: '1',
          amountCurrency: CurrencyEnum.Eur,
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: FixedChargeChargeModelEnum.Standard,
              addOn: {
                id: '5678',
                name: 'simpleAddOn',
                code: 'simple-addon',
              },
              properties: fullProperty,
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: PlanInterval.Monthly,
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          nonRecurringUsageThresholds: [],
          recurringUsageThreshold: undefined,
          entitlements: [],
        })

        expect(plan).toStrictEqual({
          amountCents: 100,
          amountCurrency: 'EUR',
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: 'standard',
              addOnId: '5678',
              addon: undefined,
              taxes: undefined,
              // Only amount is valid for a standard FixedChargePropertiesInput;
              // usage-only fields must not leak through.
              properties: {
                amount: '1',
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: 'monthly',
          minimumCommitment: {},
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          usageThresholds: [],
          entitlements: [],
        })
      })
    })

    describe('volume fixed charge', () => {
      it('returns plan correctly serialized', () => {
        const plan = serializePlanInput({
          amountCents: '1',
          amountCurrency: CurrencyEnum.Eur,
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: FixedChargeChargeModelEnum.Volume,
              addOn: {
                id: '5678',
                name: 'simpleAddOn',
                code: 'simple-addon',
              },
              properties: fullProperty,
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: PlanInterval.Monthly,
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          nonRecurringUsageThresholds: [],
          recurringUsageThreshold: undefined,
          entitlements: [],
        })

        expect(plan).toStrictEqual({
          amountCents: 100,
          amountCurrency: 'EUR',
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: 'volume',
              addOnId: '5678',
              addon: undefined,
              taxes: undefined,
              // Only volumeRanges is valid for a volume FixedChargePropertiesInput.
              properties: {
                volumeRanges: [
                  {
                    flatAmount: '1',
                    fromValue: 0,
                    perUnitAmount: '1',
                  },
                  {
                    flatAmount: '1',
                    fromValue: 1,
                    perUnitAmount: '1',
                  },
                ],
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: 'monthly',
          minimumCommitment: {},
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          usageThresholds: [],
          entitlements: [],
        })
      })
    })

    describe('fixed charge with units', () => {
      it('returns plan correctly serialized with units', () => {
        const plan = serializePlanInput({
          amountCents: '1',
          amountCurrency: CurrencyEnum.Eur,
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: FixedChargeChargeModelEnum.Standard,
              addOn: {
                id: '5678',
                name: 'simpleAddOn',
                code: 'simple-addon',
              },
              units: '10.123456',
              properties: {
                amount: '5',
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: PlanInterval.Monthly,
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          nonRecurringUsageThresholds: [],
          recurringUsageThreshold: undefined,
          entitlements: [],
        })

        expect(plan).toStrictEqual({
          amountCents: 100,
          amountCurrency: 'EUR',
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: 'standard',
              addOnId: '5678',
              units: '10.123456',
              addon: undefined,
              taxes: undefined,
              properties: {
                amount: '5',
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: 'monthly',
          minimumCommitment: {},
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          usageThresholds: [],
          entitlements: [],
        })
      })
    })

    describe('graduated fixed charge', () => {
      it('returns plan correctly serialized with flatAmount defaulted to 0', () => {
        const plan = serializePlanInput({
          amountCents: '1',
          amountCurrency: CurrencyEnum.Eur,
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: FixedChargeChargeModelEnum.Graduated,
              addOn: {
                id: '5678',
                name: 'simpleAddOn',
                code: 'simple-addon',
              },
              properties: {
                graduatedRanges: [
                  {
                    fromValue: 0,
                    toValue: 1,
                    perUnitAmount: '1',
                    flatAmount: undefined as unknown as string,
                  },
                  {
                    fromValue: 2,
                    toValue: null,
                    perUnitAmount: '1',
                    flatAmount: undefined as unknown as string,
                  },
                ],
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: PlanInterval.Monthly,
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          nonRecurringUsageThresholds: [],
          recurringUsageThreshold: undefined,
          entitlements: [],
        })

        expect(plan).toStrictEqual({
          amountCents: 100,
          amountCurrency: 'EUR',
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: 'graduated',
              addOnId: '5678',
              addon: undefined,
              taxes: undefined,
              properties: {
                graduatedRanges: [
                  {
                    flatAmount: '0',
                    fromValue: 0,
                    perUnitAmount: '1',
                    toValue: 1,
                  },
                  {
                    flatAmount: '0',
                    fromValue: 2,
                    perUnitAmount: '1',
                    toValue: null,
                  },
                ],
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: 'monthly',
          minimumCommitment: {},
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          usageThresholds: [],
          entitlements: [],
        })
      })

      it('returns plan correctly serialized with provided flatAmount values', () => {
        const plan = serializePlanInput({
          amountCents: '1',
          amountCurrency: CurrencyEnum.Eur,
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: FixedChargeChargeModelEnum.Graduated,
              addOn: {
                id: '5678',
                name: 'simpleAddOn',
                code: 'simple-addon',
              },
              properties: {
                graduatedRanges: [
                  {
                    fromValue: 0,
                    toValue: 1,
                    perUnitAmount: '5',
                    flatAmount: '10',
                  },
                  {
                    fromValue: 2,
                    toValue: null,
                    perUnitAmount: '3',
                    flatAmount: '7',
                  },
                ],
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: PlanInterval.Monthly,
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          nonRecurringUsageThresholds: [],
          recurringUsageThreshold: undefined,
          entitlements: [],
        })

        expect(plan).toStrictEqual({
          amountCents: 100,
          amountCurrency: 'EUR',
          billChargesMonthly: true,
          charges: [],
          fixedCharges: [
            {
              chargeModel: 'graduated',
              addOnId: '5678',
              addon: undefined,
              taxes: undefined,
              properties: {
                graduatedRanges: [
                  {
                    flatAmount: '10',
                    fromValue: 0,
                    perUnitAmount: '5',
                    toValue: 1,
                  },
                  {
                    flatAmount: '7',
                    fromValue: 2,
                    perUnitAmount: '3',
                    toValue: null,
                  },
                ],
              },
              taxCodes: [],
            },
          ],
          code: 'my-plan',
          interval: 'monthly',
          minimumCommitment: {},
          name: 'My plan',
          payInAdvance: true,
          trialPeriod: 1,
          taxCodes: [],
          usageThresholds: [],
          entitlements: [],
        })
      })
    })
  })
})

describe('serializeProperties — presentationGroupKeys', () => {
  it('converts displayInInvoice "true"/"false" strings to booleans', () => {
    const result = serializeProperties(
      {
        amount: '1',
        presentationGroupKeys: [
          { value: 'region', options: { displayInInvoice: 'true' } },
          { value: 'agent', options: { displayInInvoice: 'false' } },
        ],
      } as unknown as Parameters<typeof serializeProperties>[0],
      ChargeModelEnum.Standard,
    )

    expect(result.presentationGroupKeys).toEqual([
      { value: 'region', options: { displayInInvoice: true } },
      { value: 'agent', options: { displayInInvoice: false } },
    ])
  })

  it('maps an unknown displayInInvoice value to undefined', () => {
    const result = serializeProperties(
      {
        amount: '1',
        presentationGroupKeys: [{ value: 'region', options: { displayInInvoice: 'maybe' } }],
      } as unknown as Parameters<typeof serializeProperties>[0],
      ChargeModelEnum.Standard,
    )

    expect(result.presentationGroupKeys?.[0].options.displayInInvoice).toBeUndefined()
  })

  it('returns undefined when there are no presentationGroupKeys', () => {
    const result = serializeProperties(
      { amount: '1', presentationGroupKeys: [] } as unknown as Parameters<
        typeof serializeProperties
      >[0],
      ChargeModelEnum.Standard,
    )

    expect(result.presentationGroupKeys).toBeUndefined()
  })

  it('strips presentationGroupKeys for the Custom charge model', () => {
    const result = serializeProperties(
      {
        presentationGroupKeys: [{ value: 'region', options: { displayInInvoice: 'true' } }],
      } as unknown as Parameters<typeof serializeProperties>[0],
      ChargeModelEnum.Custom,
    )

    expect(result.presentationGroupKeys).toBeUndefined()
  })
})
