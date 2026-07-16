import { CurrencyEnum, PlanInterval } from '~/generated/graphql'

import { buildPlanSettingsValues, formatAnyToValueForChargeFormArrays } from '../utils'

describe('formattedToValue', () => {
  describe('GIVEN toValue is null', () => {
    it('THEN returns null', () => {
      expect(formatAnyToValueForChargeFormArrays(null, 10)).toBeNull()
    })
  })

  describe('GIVEN toValue is less than fromValue', () => {
    it('THEN returns fromValue + 1', () => {
      expect(formatAnyToValueForChargeFormArrays(5, 10)).toBe(11)
    })

    it('THEN handles string toValue', () => {
      expect(formatAnyToValueForChargeFormArrays('5', 10)).toBe(11)
    })
  })

  describe('GIVEN toValue equals fromValue', () => {
    it('THEN returns fromValue + 1', () => {
      expect(formatAnyToValueForChargeFormArrays(10, 10)).toBe(11)
    })

    it('THEN handles string toValue', () => {
      expect(formatAnyToValueForChargeFormArrays('10', 10)).toBe(11)
    })
  })

  describe('GIVEN toValue is greater than fromValue', () => {
    it('THEN returns toValue as a number', () => {
      expect(formatAnyToValueForChargeFormArrays(15, 10)).toBe(15)
    })

    it('THEN handles string toValue', () => {
      expect(formatAnyToValueForChargeFormArrays('15', 10)).toBe(15)
    })
  })

  describe('GIVEN edge cases', () => {
    it('THEN handles undefined toValue', () => {
      expect(formatAnyToValueForChargeFormArrays(undefined, 10)).toBe(11)
    })

    it('THEN handles empty string as toValue', () => {
      expect(formatAnyToValueForChargeFormArrays('', 10)).toBe(11)
    })

    it('THEN handles 0 as toValue when fromValue is 0', () => {
      expect(formatAnyToValueForChargeFormArrays(0, 0)).toBe(1)
    })

    it('THEN handles 0 as toValue when fromValue is greater', () => {
      expect(formatAnyToValueForChargeFormArrays(0, 5)).toBe(6)
    })

    it('THEN handles negative numbers', () => {
      expect(formatAnyToValueForChargeFormArrays(-5, 10)).toBe(11)
    })

    it('THEN handles negative fromValue', () => {
      expect(formatAnyToValueForChargeFormArrays(5, -10)).toBe(5)
    })

    it('THEN handles decimal numbers', () => {
      expect(formatAnyToValueForChargeFormArrays(10.5, 10)).toBe(10.5)
    })

    it('THEN handles decimal numbers when toValue <= fromValue', () => {
      expect(formatAnyToValueForChargeFormArrays(10.5, 11)).toBe(12)
    })

    it('THEN handles string fromValue', () => {
      expect(formatAnyToValueForChargeFormArrays(5, '10')).toBe(11)
    })
  })
})

describe('buildPlanSettingsValues', () => {
  const plan = {
    name: 'Pro',
    code: 'pro',
    description: 'A pro plan',
    interval: PlanInterval.Yearly,
    amountCurrency: CurrencyEnum.Eur,
    billChargesMonthly: true,
    billFixedChargesMonthly: false,
    taxes: [{ id: 't1', code: 'vat', name: 'VAT', rate: 20 }],
    fixedCharges: [{ id: 'fc1' }, { id: 'fc2' }],
    charges: [{ id: 'c1' }],
  }

  it('maps each plan-settings field 1:1 from the plan', () => {
    const values = buildPlanSettingsValues(plan)

    expect(values.name).toBe('Pro')
    expect(values.code).toBe('pro')
    expect(values.description).toBe('A pro plan')
    expect(values.interval).toBe(PlanInterval.Yearly)
    expect(values.amountCurrency).toBe(CurrencyEnum.Eur)
    expect(values.billChargesMonthly).toBe(true)
    expect(values.billFixedChargesMonthly).toBe(false)
    expect(values.taxes).toEqual(plan.taxes)
  })

  it('preserves fixedCharges/charges presence (length-only)', () => {
    const values = buildPlanSettingsValues(plan)

    expect(values.fixedCharges).toHaveLength(2)
    expect(values.charges).toHaveLength(1)
  })

  it('defaults to empty values when fields are missing', () => {
    const values = buildPlanSettingsValues({
      name: 'Free',
      code: 'free',
      interval: PlanInterval.Monthly,
      amountCurrency: CurrencyEnum.Usd,
    })

    expect(values.description).toBe('')
    expect(values.billChargesMonthly).toBe(false)
    expect(values.billFixedChargesMonthly).toBe(false)
    expect(values.taxes).toEqual([])
    expect(values.fixedCharges).toEqual([])
    expect(values.charges).toEqual([])
  })
})
