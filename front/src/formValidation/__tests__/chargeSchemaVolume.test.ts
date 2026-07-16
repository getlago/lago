import { transformFilterObjectToString } from '~/components/plans/utils'
import { chargeSchema, fixedChargeSchema } from '~/formValidation/chargeSchema'
import { ChargeModelEnum, FixedChargeChargeModelEnum } from '~/generated/graphql'

describe('chargeSchema Volume', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has undefined volumeRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: undefined,
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty volumeRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [],
            },
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong perUnitAmount', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
      it('has valid volumeRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
      it('has undefined volumeRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
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
                  volumeRanges: undefined,
                },
              },
            ],
          },
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty volumeRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
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
                  volumeRanges: [],
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
            chargeModel: ChargeModelEnum.Volume,
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
                    volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
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
                    volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
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
                    volumeRanges: [
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

      it('has fromValue bigger than toValue with one range', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
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
                    volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
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
                    volumeRanges: [
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
            chargeModel: ChargeModelEnum.Volume,
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
                    volumeRanges: [
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
      it('has valid volumeRange', () => {
        const values = [
          {
            chargeModel: ChargeModelEnum.Volume,
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
                  volumeRanges: [
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
        ]
        const result = chargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
    })
  })
})

describe('fixedChargeSchema Volume', () => {
  describe('properties', () => {
    describe('invalid', () => {
      it('has undefined volumeRange', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: undefined,
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has empty volumeRange', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [],
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong perUnitAmount', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: 'a',
                  flatAmount: '1',
                },
              ],
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong flatAmount', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: 'a',
                },
              ],
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has wrong perUnitAmount and flatAmount', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
                {
                  fromValue: '0',
                  toValue: '100',
                  perUnitAmount: 'a',
                  flatAmount: 'a',
                },
              ],
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue bigger than toValue with one range', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
                {
                  fromValue: '100',
                  toValue: '10',
                  perUnitAmount: '1',
                  flatAmount: '1',
                },
              ],
            },
            units: '10',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has fromValue bigger than toValue with two range', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
                {
                  fromValue: '100',
                  toValue: '100',
                  perUnitAmount: '1',
                  flatAmount: 'a',
                },
              ],
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
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [],
            },
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })

      it('has invalid units', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [],
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
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [],
            },
            units: '0',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })

    describe('valid', () => {
      it('has valid volumeRange and units', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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

      it('has valid volumeRange and small units', () => {
        const values = [
          {
            chargeModel: FixedChargeChargeModelEnum.Volume,
            properties: {
              volumeRanges: [
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
            units: '0.000001',
          },
        ]
        const result = fixedChargeSchema.isValidSync(values)

        expect(result).toBeTruthy()
      })
    })
  })
})
