import { transformFilterObjectToString } from '~/components/plans/utils'
import { chargeSchema, fixedChargeSchema } from '~/formValidation/chargeSchema'
import { ChargeModelEnum } from '~/generated/graphql'

describe('chargeSchema Graduated', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has undefined graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: undefined,
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong perUnitAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: 'a',
                  flatAmount: '1',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong flatAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: 'a',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has wrong perUnitAmount and flatAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: 'a',
                  flatAmount: 'a',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue bigger than toValue with one range', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '100',
                  toValue: '10',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has fromValue bigger than toValue with two range', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '1',
                  toValue: '10',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
                {
                  fromValue: '100',
                  toValue: '10',
                  perUnitAmount: '1',
                  flatAmount: '1',
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
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '100',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: 'a',
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
      it('has valid graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '1',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
                {
                  fromValue: '101',
                  toValue: '1000',
                  perUnitAmount: '1',
                  flatAmount: '1',
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
      it('has undefined graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
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
                  graduatedRanges: undefined,
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
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
                  graduatedRanges: [],
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong perUnitAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            values: {
              filters: [
                {
                  invoiceDisplayName: undefined,
                  values: [
                    transformFilterObjectToString('key'),
                    transformFilterObjectToString('key', 'value'),
                  ],
                  properties: {
                    graduatedRanges: [
                      {
                        fromValue: '0',
                        toValue: '100',
                        perUnitAmount: 'a',
                        flatAmount: '1',
                      },
                    ],
                  },
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong flatAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            values: {
              filters: [
                {
                  invoiceDisplayName: undefined,
                  values: [
                    transformFilterObjectToString('key'),
                    transformFilterObjectToString('key', 'value'),
                  ],
                  properties: {
                    graduatedRanges: [
                      {
                        fromValue: '0',
                        toValue: '100',
                        perUnitAmount: '1',
                        flatAmount: 'a',
                      },
                    ],
                  },
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has wrong perUnitAmount and flatAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            values: {
              filters: [
                {
                  invoiceDisplayName: undefined,
                  values: [
                    transformFilterObjectToString('key'),
                    transformFilterObjectToString('key', 'value'),
                  ],
                  properties: {
                    graduatedRanges: [
                      {
                        fromValue: '0',
                        toValue: '100',
                        perUnitAmount: 'a',
                        flatAmount: 'a',
                      },
                    ],
                  },
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
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            values: {
              filters: [
                {
                  invoiceDisplayName: undefined,
                  values: [
                    transformFilterObjectToString('key'),
                    transformFilterObjectToString('key', 'value'),
                  ],
                  properties: {
                    graduatedRanges: [
                      {
                        fromValue: '100',
                        toValue: '10',
                        perUnitAmount: '1',
                        flatAmount: '1',
                      },
                    ],
                  },
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has fromValue bigger than toValue with two range', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            values: {
              filters: [
                {
                  invoiceDisplayName: undefined,
                  values: [
                    transformFilterObjectToString('key'),
                    transformFilterObjectToString('key', 'value'),
                  ],
                  properties: {
                    graduatedRanges: [
                      {
                        fromValue: '1',
                        toValue: '10',
                        perUnitAmount: '1',
                        flatAmount: '1',
                      },
                      {
                        fromValue: '100',
                        toValue: '10',
                        perUnitAmount: '1',
                        flatAmount: '1',
                      },
                    ],
                  },
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
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            values: {
              filters: [
                {
                  invoiceDisplayName: undefined,
                  values: [
                    transformFilterObjectToString('key'),
                    transformFilterObjectToString('key', 'value'),
                  ],
                  properties: {
                    graduatedRanges: [
                      {
                        fromValue: '100',
                        toValue: '100',
                        perUnitAmount: '1',
                        flatAmount: 'a',
                      },
                    ],
                  },
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
      it('has valid graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              filters: [{ key: 'key', values: ['value'], id: '1' }],
            },
            values: {
              filters: [
                {
                  invoiceDisplayName: undefined,
                  values: [
                    transformFilterObjectToString('key'),
                    transformFilterObjectToString('key', 'value'),
                  ],
                  properties: {
                    graduatedRanges: [
                      {
                        fromValue: '1',
                        toValue: '100',
                        perUnitAmount: '1',
                        flatAmount: '1',
                      },
                      {
                        fromValue: '101',
                        toValue: '1000',
                        perUnitAmount: '1',
                        flatAmount: '1',
                      },
                    ],
                  },
                },
              ],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
  })
})

describe('fixedChargeSchema', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has undefined graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: undefined,
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong perUnitAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: 'a',
                  flatAmount: '1',
                },
              ],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong flatAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: 'a',
                },
              ],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has wrong perUnitAmount and flatAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: 'a',
                  flatAmount: 'a',
                },
              ],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue bigger than toValue with one range', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '100',
                  toValue: '10',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
              ],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has fromValue bigger than toValue with two range', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '1',
                  toValue: '10',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
                {
                  fromValue: '100',
                  toValue: '10',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
              ],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue equal than toValue', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '100',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: 'a',
                },
              ],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has empty units', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid units', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [],
            },
            units: 'a',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has 0 units', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [],
            },
            units: '0',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
    describe('valid', () => {
      it('has valid graduatedRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Graduated,
            properties: {
              graduatedRanges: [
                {
                  fromValue: '1',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
                {
                  fromValue: '101',
                  toValue: '1000',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
              ],
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
