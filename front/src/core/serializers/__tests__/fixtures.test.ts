import { addOnBillingItemsFixture, planBillingItemsFixture } from './fixtures'

import { fromBillingItems } from '../serializeQuoteBillingItems'
import { fromPlanBillingItems } from '../serializeQuotePlanBillingItems'

describe('billing items fixtures', () => {
  describe('addOnBillingItemsFixture', () => {
    it('deserializes the add-on payload (code/name/description) and applies overrides', () => {
      const { addOnItems, originalPayloads } = fromBillingItems(addOnBillingItemsFixture)

      expect(addOnItems).toHaveLength(1)

      const [item] = addOnItems

      expect(item.code).toBe('setup_fee')
      expect(item.name).toBe('Setup Fee')
      expect(item.description).toBe('One-time onboarding and setup')
      // override wins over baseline payload
      expect(item.unitAmountCents).toBe('45000')
      expect(item.totalAmount).toBe('45000')

      // original (pre-override) payload is preserved, keyed by localId
      const original = originalPayloads['a1b2c3d4-e5f6-0000-1111-222233334444']

      expect(original.code).toBe('setup_fee')
      expect(original.unit_amount_cents).toBe(50000)
    })
  })

  describe('planBillingItemsFixture', () => {
    it('deserializes the plan payload (code/name/description) and exposes overrides', () => {
      const plans = planBillingItemsFixture.plans ?? []
      const result = fromPlanBillingItems(plans)

      expect(result.planCode).toBe('enterprise')
      expect(result.planName).toBe('Enterprise Plan')
      expect(result.planDescription).toBe('Custom enterprise offering')

      // full plan config is reconstructed into form values
      expect(result.formValues?.code).toBe('enterprise')
      expect(result.formValues?.name).toBe('Enterprise Plan')
      expect(result.formValues?.charges).toHaveLength(1)

      // expanded overrides pass through untouched
      expect(result.overrides.amount_cents).toBe(90000)
      expect(result.overrides.invoice_display_name).toBe('Enterprise (negotiated)')
      expect(result.overrides.minimum_commitment).toEqual({
        amount_cents: 45000,
        invoice_display_name: 'Negotiated monthly minimum',
      })
      expect(result.overrides.charges).toEqual([
        {
          billable_metric_code: 'api_calls',
          charge_model: 'standard',
          properties: { amount: '0.008' },
        },
      ])
      expect(result.overrides.usage_thresholds).toEqual([
        { amount_cents: 200000, recurring: false, threshold_display_name: 'Annual usage cap' },
      ])
    })
  })
})
