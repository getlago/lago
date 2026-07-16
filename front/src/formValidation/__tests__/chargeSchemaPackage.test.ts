import { transformFilterObjectToString } from '~/components/plans/utils'
import { chargeSchema } from '~/formValidation/chargeSchema'
import { ChargeModelEnum } from '~/generated/graphql'

describe('chargeSchema Package', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has empty string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
            properties: {
              amount: '',
              packageSize: '1',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid string amount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
            properties: {
              amount: 'a',
              packageSize: '1',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has empty string packageSize', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
            properties: {
              amount: '1',
              packageSize: '',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid string packageSize', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
            properties: {
              amount: '1',
              packageSize: 'a',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has too small  packageSize', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
            properties: {
              amount: '1',
              packageSize: '0.99',
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
            chargeModel: ChargeModelEnum.Package,
            properties: {
              amount: '1',
              packageSize: '1',
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('has number value', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
            properties: {
              amount: 1,
              packageSize: 1,
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
            chargeModel: ChargeModelEnum.Package,
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
                  packageSize: '1',
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
            chargeModel: ChargeModelEnum.Package,
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
                  packageSize: '1',
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has empty string packageSize', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
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
                  packageSize: '',
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid string packageSize', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
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
                  packageSize: 'a',
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has too small  packageSize', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Package,
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
                  packageSize: '0.99',
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
            chargeModel: ChargeModelEnum.Package,
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
                  packageSize: '1',
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
            chargeModel: ChargeModelEnum.Package,
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
                  packageSize: 1,
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
