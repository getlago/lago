import { DateTime, Settings } from 'luxon'

import {
  CouponExpiration,
  CouponFrequency,
  CouponTypeEnum,
  CurrencyEnum,
} from '~/generated/graphql'

import {
  CouponFormValues,
  couponValidationSchema,
  emptyCouponDefaultValues,
} from '../validationSchema'

describe('couponValidationSchema', () => {
  const originalDefaultZone = Settings.defaultZone

  beforeAll(() => {
    Settings.defaultZone = 'UTC'
  })

  afterAll(() => {
    Settings.defaultZone = originalDefaultZone
  })

  const createValidCouponData = (overrides: Partial<CouponFormValues> = {}): CouponFormValues => ({
    name: 'Test Coupon',
    code: 'TEST_COUPON',
    description: '',
    couponType: CouponTypeEnum.FixedAmount,
    amountCents: '100',
    amountCurrency: CurrencyEnum.Usd,
    percentageRate: undefined,
    frequency: CouponFrequency.Once,
    frequencyDuration: undefined,
    reusable: true,
    expiration: CouponExpiration.NoExpiration,
    expirationAt: undefined,
    hasPlanLimit: false,
    limitPlansList: [],
    hasBillableMetricLimit: false,
    limitBillableMetricsList: [],
    ...overrides,
  })

  describe('GIVEN basic field validation', () => {
    describe('WHEN name is empty', () => {
      it('THEN should fail validation with error on name field', () => {
        const data = createValidCouponData({ name: '' })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const nameError = result.error.issues.find((issue) => issue.path.includes('name'))

          expect(nameError).toBeDefined()
        }
      })
    })

    describe('WHEN code is empty', () => {
      it('THEN should fail validation with error on code field', () => {
        const data = createValidCouponData({ code: '' })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const codeError = result.error.issues.find((issue) => issue.path.includes('code'))

          expect(codeError).toBeDefined()
        }
      })
    })

    describe('WHEN all required fields are provided', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData()

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN couponType is FixedAmount', () => {
    describe('WHEN amountCents is undefined', () => {
      it('THEN should fail validation with error on amountCents field', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const amountError = result.error.issues.find((issue) =>
            issue.path.includes('amountCents'),
          )

          expect(amountError).toBeDefined()
        }
      })
    })

    describe('WHEN amountCents is empty string', () => {
      it('THEN should fail validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: '',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN amountCents is less than 0.001', () => {
      it('THEN should fail validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: '0.0001',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN amountCents is exactly 0.001', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: '0.001',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN amountCents is a valid positive number', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: '100.50',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN amountCents is NaN', () => {
      it('THEN should fail validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: 'invalid',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })
  })

  describe('GIVEN couponType is Percentage', () => {
    describe('WHEN percentageRate is undefined', () => {
      it('THEN should fail validation with error on percentageRate field', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.Percentage,
          percentageRate: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const percentageError = result.error.issues.find((issue) =>
            issue.path.includes('percentageRate'),
          )

          expect(percentageError).toBeDefined()
        }
      })
    })

    describe('WHEN percentageRate is empty string', () => {
      it('THEN should fail validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.Percentage,
          percentageRate: '',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN percentageRate is less than 0.001', () => {
      it('THEN should fail validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.Percentage,
          percentageRate: '0.0001',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN percentageRate is exactly 0.001', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.Percentage,
          percentageRate: '0.001',
          amountCents: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN percentageRate is a valid positive number', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.Percentage,
          percentageRate: '25.5',
          amountCents: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN amountCents is not provided but percentageRate is valid', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          couponType: CouponTypeEnum.Percentage,
          percentageRate: '10',
          amountCents: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN frequency is Recurring', () => {
    describe('WHEN frequencyDuration is undefined', () => {
      it('THEN should fail validation with error on frequencyDuration field', () => {
        const data = createValidCouponData({
          frequency: CouponFrequency.Recurring,
          frequencyDuration: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const durationError = result.error.issues.find((issue) =>
            issue.path.includes('frequencyDuration'),
          )

          expect(durationError).toBeDefined()
        }
      })
    })

    describe('WHEN frequencyDuration is empty string', () => {
      it('THEN should fail validation', () => {
        const data = createValidCouponData({
          frequency: CouponFrequency.Recurring,
          frequencyDuration: '',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN frequencyDuration is less than 1', () => {
      it('THEN should fail validation', () => {
        const data = createValidCouponData({
          frequency: CouponFrequency.Recurring,
          frequencyDuration: '0',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN frequencyDuration is exactly 1', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          frequency: CouponFrequency.Recurring,
          frequencyDuration: '1',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN frequencyDuration is a valid positive integer', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          frequency: CouponFrequency.Recurring,
          frequencyDuration: '12',
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN frequency is Once or Forever', () => {
    describe('WHEN frequencyDuration is not provided', () => {
      it.each([
        ['Once', CouponFrequency.Once],
        ['Forever', CouponFrequency.Forever],
      ])('THEN should pass validation for %s frequency', (_, frequency) => {
        const data = createValidCouponData({
          frequency,
          frequencyDuration: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN expiration is TimeLimit', () => {
    describe('WHEN expirationAt is undefined', () => {
      it('THEN should fail validation with error on expirationAt field', () => {
        const data = createValidCouponData({
          expiration: CouponExpiration.TimeLimit,
          expirationAt: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const expirationError = result.error.issues.find((issue) =>
            issue.path.includes('expirationAt'),
          )

          expect(expirationError).toBeDefined()
        }
      })
    })

    describe('WHEN expirationAt is in the past (more than 1 day ago)', () => {
      it('THEN should fail validation', () => {
        const pastDate = DateTime.now().minus({ days: 2 }).toISO()
        const data = createValidCouponData({
          expiration: CouponExpiration.TimeLimit,
          expirationAt: pastDate as string,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN expirationAt is in the future', () => {
      it('THEN should pass validation', () => {
        const futureDate = DateTime.now().plus({ days: 30 }).toISO()
        const data = createValidCouponData({
          expiration: CouponExpiration.TimeLimit,
          expirationAt: futureDate as string,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN expirationAt is today', () => {
      it('THEN should pass validation', () => {
        const today = DateTime.now().toISO()
        const data = createValidCouponData({
          expiration: CouponExpiration.TimeLimit,
          expirationAt: today as string,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN expiration is NoExpiration', () => {
    describe('WHEN expirationAt is not provided', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          expiration: CouponExpiration.NoExpiration,
          expirationAt: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN hasPlanLimit is true', () => {
    describe('WHEN limitPlansList is empty', () => {
      it('THEN should fail validation with error on limitPlansList field', () => {
        const data = createValidCouponData({
          hasPlanLimit: true,
          limitPlansList: [],
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const planError = result.error.issues.find((issue) =>
            issue.path.includes('limitPlansList'),
          )

          expect(planError).toBeDefined()
        }
      })
    })

    describe('WHEN limitPlansList has items', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          hasPlanLimit: true,
          limitPlansList: [{ id: 'plan-1', name: 'Test Plan', code: 'TEST_PLAN' }] as never[],
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN hasPlanLimit is false', () => {
    describe('WHEN limitPlansList is empty', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          hasPlanLimit: false,
          limitPlansList: [],
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN hasBillableMetricLimit is true', () => {
    describe('WHEN limitBillableMetricsList is empty', () => {
      it('THEN should fail validation with error on limitBillableMetricsList field', () => {
        const data = createValidCouponData({
          hasBillableMetricLimit: true,
          limitBillableMetricsList: [],
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const metricError = result.error.issues.find((issue) =>
            issue.path.includes('limitBillableMetricsList'),
          )

          expect(metricError).toBeDefined()
        }
      })
    })

    describe('WHEN limitBillableMetricsList has items', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          hasBillableMetricLimit: true,
          limitBillableMetricsList: [
            { id: 'metric-1', name: 'Test Metric', code: 'TEST_METRIC' },
          ] as never[],
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN hasBillableMetricLimit is false', () => {
    describe('WHEN limitBillableMetricsList is empty', () => {
      it('THEN should pass validation', () => {
        const data = createValidCouponData({
          hasBillableMetricLimit: false,
          limitBillableMetricsList: [],
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN emptyCouponDefaultValues', () => {
    describe('WHEN validating default values', () => {
      it('THEN should fail due to empty required fields', () => {
        const result = couponValidationSchema.safeParse(emptyCouponDefaultValues)

        expect(result.success).toBe(false)
      })

      it('THEN should have the expected structure', () => {
        expect(emptyCouponDefaultValues).toEqual({
          name: '',
          code: '',
          description: '',
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: undefined,
          amountCurrency: CurrencyEnum.Usd,
          percentageRate: undefined,
          frequency: CouponFrequency.Once,
          frequencyDuration: undefined,
          reusable: true,
          expiration: CouponExpiration.NoExpiration,
          expirationAt: undefined,
          hasPlanLimit: false,
          limitPlansList: [],
          hasBillableMetricLimit: false,
          limitBillableMetricsList: [],
        })
      })
    })
  })

  describe('GIVEN multiple validation errors', () => {
    describe('WHEN multiple fields are invalid', () => {
      it('THEN should report errors for all invalid fields', () => {
        const data = createValidCouponData({
          name: '',
          code: '',
          couponType: CouponTypeEnum.FixedAmount,
          amountCents: undefined,
        })

        const result = couponValidationSchema.safeParse(data)

        expect(result.success).toBe(false)
        if (!result.success) {
          const errorPaths = result.error.issues.map((issue) => issue.path[0])

          expect(errorPaths).toContain('name')
          expect(errorPaths).toContain('code')
          expect(errorPaths).toContain('amountCents')
        }
      })
    })
  })
})
