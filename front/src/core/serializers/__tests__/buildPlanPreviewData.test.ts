// src/core/serializers/__tests__/buildPlanPreviewData.test.ts
import { buildPlanPreviewData } from '~/core/serializers/buildPlanPreviewData'
import type { PlanFormInput } from '~/core/serializers/serializeQuotePlanBillingItems'
import { ChargeModelEnum, FixedChargeChargeModelEnum, PlanInterval } from '~/generated/graphql'

const baseForm = (over: Partial<PlanFormInput> = {}): PlanFormInput =>
  ({
    interval: PlanInterval.Monthly,
    amountCents: '0',
    amountCurrency: 'USD',
    payInAdvance: true,
    charges: [],
    fixedCharges: [],
    minimumCommitment: undefined,
    nonRecurringUsageThresholds: [],
    entitlements: [],
    name: 'My Plan',
    code: 'plan_code',
    description: '',
    taxCodes: [],
    taxes: [],
    ...over,
  }) as unknown as PlanFormInput

describe('buildPlanPreviewData', () => {
  it('returns empty rows for a legacy plan (formValues null)', () => {
    expect(buildPlanPreviewData(null)).toEqual({ rows: [] })
  })

  it('renders a subscription-fee main row when amountCents > 0 (advance → beginningOfPeriod)', () => {
    const data = buildPlanPreviewData(
      baseForm({ amountCents: '13050', payInAdvance: true, interval: PlanInterval.Monthly }),
    )

    expect(data.rows[0]).toEqual({
      kind: 'main',
      rowType: 'subscriptionFee',
      name: undefined, // no invoiceDisplayName → component shows translated "Subscription fee"
      description: undefined,
      interval: PlanInterval.Monthly,
      timing: 'beginningOfPeriod',
      units: { type: 'count', value: 1 },
      // amountCents is already in display units (major) by the time it reaches the
      // builder — the form deserializes on load and the quote serializer is passthrough —
      // so it is rendered directly, never re-divided by 100.
      price: { type: 'displayAmount', amount: '13050' },
    })
  })

  it('omits the subscription-fee row when amountCents is 0', () => {
    const data = buildPlanPreviewData(baseForm({ amountCents: '0' }))

    expect(
      data.rows.find((r) => r.kind === 'main' && r.rowType === 'subscriptionFee'),
    ).toBeUndefined()
  })

  it('renders a fixed charge main row (units + amount, arrears → endOfPeriod)', () => {
    const data = buildPlanPreviewData(
      baseForm({
        amountCents: '0',
        interval: PlanInterval.Yearly,
        fixedCharges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            payInAdvance: false,
            units: '5',
            invoiceDisplayName: 'Seats',
            properties: { amount: '200.00' },
            addOn: { name: 'Seat add-on', code: 'seat' },
          },
        ] as unknown as PlanFormInput['fixedCharges'],
      }),
    )
    const row = data.rows.find((r) => r.kind === 'main' && r.rowType === 'fixedCharge')

    expect(row).toMatchObject({
      kind: 'main',
      rowType: 'fixedCharge',
      name: 'Seats',
      interval: PlanInterval.Yearly,
      timing: 'endOfPeriod',
      units: { type: 'count', value: 5 },
      price: { type: 'displayAmount', amount: '200.00' },
    })
  })

  it('renders a standard usage charge as a main usage row + a single "Usage / perUnit" detail row', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            payInAdvance: false,
            invoiceDisplayName: 'API calls',
            billableMetric: { name: 'API calls', code: 'api' },
            properties: { amount: '1.20' },
            filters: [],
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )
    const main = data.rows.find((r) => r.kind === 'main' && r.rowType === 'usageCharge')

    expect(main).toMatchObject({
      kind: 'main',
      rowType: 'usageCharge',
      name: 'API calls',
      timing: 'endOfPeriod',
      units: { type: 'usageBased' },
      price: { type: 'variesWithUsage' },
    })
    expect(data.rows).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelUsage' },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '1.20' },
    })
  })

  it('renders a plan minimum commitment as its own main row (units 1 + amount)', () => {
    const data = buildPlanPreviewData(
      baseForm({
        minimumCommitment: {
          amountCents: '1000.00',
          invoiceDisplayName: undefined,
        } as unknown as PlanFormInput['minimumCommitment'],
      }),
    )
    const row = data.rows.find((r) => r.kind === 'main' && r.rowType === 'minimumCommitment')

    expect(row).toMatchObject({
      kind: 'main',
      rowType: 'minimumCommitment',
      units: { type: 'count', value: 1 },
      price: { type: 'displayAmount', amount: '1000.00' },
    })
  })

  it('renders graduated ranges: per-unit row per tier, flat-fee row only when present', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Graduated,
            payInAdvance: false,
            invoiceDisplayName: 'Tiered',
            billableMetric: { name: 'Tiered', code: 't' },
            filters: [],
            properties: {
              graduatedRanges: [
                { fromValue: 0, toValue: 10, perUnitAmount: '0.00', flatAmount: '10.00' },
                { fromValue: 11, toValue: 100, perUnitAmount: '0.10', flatAmount: '0' },
                { fromValue: 101, toValue: null, perUnitAmount: '0.05', flatAmount: '0' },
              ],
            },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )
    const details = data.rows.filter((r) => r.kind === 'detail')

    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'tierRange', from: 0, to: 10 },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '0.00' },
    })
    // flat fee shown for tier 1 (10.00) but not tiers 2/3 (0)
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'flatFeeForTier', from: 0, to: 10 },
      qualifier: { type: 'flatFee' },
      value: { type: 'displayAmount', amount: '10.00' },
    })
    expect(details.filter((d) => d.label.type === 'flatFeeForTier')).toHaveLength(1)
    // last tier is open-ended
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'tierRange', from: 101, to: undefined },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '0.05' },
    })
  })

  it('renders volume ranges identically to graduated (perUnit + optional flat fee)', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Volume,
            payInAdvance: false,
            invoiceDisplayName: 'Vol',
            billableMetric: { name: 'Vol', code: 'v' },
            filters: [],
            properties: {
              volumeRanges: [
                { fromValue: 0, toValue: 10, perUnitAmount: '0.10', flatAmount: '10.00' },
              ],
            },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )
    const details = data.rows.filter((r) => r.kind === 'detail')

    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'tierRange', from: 0, to: 10 },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '0.10' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'flatFeeForTier', from: 0, to: 10 },
      qualifier: { type: 'flatFee' },
      value: { type: 'displayAmount', amount: '10.00' },
    })
  })

  it('package: optional free-units row + Package/perPackage row', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Package,
            payInAdvance: false,
            billableMetric: { name: 'Pkg', code: 'p' },
            filters: [],
            properties: { amount: '10.00', packageSize: 1000, freeUnits: 10 },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )
    const details = data.rows.filter((r) => r.kind === 'detail')

    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelFreeUnits' },
      qualifier: { type: 'firstNUnits', count: 10 },
      value: { type: 'displayAmount', amount: '0' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelPackage' },
      qualifier: { type: 'perPackage', size: 1000 },
      value: { type: 'displayAmount', amount: '10.00' },
    })
  })

  it('package: omits free-units row when freeUnits is 0', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Package,
            payInAdvance: false,
            billableMetric: { name: 'Pkg', code: 'p' },
            filters: [],
            properties: { amount: '10.00', packageSize: 1000, freeUnits: 0 },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )

    expect(
      data.rows.filter(
        (r) => r.kind === 'detail' && r.label.type === 'text' && r.label.key === 'labelFreeUnits',
      ),
    ).toHaveLength(0)
  })

  it('percentage: always shows transaction cost; optional free/fixed/min/max only when present', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Percentage,
            payInAdvance: false,
            billableMetric: { name: 'Pct', code: 'pct' },
            filters: [],
            properties: {
              rate: '1.50',
              fixedAmount: '0.10',
              freeUnitsPerTotalAggregation: '1000',
              freeUnitsPerEvents: '10',
              perTransactionMinAmount: '1.00',
              perTransactionMaxAmount: '4.00',
            },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )
    const details = data.rows.filter((r) => r.kind === 'detail')
    // mandatory transaction cost

    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelTransactionCost' },
      qualifier: { type: 'percentOfVolume' },
      value: { type: 'percentage', rate: '1.50' },
    })
    // optional rows
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelFreeVolume' },
      qualifier: { type: 'firstNUnits', count: 1000 },
      value: { type: 'percentage', rate: '0' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelFreeTransactions' },
      qualifier: { type: 'firstNTransactions', count: 10 },
      value: { type: 'percentage', rate: '0' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelFixedFee' },
      qualifier: { type: 'perTransaction' },
      value: { type: 'displayAmount', amount: '0.10' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelMinimum' },
      qualifier: { type: 'perTransaction' },
      value: { type: 'displayAmount', amount: '1.00' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelMaximum' },
      qualifier: { type: 'perTransaction' },
      value: { type: 'displayAmount', amount: '4.00' },
    })
  })

  it('percentage: only the transaction-cost row when no optional fields', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Percentage,
            payInAdvance: false,
            billableMetric: { name: 'Pct', code: 'pct' },
            filters: [],
            properties: { rate: '1.50' },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )

    expect(data.rows.filter((r) => r.kind === 'detail')).toHaveLength(1)
  })

  it('graduated_percentage: tier rows use percentOfVolume + percentage value (+ optional flat fee)', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            payInAdvance: false,
            billableMetric: { name: 'GP', code: 'gp' },
            filters: [],
            properties: {
              graduatedPercentageRanges: [
                { fromValue: 0, toValue: 10, rate: '0', flatAmount: '10.00' },
                { fromValue: 11, toValue: null, rate: '1.50', flatAmount: '0' },
              ],
            },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )
    const details = data.rows.filter((r) => r.kind === 'detail')

    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'tierRange', from: 0, to: 10 },
      qualifier: { type: 'percentOfVolume' },
      value: { type: 'percentage', rate: '0' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'flatFeeForTier', from: 0, to: 10 },
      qualifier: { type: 'flatFee' },
      value: { type: 'displayAmount', amount: '10.00' },
    })
  })

  it('appends a "Minimum spending / Commitment" detail row when a usage charge has minAmountCents', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            payInAdvance: false,
            billableMetric: { name: 'Usage', code: 'u' },
            filters: [],
            properties: { amount: '1.20' },
            minAmountCents: '100.00',
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )

    expect(data.rows).toContainEqual({
      kind: 'detail',
      label: { type: 'text', key: 'labelMinimumSpending' },
      qualifier: { type: 'commitment' },
      value: { type: 'displayAmount', amount: '100.00' },
    })
  })

  it('graduated fixed charge: main row with count+empty-price, tier rows below', () => {
    const data = buildPlanPreviewData(
      baseForm({
        amountCents: '0',
        interval: PlanInterval.Monthly,
        fixedCharges: [
          {
            chargeModel: FixedChargeChargeModelEnum.Graduated,
            payInAdvance: false,
            units: '5',
            invoiceDisplayName: 'Graduated FC',
            properties: {
              graduatedRanges: [
                { fromValue: 0, toValue: 10, perUnitAmount: '0.10', flatAmount: '10.00' },
                { fromValue: 11, toValue: null, perUnitAmount: '0.05', flatAmount: '0' },
              ],
            },
          },
        ] as unknown as PlanFormInput['fixedCharges'],
      }),
    )
    const mainRow = data.rows.find((r) => r.kind === 'main' && r.rowType === 'fixedCharge')

    expect(mainRow).toMatchObject({
      kind: 'main',
      rowType: 'fixedCharge',
      units: { type: 'count', value: 5 },
      price: { type: 'empty' },
    })

    const details = data.rows.filter((r) => r.kind === 'detail')

    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'tierRange', from: 0, to: 10 },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '0.10' },
    })
    // flat fee present for tier 1 (10.00), absent for tier 2 (0)
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'flatFeeForTier', from: 0, to: 10 },
      qualifier: { type: 'flatFee' },
      value: { type: 'displayAmount', amount: '10.00' },
    })
    expect(details.filter((d) => d.label.type === 'flatFeeForTier')).toHaveLength(1)
    // open-ended top tier (toValue null → to: undefined)
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'tierRange', from: 11, to: undefined },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '0.05' },
    })
  })

  it('volume fixed charge: main row with count+empty-price, tier rows below', () => {
    const data = buildPlanPreviewData(
      baseForm({
        amountCents: '0',
        interval: PlanInterval.Monthly,
        fixedCharges: [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            payInAdvance: false,
            units: '3',
            invoiceDisplayName: 'Volume FC',
            properties: {
              volumeRanges: [
                { fromValue: 0, toValue: 10, perUnitAmount: '0.20', flatAmount: '5.00' },
              ],
            },
          },
        ] as unknown as PlanFormInput['fixedCharges'],
      }),
    )
    const mainRow = data.rows.find((r) => r.kind === 'main' && r.rowType === 'fixedCharge')

    expect(mainRow).toMatchObject({
      kind: 'main',
      rowType: 'fixedCharge',
      units: { type: 'count', value: 3 },
      price: { type: 'empty' },
    })

    const details = data.rows.filter((r) => r.kind === 'detail')

    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'tierRange', from: 0, to: 10 },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '0.20' },
    })
    expect(details).toContainEqual({
      kind: 'detail',
      label: { type: 'flatFeeForTier', from: 0, to: 10 },
      qualifier: { type: 'flatFee' },
      value: { type: 'displayAmount', amount: '5.00' },
    })
  })

  it('dynamic and custom: main usage row only, no detail rows', () => {
    for (const model of [ChargeModelEnum.Dynamic, ChargeModelEnum.Custom]) {
      const data = buildPlanPreviewData(
        baseForm({
          charges: [
            {
              chargeModel: model,
              payInAdvance: false,
              billableMetric: { name: 'X', code: 'x' },
              filters: [],
              properties: model === ChargeModelEnum.Custom ? { customProperties: {} } : {},
            },
          ] as unknown as PlanFormInput['charges'],
        }),
      )

      expect(data.rows.filter((r) => r.kind === 'detail')).toHaveLength(0)
      expect(
        data.rows.filter((r) => r.kind === 'main' && r.rowType === 'usageCharge'),
      ).toHaveLength(1)
    }
  })

  it('renders a percentage charge main row with onTransaction timing regardless of payInAdvance', () => {
    for (const payInAdvance of [true, false]) {
      const data = buildPlanPreviewData(
        baseForm({
          charges: [
            {
              chargeModel: ChargeModelEnum.Percentage,
              payInAdvance,
              billableMetric: { name: 'Pct', code: 'pct' },
              filters: [],
              properties: { rate: '1.50' },
            },
          ] as unknown as PlanFormInput['charges'],
        }),
      )
      const main = data.rows.find((r) => r.kind === 'main' && r.rowType === 'usageCharge')

      expect(main).toMatchObject({ timing: 'onTransaction' })
    }
  })

  it('keeps non-percentage arrears usage charges on endOfPeriod timing', () => {
    const data = buildPlanPreviewData(
      baseForm({
        charges: [
          {
            chargeModel: ChargeModelEnum.Standard,
            payInAdvance: false,
            billableMetric: { name: 'Std', code: 'std' },
            filters: [],
            properties: { amount: '1.20' },
          },
        ] as unknown as PlanFormInput['charges'],
      }),
    )
    const main = data.rows.find((r) => r.kind === 'main' && r.rowType === 'usageCharge')

    expect(main).toMatchObject({ timing: 'endOfPeriod' })
  })
})
