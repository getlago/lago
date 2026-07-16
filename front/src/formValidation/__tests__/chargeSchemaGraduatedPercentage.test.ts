import { transformFilterObjectToString } from '~/components/plans/utils'
import { chargeSchema } from '~/formValidation/chargeSchema'
import { ChargeModelEnum } from '~/generated/graphql'

describe('chargeSchema GraduatedPercentage', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has undefined graduatedPercentageRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: undefined,
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty graduatedPercentageRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: [],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has NaN rate', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  rate: 'a',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has empty string rate', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  rate: '',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has null rate', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  rate: null,
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue bigger than toValue', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: [
                {
                  fromValue: '100',
                  toValue: '10',
                  rate: '1',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue equal than toValue', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: [
                {
                  fromValue: '100',
                  toValue: '100',
                  rate: '1',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
    describe('valid', () => {
      it('has valid graduatedPercentageRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
            properties: {
              graduatedPercentageRanges: [
                {
                  fromValue: '1',
                  toValue: '100',
                  rate: '1',
                },
                {
                  fromValue: '101',
                  toValue: '1000',
                  rate: '1',
                },
              ],
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
      it('has undefined graduatedPercentageRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: undefined,
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty graduatedPercentageRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: [],
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has NaN rate', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: [
                    {
                      fromValue: '0',
                      toValue: '100',
                      rate: 'a',
                    },
                  ],
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has empty string rate', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: [
                    {
                      fromValue: '0',
                      toValue: '100',
                      rate: '',
                    },
                  ],
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has null rate', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: [
                    {
                      fromValue: '0',
                      toValue: '100',
                      rate: null,
                    },
                  ],
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue bigger than toValue', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: [
                    {
                      fromValue: '100',
                      toValue: '10',
                      rate: '1',
                    },
                  ],
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue equal than toValue', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: [
                    {
                      fromValue: '100',
                      toValue: '100',
                      rate: '1',
                    },
                  ],
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
      it('has valid graduatedPercentageRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.GraduatedPercentage,
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
                  graduatedPercentageRanges: [
                    {
                      fromValue: '1',
                      toValue: '100',
                      rate: '1',
                    },
                    {
                      fromValue: '101',
                      toValue: '1000',
                      rate: '1',
                    },
                  ],
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
