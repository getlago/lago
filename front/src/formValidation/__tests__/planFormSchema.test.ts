import {
  ChargeModelEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  PlanInterval,
} from '~/generated/graphql'

import { planFormSchema } from '../planFormSchema'

// --- Helpers ---

const validBase = {
  name: 'My Plan',
  code: 'my_plan',
  description: '',
  interval: PlanInterval.Monthly,
  amountCurrency: CurrencyEnum.Usd,
  amountCents: '0',
  payInAdvance: false,
  trialPeriod: 0,
  taxes: [],
  billChargesMonthly: false,
  billFixedChargesMonthly: false,
  charges: [],
  fixedCharges: [],
  minimumCommitment: {},
  invoiceDisplayName: '',
  entitlements: [],
}

function validate(overrides: Record<string, unknown> = {}) {
  const result = planFormSchema.safeParse({ ...validBase, ...overrides })

  return {
    isValid: result.success,
    issues: result.success ? [] : result.error.issues,
  }
}

function issuePathsFor(overrides: Record<string, unknown> = {}) {
  const { issues } = validate(overrides)

  return issues.map((i) => i.path.join('.'))
}

// --- Tests ---

describe('planFormSchema', () => {
  describe('GIVEN a valid plan form', () => {
    describe('WHEN all required fields are filled', () => {
      it('THEN should pass validation', () => {
        expect(validate().isValid).toBe(true)
      })
    })
  })

  describe('GIVEN required settings fields', () => {
    describe('WHEN name is empty', () => {
      it('THEN should fail with name error', () => {
        expect(validate({ name: '' }).isValid).toBe(false)
        expect(issuePathsFor({ name: '' })).toContain('name')
      })
    })

    describe('WHEN code is empty', () => {
      it('THEN should fail with code error', () => {
        expect(validate({ code: '' }).isValid).toBe(false)
        expect(issuePathsFor({ code: '' })).toContain('code')
      })
    })

    describe('WHEN interval is invalid', () => {
      it('THEN should fail with interval error', () => {
        expect(validate({ interval: 'invalid' }).isValid).toBe(false)
        expect(issuePathsFor({ interval: 'invalid' })).toContain('interval')
      })
    })

    describe('WHEN amountCurrency is invalid', () => {
      it('THEN should fail with amountCurrency error', () => {
        expect(validate({ amountCurrency: 'INVALID' }).isValid).toBe(false)
        expect(issuePathsFor({ amountCurrency: 'INVALID' })).toContain('amountCurrency')
      })
    })
  })

  describe('GIVEN fixed charges', () => {
    const validFixedCharge = {
      addOn: { id: 'addon-1', name: 'Add-on', code: 'addon' },
      chargeModel: FixedChargeChargeModelEnum.Standard,
      properties: { amount: '10' },
      units: '5',
      payInAdvance: false,
      prorated: false,
      taxes: [],
      invoiceDisplayName: '',
      applyUnitsImmediately: false,
    }

    describe('WHEN units is missing', () => {
      it('THEN should fail with units error', () => {
        const charge = { ...validFixedCharge, units: '' }
        const result = validate({ fixedCharges: [charge] })

        expect(result.isValid).toBe(false)
        expect(issuePathsFor({ fixedCharges: [charge] })).toContain('fixedCharges.0.units')
      })
    })

    describe('WHEN units is NaN', () => {
      it('THEN should fail with units error', () => {
        const charge = { ...validFixedCharge, units: 'abc' }

        expect(validate({ fixedCharges: [charge] }).isValid).toBe(false)
      })
    })

    describe('WHEN units is valid', () => {
      it('THEN should pass', () => {
        expect(validate({ fixedCharges: [validFixedCharge] }).isValid).toBe(true)
      })
    })
  })

  describe('GIVEN minimum commitment', () => {
    describe('WHEN commitment is empty object', () => {
      it('THEN should pass (no commitment configured)', () => {
        expect(validate({ minimumCommitment: {} }).isValid).toBe(true)
      })
    })

    describe('WHEN commitment has zero amountCents', () => {
      it('THEN should fail', () => {
        const result = validate({ minimumCommitment: { amountCents: '0' } })

        expect(result.isValid).toBe(false)
        expect(issuePathsFor({ minimumCommitment: { amountCents: '0' } })).toContain(
          'minimumCommitment.amountCents',
        )
      })
    })

    describe('WHEN commitment has valid amountCents', () => {
      it('THEN should pass', () => {
        expect(validate({ minimumCommitment: { amountCents: '1000' } }).isValid).toBe(true)
      })
    })
  })

  describe('GIVEN non-recurring usage thresholds', () => {
    describe('WHEN thresholds is undefined', () => {
      it('THEN should pass (no thresholds configured)', () => {
        expect(validate({ nonRecurringUsageThresholds: undefined }).isValid).toBe(true)
      })
    })

    describe('WHEN thresholds is empty array', () => {
      it('THEN should fail', () => {
        expect(validate({ nonRecurringUsageThresholds: [] }).isValid).toBe(false)
      })
    })

    describe('WHEN first threshold has amountCents <= 0', () => {
      it('THEN should fail', () => {
        const thresholds = [{ amountCents: 0 }]

        expect(validate({ nonRecurringUsageThresholds: thresholds }).isValid).toBe(false)
      })
    })

    describe('WHEN threshold amountCents is undefined', () => {
      it('THEN should fail', () => {
        const thresholds = [{ amountCents: undefined }]

        expect(validate({ nonRecurringUsageThresholds: thresholds }).isValid).toBe(false)
      })
    })

    describe('WHEN thresholds are not in ascending order', () => {
      it('THEN should fail', () => {
        const thresholds = [{ amountCents: 100 }, { amountCents: 50 }]

        expect(validate({ nonRecurringUsageThresholds: thresholds }).isValid).toBe(false)
      })
    })

    describe('WHEN thresholds are in ascending order', () => {
      it('THEN should pass', () => {
        const thresholds = [{ amountCents: 50 }, { amountCents: 100 }]

        expect(validate({ nonRecurringUsageThresholds: thresholds }).isValid).toBe(true)
      })
    })
  })

  describe('GIVEN recurring usage threshold', () => {
    describe('WHEN threshold is undefined', () => {
      it('THEN should pass (no threshold configured)', () => {
        expect(validate({ recurringUsageThreshold: undefined }).isValid).toBe(true)
      })
    })

    describe('WHEN threshold amountCents is 0', () => {
      it('THEN should fail', () => {
        const result = validate({ recurringUsageThreshold: { amountCents: 0 } })

        expect(result.isValid).toBe(false)
        expect(issuePathsFor({ recurringUsageThreshold: { amountCents: 0 } })).toContain(
          'recurringUsageThreshold.amountCents',
        )
      })
    })

    describe('WHEN threshold amountCents is positive', () => {
      it('THEN should pass', () => {
        expect(validate({ recurringUsageThreshold: { amountCents: 100 } }).isValid).toBe(true)
      })
    })
  })

  describe('GIVEN usage charges with filters', () => {
    describe('WHEN a filter has empty values', () => {
      it('THEN should fail with filter values error', () => {
        const charges = [
          {
            chargeModel: ChargeModelEnum.Standard,
            properties: { amount: '10' },
            billableMetric: { id: 'bm-1', name: 'BM', code: 'bm', recurring: false, filters: [] },
            filters: [{ properties: { amount: '5' }, values: [] }],
            taxes: [],
            payInAdvance: false,
            prorated: false,
          },
        ]

        const paths = issuePathsFor({ charges })

        expect(paths).toContain('charges.0.filters.0.values')
      })
    })
  })
})
