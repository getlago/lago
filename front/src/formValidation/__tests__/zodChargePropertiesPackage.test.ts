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

describe('validateChargeProperties Package', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '', packageSize: '1' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string amount', () => {
        const result = validate(ChargeModelEnum.Package, { amount: 'a', packageSize: '1' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has empty string packageSize', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: '' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string packageSize', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: 'a' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has too small packageSize', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: '0.99' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has string amount', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: '1' }, [
          'properties',
        ])

        expect(result.isValid).toBe(true)
      })
    })
  })

  describe('filters (same validation, different path prefix)', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '', packageSize: '1' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string amount', () => {
        const result = validate(ChargeModelEnum.Package, { amount: 'a', packageSize: '1' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has empty string packageSize', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: '' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string packageSize', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: 'a' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has too small packageSize', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: '0.99' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has string amount', () => {
        const result = validate(ChargeModelEnum.Package, { amount: '1', packageSize: '1' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(true)
      })
    })
  })
})
