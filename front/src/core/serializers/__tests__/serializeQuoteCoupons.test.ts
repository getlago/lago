import { CouponFrequency, CouponTypeEnum, CurrencyEnum } from '~/generated/graphql'

import {
  type BillingItemCoupon,
  type DiscountFormItem,
  fromCoupons,
  toCoupons,
} from '../serializeQuoteCoupons'

const fixedPayload = {
  position: 1,
  code: 'enterprise_discount_20',
  id: 'cpn_uuid',
  name: 'Enterprise 20% Discount',
  type: 'fixed_amount' as const,
  amount_cents: 5000,
  percentage_rate: null,
  currency: 'EUR',
  frequency: 'recurring' as const,
  frequency_duration: 6,
  expiration_at: null,
  limited_plans: false,
  plan_codes: [],
  limited_billable_metrics: false,
  billable_metric_codes: [],
  coupon_overrides: null,
  catalog_snapshot: null,
  resolved_payload: null,
}

describe('serializeQuoteCoupons', () => {
  describe('toCoupons', () => {
    it('writes the full UI-editable set into overrides (fixed amount)', () => {
      const items: DiscountFormItem[] = [
        {
          localId: 'local-1',
          couponId: 'cpn_uuid',
          couponType: CouponTypeEnum.FixedAmount,
          name: 'Enterprise 20% Discount',
          code: 'enterprise_discount_20',
          currency: CurrencyEnum.Eur,
          amount: '90.00',
          percentageRate: null,
          frequency: CouponFrequency.Recurring,
          frequencyDuration: 6,
        },
      ]

      const result = toCoupons(items, { 'local-1': fixedPayload })

      expect(result).toHaveLength(1)
      expect(result[0].type).toBe('coupon')
      expect(result[0].id).toBe('cpn_uuid')
      expect(result[0].localId).toBe('local-1')
      expect(result[0].overrides).toEqual({
        amount_cents: 9000,
        percentage_rate: null,
        frequency: 'recurring',
        frequency_duration: 6,
      })
      // currency is NOT in overrides
      expect(result[0].overrides).not.toHaveProperty('currency')
    })

    it('writes percentage_rate (amount_cents null) for percentage coupons', () => {
      const items: DiscountFormItem[] = [
        {
          localId: 'local-2',
          couponId: 'cpn_pct',
          couponType: CouponTypeEnum.Percentage,
          name: 'Pct',
          code: 'pct',
          currency: CurrencyEnum.Eur,
          amount: '',
          percentageRate: 12.5,
          frequency: CouponFrequency.Forever,
          frequencyDuration: null,
        },
      ]

      const result = toCoupons(items, {
        'local-2': {
          ...fixedPayload,
          id: 'cpn_pct',
          type: 'percentage',
          amount_cents: null,
          percentage_rate: 10,
        },
      })

      expect(result[0].overrides).toEqual({
        amount_cents: null,
        percentage_rate: 12.5,
        frequency: 'forever',
        frequency_duration: null,
      })
    })
  })

  describe('fromCoupons', () => {
    it('round-trips a saved coupon into a form item keyed by localId, overrides winning', () => {
      const saved: BillingItemCoupon[] = [
        {
          type: 'coupon',
          id: 'cpn_uuid',
          localId: 'local-1',
          payload: fixedPayload,
          overrides: {
            amount_cents: 9000,
            percentage_rate: null,
            frequency: CouponFrequency.Recurring,
            frequency_duration: 6,
          },
        },
      ]

      const { entities, discountItems, originalPayloads } = fromCoupons(saved)

      expect(discountItems[0].couponId).toBe('cpn_uuid')
      expect(discountItems[0].amount).toBe('90') // 9000 cents / EUR, no trailing .00
      expect(discountItems[0].frequency).toBe(CouponFrequency.Recurring)
      expect(entities['local-1'].entityType).toBe('coupon')
      expect(entities['local-1'].name).toBe('Enterprise 20% Discount')
      expect(originalPayloads['local-1']).toEqual(fixedPayload)
    })
  })
})
