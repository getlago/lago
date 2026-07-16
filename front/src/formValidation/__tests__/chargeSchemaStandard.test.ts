import { transformFilterObjectToString } from '~/components/plans/utils'
import { chargeSchema, fixedChargeSchema } from '~/formValidation/chargeSchema'
import { ChargeModelEnum, FixedChargeChargeModelEnum } from '~/generated/graphql'

describe('chargeSchema Standard', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            properties: {
              amount: '',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            properties: {
              amount: 'a',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
    describe('valid', () => {
      it('has string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            properties: {
              amount: '1',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('has number value', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            properties: {
              amount: 1,
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
    })
  })

  describe('filters', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            filters: [
              {
                invoiceDisplayName: undefined,
                values: [
                  transformFilterObjectToString('key'),
                  transformFilterObjectToString('key', 'value'),
                ],
                properties: {
                  amount: '',
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            filters: [
              {
                invoiceDisplayName: undefined,
                values: [
                  transformFilterObjectToString('key'),
                  transformFilterObjectToString('key', 'value'),
                ],
                properties: {
                  amount: 'a',
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
    describe('valid', () => {
      it('has string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            filters: [
              {
                invoiceDisplayName: undefined,
                values: [
                  transformFilterObjectToString('key'),
                  transformFilterObjectToString('key', 'value'),
                ],
                properties: {
                  amount: '1',
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('has string value', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Standard,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            filters: [
              {
                invoiceDisplayName: undefined,
                values: [
                  transformFilterObjectToString('key'),
                  transformFilterObjectToString('key', 'value'),
                ],
                properties: {
                  amount: 1,
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
    })
  })
})

describe('fixedChargeSchema Standard', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Standard,
            properties: {
              amount: '',
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid string amount', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Standard,
            properties: {
              amount: 'a',
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has empty units', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Standard,
            properties: {
              amount: '1',
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
    describe('valid', () => {
      it('has string amount and units', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Standard,
            properties: {
              amount: '1',
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('has number value and units', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Standard,
            properties: {
              amount: 1,
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
    })
  })
})
