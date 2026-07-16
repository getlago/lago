import { hasNonEuEligibilityError } from '../utils'

const createNonEuError = () => ({
  errors: [
    {
      message: 'Unprocessable Entity',
      extensions: {
        code: 'unprocessable_entity',
        details: { euTaxManagement: ['billing_entity_must_be_in_eu'] },
      },
    },
  ],
})

describe('lagoTaxManagementUtils', () => {
  describe('hasNonEuEligibilityError', () => {
    it('should return false when no results have errors', () => {
      const results = [{ data: { updateBillingEntity: { id: '1' } }, errors: undefined }]

      expect(hasNonEuEligibilityError(results)).toBe(false)
    })

    it('should return true when a result contains the non-EU eligibility error', () => {
      expect(hasNonEuEligibilityError([createNonEuError()])).toBe(true)
    })

    it('should return false for a generic error without EU tax details', () => {
      const results = [
        {
          errors: [
            {
              message: 'Internal server error',
              extensions: { code: 'internal_error' },
            },
          ],
        },
      ]

      expect(hasNonEuEligibilityError(results)).toBe(false)
    })

    it('should return true when at least one result in multiple has the error', () => {
      const results = [
        { data: { updateBillingEntity: { id: '1' } }, errors: undefined },
        createNonEuError(),
      ]

      expect(hasNonEuEligibilityError(results)).toBe(true)
    })
  })
})
