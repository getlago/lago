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

describe('validateChargeProperties Volume', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has undefined volumeRange', () => {
        const result = validate(ChargeModelEnum.Volume, { volumeRanges: undefined }, ['properties'])

        expect(result.isValid).toBe(false)
      })
      it('has empty volumeRange', () => {
        const result = validate(ChargeModelEnum.Volume, { volumeRanges: [] }, ['properties'])

        expect(result.isValid).toBe(false)
      })
      it('has wrong perUnitAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '0', toValue: '100', perUnitAmount: 'a', flatAmount: '1' }],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has wrong flatAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '0', toValue: '100', perUnitAmount: '1', flatAmount: 'a' }],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has wrong perUnitAmount and flatAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '0', toValue: '100', perUnitAmount: 'a', flatAmount: 'a' }],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has empty perUnitAmount and empty flatAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '0', toValue: '100', perUnitAmount: '', flatAmount: '' }],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has undefined perUnitAmount and undefined flatAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '0', toValue: '100', perUnitAmount: undefined, flatAmount: undefined },
            ],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has fromValue bigger than toValue with one range', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '100', toValue: '10', perUnitAmount: '1', flatAmount: '1' },
            ],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has fromValue bigger than toValue with two range', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '1', toValue: '10', perUnitAmount: '1', flatAmount: '1' },
              { fromValue: '100', toValue: '10', perUnitAmount: '1', flatAmount: '1' },
            ],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has fromValue equal to toValue', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '100', toValue: '100', perUnitAmount: '1', flatAmount: 'a' },
            ],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has valid volumeRange', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '1', toValue: '100', perUnitAmount: '1', flatAmount: '1' },
              { fromValue: '101', toValue: '1000', perUnitAmount: '1', flatAmount: '1' },
            ],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })
      it('has valid range with only perUnitAmount filled', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '1', toValue: '100', perUnitAmount: '1', flatAmount: '' }],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })
      it('has valid range with only flatAmount filled', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '1', toValue: '100', perUnitAmount: '', flatAmount: '1' }],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })
      it('has valid range with zero perUnitAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '1', toValue: '100', perUnitAmount: '0', flatAmount: '' }],
          },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })
    })
  })

  describe('filters (same validation, different path prefix)', () => {
    describe('invalid', () => {
      it('has undefined volumeRange', () => {
        const result = validate(ChargeModelEnum.Volume, { volumeRanges: undefined }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
      it('has empty volumeRange', () => {
        const result = validate(ChargeModelEnum.Volume, { volumeRanges: [] }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })
      it('has wrong perUnitAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '0', toValue: '100', perUnitAmount: 'a', flatAmount: '1' }],
          },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has wrong flatAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '0', toValue: '100', perUnitAmount: '1', flatAmount: 'a' }],
          },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has wrong perUnitAmount and flatAmount', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [{ fromValue: '0', toValue: '100', perUnitAmount: 'a', flatAmount: 'a' }],
          },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has fromValue bigger than toValue with one range', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '100', toValue: '10', perUnitAmount: '1', flatAmount: '1' },
            ],
          },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has fromValue bigger than toValue with two range', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '1', toValue: '10', perUnitAmount: '1', flatAmount: '1' },
              { fromValue: '100', toValue: '10', perUnitAmount: '1', flatAmount: '1' },
            ],
          },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(false)
      })
      it('has fromValue equal to toValue', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '100', toValue: '100', perUnitAmount: '1', flatAmount: 'a' },
            ],
          },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has valid volumeRange', () => {
        const result = validate(
          ChargeModelEnum.Volume,
          {
            volumeRanges: [
              { fromValue: '1', toValue: '100', perUnitAmount: '1', flatAmount: '1' },
              { fromValue: '101', toValue: '1000', perUnitAmount: '1', flatAmount: '1' },
            ],
          },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(true)
      })
    })
  })
})
