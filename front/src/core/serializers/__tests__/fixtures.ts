import type { BillingItemsPayload } from '../serializeQuoteBillingItems'

/**
 * Example `BillingItemsPayload` for **add-on** pricing.
 *
 * Mirrors the backend contract: `payload` is the API baseline, `overrides`
 * carries only the fields the user changed in the pricing drawer (here, a
 * negotiated discount). `position`, `code` and `tax_codes` are not overridable.
 */
export const addOnBillingItemsFixture: BillingItemsPayload = {
  addons: [
    {
      type: 'addon',
      id: 'addon_01HXY',
      localId: 'a1b2c3d4-e5f6-0000-1111-222233334444',
      payload: {
        position: 1,
        code: 'setup_fee',
        name: 'Setup Fee',
        description: 'One-time onboarding and setup',
        units: 1,
        unit_amount_cents: 50000,
        total_amount_cents: 50000,
        invoice_display_name: 'Initial setup',
        from_datetime: null,
        to_datetime: null,
        tax_codes: ['vat_20'],
      },
      overrides: {
        unit_amount_cents: 45000,
        total_amount_cents: 45000,
      },
    },
  ],
}

/**
 * Example `BillingItemsPayload` for **plan** pricing.
 *
 * `payload` includes the optional plan-config fields (interval / amount /
 * charges) the FE persists for form reconstruction. `overrides` exercises the
 * full `PlanOverrides` shape — plan amount, display name, minimum commitment,
 * a charge override and a usage threshold. Note amounts in `overrides` are
 * numbers, while serialized `payload.amount_cents` is a string.
 */
export const planBillingItemsFixture: BillingItemsPayload = {
  addons: [],
  plans: [
    {
      type: 'plan',
      id: 'plan_01HXY',
      payload: {
        position: 1,
        code: 'enterprise',
        name: 'Enterprise Plan',
        description: 'Custom enterprise offering',

        subscription_external_id: 'sub_ext_acme_001',
        subscription_name: 'Acme Corp subscription',
        billing_time: 'anniversary',
        start_date: '2026-07-01',
        end_date: null,
        payment_method_id: null,
        invoice_custom_footer: null,

        // --- plan configuration ---
        interval: 'monthly',
        amount_cents: '100000',
        amount_currency: 'USD',
        pay_in_advance: true,
        bill_charges_monthly: null,
        bill_fixed_charges_monthly: null,
        trial_period: 14,
        invoice_display_name: 'Enterprise',
        tax_codes: ['vat_20'],
        taxes: [{ id: 'tax_01H', code: 'vat_20', name: 'VAT 20%', rate: 20 }],

        // --- charges ---
        charges: [
          {
            id: 'charge_01H',
            billable_metric: {
              id: 'bm_01H',
              code: 'api_calls',
              name: 'API Calls',
              aggregation_type: 'sum_agg',
              recurring: false,
              filters: [],
            },
            charge_model: 'standard',
            properties: { amount: '0.01' },
            invoice_display_name: 'API usage',
            min_amount_cents: '0',
            pay_in_advance: false,
            prorated: false,
            regroup_paid_fees: null,
            invoiceable: true,
            tax_codes: [],
            taxes: [],
            filters: [],
            applied_pricing_unit: null,
          },
        ],
        fixed_charges: [],

        // --- commitments & thresholds ---
        minimum_commitment: {
          id: 'mc_01H',
          amount_cents: '50000',
          invoice_display_name: 'Monthly minimum',
          commitment_type: 'minimum_commitment',
          tax_codes: [],
          taxes: [],
        },
        non_recurring_usage_thresholds: [],
        recurring_usage_threshold: null,
      },
      overrides: {
        amount_cents: 90000,
        invoice_display_name: 'Enterprise (negotiated)',
        minimum_commitment: {
          amount_cents: 45000,
          invoice_display_name: 'Negotiated monthly minimum',
        },
        charges: [
          {
            billable_metric_code: 'api_calls',
            charge_model: 'standard',
            properties: { amount: '0.008' },
          },
        ],
        usage_thresholds: [
          {
            amount_cents: 200000,
            recurring: false,
            threshold_display_name: 'Annual usage cap',
          },
        ],
      },
    },
  ],
}
