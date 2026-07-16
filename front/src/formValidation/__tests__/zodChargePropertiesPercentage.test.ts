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

describe('validateChargeProperties Percentage', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has empty string rate', () => {
        const result = validate(ChargeModelEnum.Percentage, { rate: '' }, ['properties'])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string rate', () => {
        const result = validate(ChargeModelEnum.Percentage, { rate: 'a' }, ['properties'])

        expect(result.isValid).toBe(false)
      })

      it('has null rate', () => {
        const result = validate(ChargeModelEnum.Percentage, { rate: null }, ['properties'])

        expect(result.isValid).toBe(false)
      })

      it('has perTransactionMinAmount higher than perTransactionMaxAmount as strings', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          { rate: '1', perTransactionMinAmount: '10', perTransactionMaxAmount: '1' },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
        expect(result.issues).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              message: 'minAmountShouldBeLowerThanMax',
              path: ['properties', 'perTransactionMinAmount'],
            }),
            expect.objectContaining({
              message: 'maxAmountShouldBeHigherThanMin',
              path: ['properties', 'perTransactionMaxAmount'],
            }),
          ]),
        )
      })

      it('has perTransactionMinAmount higher than perTransactionMaxAmount as mixed', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          {
            rate: '1',
            perTransactionMinAmount: '10',
            // perTransactionMaxAmount as string since Zod schema expects strings
            perTransactionMaxAmount: '1',
          },
          ['properties'],
        )

        expect(result.isValid).toBe(false)
        expect(result.issues).toHaveLength(2)
      })
    })
    describe('valid', () => {
      it('has string rate', () => {
        const result = validate(ChargeModelEnum.Percentage, { rate: '1' }, ['properties'])

        expect(result.isValid).toBe(true)
      })

      it('has perTransactionMinAmount lower than perTransactionMaxAmount for strings', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          { rate: '1', perTransactionMinAmount: '1', perTransactionMaxAmount: '10' },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })

      it('has perTransactionMinAmount equal to perTransactionMaxAmount', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          { rate: '1', perTransactionMinAmount: '10', perTransactionMaxAmount: '10' },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })

      it('has only perTransactionMinAmount (no max)', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          { rate: '1', perTransactionMinAmount: '10' },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })

      it('has only perTransactionMaxAmount (no min)', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          { rate: '1', perTransactionMaxAmount: '10' },
          ['properties'],
        )

        expect(result.isValid).toBe(true)
      })
    })
  })

  describe('filters (same validation, different path prefix)', () => {
    describe('invalid', () => {
      it('has empty string rate', () => {
        const result = validate(ChargeModelEnum.Percentage, { rate: '' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has invalid string rate', () => {
        const result = validate(ChargeModelEnum.Percentage, { rate: 'a' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(false)
      })

      it('has perTransactionMinAmount higher than perTransactionMaxAmount as strings', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          { rate: '1', perTransactionMinAmount: '10', perTransactionMaxAmount: '1' },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(false)
      })
    })
    describe('valid', () => {
      it('has string rate', () => {
        const result = validate(ChargeModelEnum.Percentage, { rate: '1' }, [
          'filters',
          '0',
          'properties',
        ])

        expect(result.isValid).toBe(true)
      })

      it('has perTransactionMinAmount lower than perTransactionMaxAmount for strings', () => {
        const result = validate(
          ChargeModelEnum.Percentage,
          { rate: '1', perTransactionMinAmount: '1', perTransactionMaxAmount: '10' },
          ['filters', '0', 'properties'],
        )

        expect(result.isValid).toBe(true)
      })
    })
  })
})
