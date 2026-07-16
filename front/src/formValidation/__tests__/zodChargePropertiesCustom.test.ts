import { z } from 'zod'

import { AnyChargeModel } from '~/core/constants/form'
import {
  PropertiesZodInput,
  validateChargeProperties,
} from '~/formValidation/chargePropertiesSchema'
import { ChargeModelEnum } from '~/generated/graphql'

function validate(
  chargeModel: AnyChargeModel,
  props: Partial<PropertiesZodInput>,
  pathPrefix: string[],
) {
  const issues: any[] = []

  const ctx = { addIssue: (issue: any) => issues.push(issue), path: [] } as any as z.RefinementCtx

  validateChargeProperties(chargeModel, props as PropertiesZodInput, ctx, pathPrefix)
  return { isValid: issues.length === 0, issues }
}

describe('validateChargeProperties Custom', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has undefined customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: undefined }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
      it('has null customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: null }, ['properties'])

        expect(result.isValid).toBe(false)
      })
      it('has empty string customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: '' }, ['properties'])

        expect(result.isValid).toBe(false)
      })
      it('has invalid JSON string customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: 'not json' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
      it('has array JSON customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: '[1, 2]' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
      it('has string JSON customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: '"hello"' }, [
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has valid JSON object string customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: '{"key": "value"}' }, [
          'properties',
        ])

        expect(result.isValid).toBe(true)
      })
      it('has valid object customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: { key: 'value' } }, [
          'properties',
        ])

        expect(result.isValid).toBe(true)
      })
      it('has empty object customProperties', () => {
        const result = validate(ChargeModelEnum.Custom, { customProperties: '{}' }, ['properties'])

        expect(result.isValid).toBe(true)
      })
    })
  })
})
