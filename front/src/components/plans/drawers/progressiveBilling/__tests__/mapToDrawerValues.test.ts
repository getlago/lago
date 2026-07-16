import { CurrencyEnum } from '~/generated/graphql'

import {
  mapFormThresholdsToDrawerValues,
  mapPlanThresholdsToDrawerValues,
} from '../mapToDrawerValues'

describe('mapPlanThresholdsToDrawerValues', () => {
  it('returns empty payload when usageThresholds is null', () => {
    expect(mapPlanThresholdsToDrawerValues(null, CurrencyEnum.Usd)).toEqual({
      nonRecurringUsageThresholds: [],
      recurringUsageThreshold: undefined,
    })
  })

  it('returns empty payload when usageThresholds is undefined', () => {
    expect(mapPlanThresholdsToDrawerValues(undefined, CurrencyEnum.Usd)).toEqual({
      nonRecurringUsageThresholds: [],
      recurringUsageThreshold: undefined,
    })
  })

  it('maps non-recurring thresholds and deserializes amounts to major units', () => {
    const result = mapPlanThresholdsToDrawerValues(
      [
        { amountCents: 1000, recurring: false, thresholdDisplayName: 'First' },
        { amountCents: '5000', recurring: false, thresholdDisplayName: null },
      ],
      CurrencyEnum.Usd,
    )

    expect(result.nonRecurringUsageThresholds).toEqual([
      { amountCents: '10', thresholdDisplayName: 'First', recurring: false },
      { amountCents: '50', thresholdDisplayName: undefined, recurring: false },
    ])
    expect(result.recurringUsageThreshold).toBeUndefined()
  })

  it('maps single recurring threshold separately', () => {
    const result = mapPlanThresholdsToDrawerValues(
      [{ amountCents: 7500, recurring: true, thresholdDisplayName: 'Recurring' }],
      CurrencyEnum.Usd,
    )

    expect(result.nonRecurringUsageThresholds).toEqual([])
    expect(result.recurringUsageThreshold).toEqual({
      amountCents: '75',
      thresholdDisplayName: 'Recurring',
      recurring: true,
    })
  })

  it('maps mixed recurring + non-recurring thresholds', () => {
    const result = mapPlanThresholdsToDrawerValues(
      [
        { amountCents: 1000, recurring: false, thresholdDisplayName: 'A' },
        { amountCents: 3000, recurring: true, thresholdDisplayName: 'R' },
        { amountCents: 2000, recurring: false, thresholdDisplayName: 'B' },
      ],
      CurrencyEnum.Usd,
    )

    expect(result.nonRecurringUsageThresholds).toHaveLength(2)
    expect(result.nonRecurringUsageThresholds[0].thresholdDisplayName).toBe('A')
    expect(result.nonRecurringUsageThresholds[1].thresholdDisplayName).toBe('B')
    expect(result.recurringUsageThreshold?.thresholdDisplayName).toBe('R')
  })
})

describe('mapFormThresholdsToDrawerValues', () => {
  it('returns empty payload when both inputs are null/undefined', () => {
    expect(mapFormThresholdsToDrawerValues(null, null)).toEqual({
      nonRecurringUsageThresholds: [],
      recurringUsageThreshold: undefined,
    })
  })

  it('passes amountCents through as string without deserialize', () => {
    const result = mapFormThresholdsToDrawerValues(
      [{ amountCents: '12.5', thresholdDisplayName: 'A' }],
      { amountCents: 99, thresholdDisplayName: 'R' },
    )

    expect(result.nonRecurringUsageThresholds).toEqual([
      { amountCents: '12.5', thresholdDisplayName: 'A', recurring: false },
    ])
    expect(result.recurringUsageThreshold).toEqual({
      amountCents: '99',
      thresholdDisplayName: 'R',
      recurring: true,
    })
  })

  it('converts null displayName to undefined', () => {
    const result = mapFormThresholdsToDrawerValues(
      [{ amountCents: '1', thresholdDisplayName: null }],
      undefined,
    )

    expect(result.nonRecurringUsageThresholds[0].thresholdDisplayName).toBeUndefined()
  })
})
