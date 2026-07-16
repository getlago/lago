import { act, renderHook } from '@testing-library/react'
import { useFormik } from 'formik'

import { PlanFormInput } from '~/components/plans/types'
import { transformFilterObjectToString } from '~/components/plans/utils'
import {
  AggregationTypeEnum,
  ChargeModelEnum,
  CurrencyEnum,
  GraduatedRangeInput,
  PlanInterval,
} from '~/generated/graphql'
import {
  DEFAULT_GRADUATED_PERCENTAGE_CHARGES,
  useGraduatedPercentageChargeForm,
} from '~/hooks/plans/useGraduatedPercentageChargeForm'

type PrepareType = {
  chargeIndex?: number
  filterIndex?: number
  disabled?: boolean
  graduatedRanges?: GraduatedRangeInput[]
}

const prepare = async ({
  chargeIndex = 0,
  filterIndex,
  disabled = false,
  graduatedRanges = [],
}: PrepareType) => {
  const propertyType = typeof filterIndex === 'number' ? 'filters' : 'properties'

  const { result } = renderHook(() => {
    const formikProps = useFormik<PlanFormInput>({
      initialValues: {
        amountCents: 1,
        amountCurrency: CurrencyEnum.Usd,
        code: 'graduated',
        interval: PlanInterval.Monthly,
        name: 'graduated',
        payInAdvance: false,
        entitlements: [],
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Graduated,
            billableMetric: {
              id: '1',
              name: 'graduated',
              aggregationType: AggregationTypeEnum.CountAgg,
              recurring: false,
              code: 'graduated',
              filters:
                propertyType === 'filters'
                  ? [{ key: 'key', values: ['value1'], id: '1' }]
                  : undefined,
            },
            properties: propertyType === 'properties' ? { graduatedRanges } : undefined,
            filters:
              propertyType === 'filters'
                ? [
                    {
                      invoiceDisplayName: undefined,
                      values: [
                        transformFilterObjectToString('parent_key'),
                        transformFilterObjectToString('key', 'value'),
                      ],
                      properties: { graduatedRanges },
                    },
                  ]
                : undefined,
          },
        ],
      },
      onSubmit: () => {},
    })
    const localCharge = formikProps.values.charges[chargeIndex]
    const propertyCursor =
      propertyType === 'filters' ? `filters.${filterIndex}.properties` : 'properties'
    const valuePointer =
      propertyType === 'filters'
        ? localCharge?.filters?.[filterIndex || 0].properties
        : localCharge?.properties

    const wrappedSetFieldValue = (path: string, value: unknown) => {
      formikProps.setFieldValue(`charges.${chargeIndex}.${path}`, value)
    }

    // Create a mock form object that bridges to formik
    const mockForm = {
      setFieldValue: (path: string, value: unknown) => wrappedSetFieldValue(path, value),
    }

    return useGraduatedPercentageChargeForm({
      disabled,
      propertyCursor,
      form: mockForm,
      valuePointer,
    })
  })

  // Needed to fix warning about useEffect hook being re-rendering the renderHook test component
  // It makes the result being a Promise
  await act(() => Promise.resolve())

  return { result }
}

describe('useGraduatedRange()', () => {
  describe('with properties', () => {
    describe('tableDatas', () => {
      it('returns default datas if no charges defined', async () => {
        const { result } = await prepare({})

        expect(result.current.tableDatas).toStrictEqual([
          { ...DEFAULT_GRADUATED_PERCENTAGE_CHARGES[0], disabledDelete: true },
          { ...DEFAULT_GRADUATED_PERCENTAGE_CHARGES[1], disabledDelete: false },
        ])

        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
        ])
      })

      it('should add empty line with good calculation', async () => {
        const { result } = await prepare({})

        await act(async () => await result.current.addRange())

        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 1,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 2,
            toValue: 3,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
          {
            fromValue: 4,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 3,
            rate: 0,
            flatAmount: 0,
          },
        ])
      })

      it('should handle update of row data and calculation', async () => {
        const { result } = await prepare({})

        await act(async () => await result.current.handleUpdate(0, 'flatAmount', '4'))

        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 1,
            flatAmount: 4,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 2,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])

        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 4,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
        ])
        await act(async () => await result.current.addRange())
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 4,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 3,
            rate: 0,
            flatAmount: 0,
          },
        ])
        await act(async () => await result.current.handleUpdate(1, 'flatAmount', '9'))
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 4,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 9,
          },
          {
            units: 3,
            rate: 0,
            flatAmount: 0,
          },
        ])
      })

      it('should handle update of "toValue" correctly', async () => {
        const { result } = await prepare({})

        await act(async () => await result.current.handleUpdate(0, 'toValue', 4))

        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 4,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 5,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
        ])

        await act(async () => await result.current.addRange())
        await act(async () => await result.current.handleUpdate(1, 'toValue', 8))
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 8,
            rate: 0,
            flatAmount: 0,
          },
        ])
      })

      it('should delete correcly a range', async () => {
        const { result } = await prepare({})

        await act(async () => await result.current.addRange())
        expect(result.current.tableDatas.length).toBe(3)
        await act(async () => await result.current.handleUpdate(0, 'toValue', 4))
        await act(async () => await result.current.deleteRange(1))
        expect(result.current.tableDatas.length).toBe(2)
        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 4,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 5,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])
      })

      it('should delete last row and add new one correctly from default state', async () => {
        const { result } = await prepare({})

        await act(async () => await result.current.deleteRange(1))
        expect(result.current.tableDatas).toStrictEqual([
          { ...DEFAULT_GRADUATED_PERCENTAGE_CHARGES[0], toValue: null, disabledDelete: true },
        ])

        await act(async () => await result.current.addRange())

        expect(result.current.tableDatas).toStrictEqual([
          { ...DEFAULT_GRADUATED_PERCENTAGE_CHARGES[0], disabledDelete: true },
          { ...DEFAULT_GRADUATED_PERCENTAGE_CHARGES[1], disabledDelete: false },
        ])
      })
    })
  })

  describe('with filters', () => {
    describe('tableDatas', () => {
      it('returns default datas if no charges defined', async () => {
        const { result } = await prepare({ filterIndex: 0 })

        expect(result.current.tableDatas).toStrictEqual([
          { ...DEFAULT_GRADUATED_PERCENTAGE_CHARGES[0], disabledDelete: true },
          { ...DEFAULT_GRADUATED_PERCENTAGE_CHARGES[1], disabledDelete: false },
        ])

        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
        ])
      })

      it('should add empty line with good calculation', async () => {
        const { result } = await prepare({ filterIndex: 0 })

        await act(async () => await result.current.addRange())

        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 1,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 2,
            toValue: 3,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
          {
            fromValue: 4,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 3,
            rate: 0,
            flatAmount: 0,
          },
        ])
      })

      it('should handle update of row data and calculation', async () => {
        const { result } = await prepare({ filterIndex: 0 })

        await act(async () => await result.current.handleUpdate(0, 'flatAmount', '4'))

        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 1,
            flatAmount: 4,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 2,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])

        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 4,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
        ])
        await act(async () => await result.current.addRange())
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 4,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 0,
          },
          {
            flatAmount: 0,
            rate: 0,
            units: 3,
          },
        ])
        await act(async () => await result.current.handleUpdate(1, 'flatAmount', '9'))
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 1,
            rate: 0,
            flatAmount: 4,
          },
          {
            units: 1,
            rate: 0,
            flatAmount: 9,
          },
          {
            flatAmount: 0,
            rate: 0,
            units: 3,
          },
        ])
      })

      it('should handle update of "toValue" correctly', async () => {
        const { result } = await prepare({ filterIndex: 0 })

        await act(async () => await result.current.handleUpdate(0, 'toValue', 4))

        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 4,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 5,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
        ])

        await act(async () => await result.current.addRange())
        await act(async () => await result.current.handleUpdate(1, 'toValue', 8))
        expect(result.current.infosCalculation).toStrictEqual([
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 4,
            rate: 0,
            flatAmount: 0,
          },
          {
            units: 8,
            rate: 0,
            flatAmount: 0,
          },
        ])
      })

      it('should delete correcly a range', async () => {
        const { result } = await prepare({ filterIndex: 0 })

        await act(async () => await result.current.addRange())
        expect(result.current.tableDatas.length).toBe(3)
        await act(async () => await result.current.handleUpdate(0, 'toValue', 4))
        await act(async () => await result.current.deleteRange(1))
        expect(result.current.tableDatas.length).toBe(2)
        expect(result.current.tableDatas).toStrictEqual([
          {
            fromValue: 0,
            toValue: 4,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: true,
          },
          {
            fromValue: 5,
            toValue: null,
            flatAmount: undefined,
            rate: undefined,
            disabledDelete: false,
          },
        ])
      })
    })
  })
})
