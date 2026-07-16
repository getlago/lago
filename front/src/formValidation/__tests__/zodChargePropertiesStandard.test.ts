import { z } from 'zod'

import {
  PropertiesZodInput,
  validateChargeProperties,
} from '~/formValidation/chargePropertiesSchema'
import { ChargeModelEnum } from '~/generated/graphql'

function validate(
  chargeModel: ChargeModelEnum,
  props: Partial<PropertiesZodInput>,
  pathPrefix: string[],
) {
  const issues: any[] = []

  const ctx = { addIssue: (issue: any) => issues.push(issue), path: [] } as any as z.RefinementCtx

  validateChargeProperties(chargeModel, props as PropertiesZodInput, ctx, pathPrefix)
  return { isValid: issues.length === 0, issues }
}

describe('validateChargeProperties Standard', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const result = validate(ChargeModelEnum.Standard, { amount: '' }, ['properties'])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string amount', () => {
        const result = validate(ChargeModelEnum.Standard, { amount: 'a' }, ['properties'])

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has string amount', () => {
        const result = validate(ChargeModelEnum.Standard, { amount: '1' }, ['properties'])

        expect(result.isValid).toBe(true)
      })
    })
  })

  describe('filters (same validation, different path prefix)', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const result = validate(ChargeModelEnum.Standard, { amount: '' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string amount', () => {
        const result = validate(ChargeModelEnum.Standard, { amount: 'a' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has string amount', () => {
        const result = validate(ChargeModelEnum.Standard, { amount: '1' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(true)
      })
    })
  })
})
