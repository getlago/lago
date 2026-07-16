import { CurrencyEnum } from '~/generated/graphql'

import {
  editQuoteAsideDefaultValues,
  type EditQuoteAsideFormValues,
  editQuoteAsideSchema,
} from '../validationSchema'

const validBase: EditQuoteAsideFormValues = {
  orderTypeLabel: 'Subscription creation',
  customerName: 'Acme Corp',
  billingEntityId: 'be-1',
  currency: CurrencyEnum.Usd,
  subscriptionLabel: 'Premium - ext-sub-1',
  startDate: '2026-06-01T00:00:00Z',
  endDate: '2026-12-31T00:00:00Z',
  netPaymentTermLabel: '30 days',
}

describe('editQuoteAsideSchema', () => {
  describe('GIVEN valid base values', () => {
    describe('WHEN all required and optional fields are provided', () => {
      it('THEN should pass validation', () => {
        const result = editQuoteAsideSchema.safeParse(validBase)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN optional fields are omitted', () => {
      it('THEN should pass validation', () => {
        const result = editQuoteAsideSchema.safeParse({
          orderTypeLabel: 'One-off',
          customerName: 'Test',
          billingEntityId: 'be-2',
        })

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN startDate and endDate are both provided', () => {
    describe('WHEN endDate is after startDate', () => {
      it('THEN should pass validation', () => {
        const result = editQuoteAsideSchema.safeParse({
          ...validBase,
          startDate: '2026-01-01T00:00:00Z',
          endDate: '2026-06-01T00:00:00Z',
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN endDate equals startDate', () => {
      it('THEN should fail with an endDate error', () => {
        const result = editQuoteAsideSchema.safeParse({
          ...validBase,
          startDate: '2026-06-01T00:00:00Z',
          endDate: '2026-06-01T00:00:00Z',
        })

        expect(result.success).toBe(false)

        if (!result.success) {
          const endDateError = result.error.issues.find((i) => i.path.includes('endDate'))

          expect(endDateError).toBeDefined()
        }
      })
    })

    describe('WHEN endDate is before startDate', () => {
      it('THEN should fail with an endDate error', () => {
        const result = editQuoteAsideSchema.safeParse({
          ...validBase,
          startDate: '2026-12-01T00:00:00Z',
          endDate: '2026-01-01T00:00:00Z',
        })

        expect(result.success).toBe(false)

        if (!result.success) {
          const endDateError = result.error.issues.find((i) => i.path.includes('endDate'))

          expect(endDateError).toBeDefined()
        }
      })
    })
  })

  describe('GIVEN only one date is provided', () => {
    describe('WHEN only startDate is set', () => {
      it('THEN should pass validation (no cross-field check)', () => {
        const result = editQuoteAsideSchema.safeParse({
          ...validBase,
          startDate: '2026-06-01T00:00:00Z',
          endDate: undefined,
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN only endDate is set', () => {
      it('THEN should pass validation (no cross-field check)', () => {
        const result = editQuoteAsideSchema.safeParse({
          ...validBase,
          startDate: undefined,
          endDate: '2026-12-01T00:00:00Z',
        })

        expect(result.success).toBe(true)
      })
    })
  })
})

describe('editQuoteAsideDefaultValues', () => {
  describe('GIVEN the default values export', () => {
    describe('WHEN inspected', () => {
      it('THEN should have empty strings for required fields and undefined for optional fields', () => {
        expect(editQuoteAsideDefaultValues).toEqual({
          orderTypeLabel: '',
          customerName: '',
          billingEntityId: '',
          currency: undefined,
          subscriptionLabel: undefined,
          startDate: undefined,
          endDate: undefined,
          netPaymentTermLabel: undefined,
        })
      })
    })

    describe('WHEN parsed by the schema', () => {
      it('THEN should pass validation', () => {
        const result = editQuoteAsideSchema.safeParse(editQuoteAsideDefaultValues)

        expect(result.success).toBe(true)
      })
    })
  })
})
