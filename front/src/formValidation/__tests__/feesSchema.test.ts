import { simpleFeeSchema } from '~/formValidation/feesSchema'
import { CurrencyEnum } from '~/generated/graphql'

describe('feesSchema', () => {
  describe('simpleFeeSchema()', () => {
    describe('invalid', () => {
      it('value is 0 when checked', () => {
        const values = {
          checked: true,
          value: 0,
        }
        const schema = simpleFeeSchema(10, CurrencyEnum.Eur)
        const result = schema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('value is above max amount when checked', () => {
        const values = {
          checked: true,
          value: 11,
        }
        const schema = simpleFeeSchema(10, CurrencyEnum.Eur)
        const result = schema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
    describe('valid', () => {
      it('value is 0 when not checked', () => {
        const values = {
          checked: false,
          value: 0,
        }
        const schema = simpleFeeSchema(10, CurrencyEnum.Eur)
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('value is above max amount when not checked', () => {
        const values = {
          checked: false,
          value: 11,
        }
        const schema = simpleFeeSchema(10, CurrencyEnum.Eur)
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('value is below max amount when checked', () => {
        const values = {
          checked: true,
          value: 9,
        }
        const schema = simpleFeeSchema(1000, CurrencyEnum.Eur)
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('value is 1e-16 when checked', () => {
        const values = {
          checked: true,
          value: 1e-16,
        }
        const schema = simpleFeeSchema(1000, CurrencyEnum.Eur)
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
    })
  })
})
