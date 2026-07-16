import { act, renderHook } from '@testing-library/react'
import { useFormik } from 'formik'

import { PlanFormInput } from '~/components/plans/types'
import { transformFilterObjectToString } from '~/components/plans/utils'
import {
  AggregationTypeEnum,
  ChargeModelEnum,
  CurrencyEnum,
  PlanInterval,
  VolumeRangeInput,
} from '~/generated/graphql'
import { DEFAULT_VOLUME_CHARGES, useVolumeChargeForm } from '~/hooks/plans/useVolumeChargeForm'

type PrepareType = {
  chargeIndex?: number
  filterIndex?: number
  disabled?: boolean
  volumeRanges?: VolumeRangeInput[]
}

const prepare = async ({
  chargeIndex = 0,
  filterIndex,
  disabled = false,
  volumeRanges = [],
}: PrepareType) => {
  const propertyType = typeof filterIndex === 'number' ? 'filters' : 'properties'

  const { result } = renderHook(() => {
    const formikProps = useFormik<PlanFormInput>({
      initialValues: {
        amountCents: 1,
        amountCurrency: CurrencyEnum.Usd,
        code: 'volume',
        interval: PlanInterval.Monthly,
        name: 'volume',
        payInAdvance: false,
        entitlements: [],
        fixedCharges: [],
        charges: [
          {
            chargeModel: ChargeModelEnum.Volume,
            billableMetric: {
              id: '1',
              aggregationType: AggregationTypeEnum.CountAgg,
              name: 'volume',
              code: 'volume',
              recurring: false,
              filters:
                propertyType === 'filters'
                  ? [{ key: 'key', values: ['value1'], id: '1' }]
                  : undefined,
            },
            properties: propertyType === 'properties' ? { volumeRanges } : undefined,
            filters:
              propertyType === 'filters'
                ? [
                    {
                      invoiceDisplayName: undefined,
                      values: [
                        transformFilterObjectToString('parent_key'),
                        transformFilterObjectToString('key', 'value'),
                      ],
                      properties: { volumeRanges },
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

    return useVolumeChargeForm({
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

describe('useVolumeChargeForm()', () => {
  describe('with properties', () => {
    describe('tableDatas', () => {
      it('returns default datas if no charges defined', async () => {
        const { result } = await prepare({ volumeRanges: [] })

        expect(result.current.tableDatas).toStrictEqual([
          { ...DEFAULT_VOLUME_CHARGES[0], disabledDelete: true },
          { ...DEFAULT_VOLUME_CHARGES[1], disabledDelete: false },
        ])
      })

      it('returns in tableDatas the given datas', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '1',
            flatAmount: '1',
            perUnitAmount: '2',
          },
          {
            fromValue: '1',
            toValue: '2',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '2',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '1',
          },
        ]
        const { result } = await prepare({
          volumeRanges,
        })

        expect(result.current.tableDatas).toStrictEqual(
          volumeRanges.map((row, i) => ({
            ...row,
            disabledDelete: [0].includes(i),
          })),
        )
      })

      it('should all be disabled if disabled props is true', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '1',
            flatAmount: '1',
            perUnitAmount: '2',
          },
          {
            fromValue: '1',
            toValue: '2',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '2',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '1',
          },
        ]
        const { result } = await prepare({
          volumeRanges,
          disabled: true,
        })

        expect(result.current.tableDatas).toStrictEqual(
          volumeRanges.map((row) => ({
            ...row,
            disabledDelete: true,
          })),
        )
      })
    })
    describe('infosCalculation', () => {
      it('returns expected results with given props', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '100',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.2',
          },
        ]
        const { result } = await prepare({
          volumeRanges,
        })

        expect(result.current.infosCalculation).toStrictEqual({
          lastRowFirstUnit: 501,
          lastRowFlatFee: 1,
          lastRowPerUnit: 0.2,
          value: 101.2,
        })
      })

      it('rounds correclty the returned value', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '10000',
            flatAmount: '',
            perUnitAmount: '1',
          },
          {
            fromValue: '10001',
            toValue: null,
            flatAmount: '',
            perUnitAmount: '0.3',
          },
        ]
        const { result } = await prepare({
          volumeRanges,
        })

        expect(result.current.infosCalculation).toStrictEqual({
          lastRowFirstUnit: 10001,
          lastRowFlatFee: 0,
          lastRowPerUnit: 0.3,
          value: 3000.3,
        })
      })
    })

    describe('addRange()', () => {
      it('should add one row in volumeRanges and update infosCalculation', async () => {
        const volumeRanges = [
          {
            toValue: '100',
            fromValue: '0',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.3',
          },
        ]
        const { result } = await prepare({
          volumeRanges,
        })

        await act(async () => await result.current.addRange())

        expect(result.current.infosCalculation).toStrictEqual({
          lastRowFirstUnit: 503,
          lastRowFlatFee: 1,
          lastRowPerUnit: 0.3,
          value: 151.9,
        })

        expect(result.current.tableDatas.length).toBe(4)
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...volumeRanges[1], disabledDelete: false },
          {
            toValue: '502',
            fromValue: '501',
            flatAmount: undefined,
            perUnitAmount: undefined,
            disabledDelete: false,
          },
          {
            toValue: null,
            fromValue: '503',
            flatAmount: volumeRanges[2].flatAmount,
            perUnitAmount: volumeRanges[2].perUnitAmount,
            disabledDelete: false,
          },
        ])
      })
    })

    describe('handleUpdate()', () => {
      it('should correctly udpate data', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '100',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.2',
          },
        ]
        const { result } = await prepare({
          volumeRanges,
        })

        await act(async () => await result.current.handleUpdate(1, 'toValue', ''))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], toValue: '0' }, disabledDelete: false },
          { ...{ ...volumeRanges[2], fromValue: '1', toValue: null }, disabledDelete: false },
        ])

        await act(async () => await result.current.handleUpdate(1, 'toValue', 30))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], toValue: '30' }, disabledDelete: false },
          { ...{ ...volumeRanges[2], fromValue: '31', toValue: null }, disabledDelete: false },
        ])
        await act(async () => await result.current.handleUpdate(1, 'toValue', 500))

        await act(async () => await result.current.handleUpdate(1, 'flatAmount', '10'))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], flatAmount: '10' }, disabledDelete: false },
          { ...volumeRanges[2], disabledDelete: false },
        ])
        await act(async () => await result.current.handleUpdate(1, 'flatAmount', '1'))

        await act(async () => await result.current.handleUpdate(1, 'fromValue', 5))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], flatAmount: '1', fromValue: 5 }, disabledDelete: false },
          { ...volumeRanges[2], disabledDelete: false },
        ])
      })
    })

    describe('deleteRange()', () => {
      it('should correctly udpate data', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '100',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.2',
          },
        ]
        const { result } = await prepare({
          volumeRanges,
        })

        expect(result.current.tableDatas.length).toBe(3)

        await act(async () => await result.current.deleteRange(1))

        expect(result.current.tableDatas.length).toBe(2)
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[2], fromValue: '101' }, disabledDelete: false },
        ])
      })
    })
  })

  describe('with filters', () => {
    describe('tableDatas', () => {
      it('returns default datas if no charges defined', async () => {
        const { result } = await prepare({
          volumeRanges: [],
          filterIndex: 0,
        })

        expect(result.current.tableDatas).toStrictEqual([
          { ...DEFAULT_VOLUME_CHARGES[0], disabledDelete: true },
          { ...DEFAULT_VOLUME_CHARGES[1], disabledDelete: false },
        ])
      })

      it('returns in tableDatas the given datas', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '1',
            flatAmount: '1',
            perUnitAmount: '2',
          },
          {
            fromValue: '1',
            toValue: '2',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '2',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '1',
          },
        ]
        const { result } = await prepare({
          filterIndex: 0,
          volumeRanges,
        })

        expect(result.current.tableDatas).toStrictEqual(
          volumeRanges.map((row, i) => ({
            ...row,
            disabledDelete: [0].includes(i),
          })),
        )
      })

      it('should all be disabled if disabled props is true', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '1',
            flatAmount: '1',
            perUnitAmount: '2',
          },
          {
            fromValue: '1',
            toValue: '2',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '2',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '1',
          },
        ]
        const { result } = await prepare({
          filterIndex: 0,
          volumeRanges,
          disabled: true,
        })

        expect(result.current.tableDatas).toStrictEqual(
          volumeRanges.map((row) => ({
            ...row,
            disabledDelete: true,
          })),
        )
      })
    })
    describe('infosCalculation', () => {
      it('returns expected results with given props', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '100',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.2',
          },
        ]
        const { result } = await prepare({
          filterIndex: 0,
          volumeRanges,
        })

        expect(result.current.infosCalculation).toStrictEqual({
          lastRowFirstUnit: 501,
          lastRowFlatFee: 1,
          lastRowPerUnit: 0.2,
          value: 101.2,
        })
      })
    })

    describe('addRange()', () => {
      it('should add one row in volumeRanges and update infosCalculation', async () => {
        const volumeRanges = [
          {
            toValue: '100',
            fromValue: '0',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.3',
          },
        ]
        const { result } = await prepare({
          filterIndex: 0,
          volumeRanges,
        })

        await act(async () => await result.current.addRange())

        expect(result.current.infosCalculation).toStrictEqual({
          lastRowFirstUnit: 503,
          lastRowFlatFee: 1,
          lastRowPerUnit: 0.3,
          value: 151.9,
        })

        expect(result.current.tableDatas.length).toBe(4)
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...volumeRanges[1], disabledDelete: false },
          {
            toValue: '502',
            fromValue: '501',
            flatAmount: undefined,
            perUnitAmount: undefined,
            disabledDelete: false,
          },
          {
            toValue: null,
            fromValue: '503',
            flatAmount: volumeRanges[2].flatAmount,
            perUnitAmount: volumeRanges[2].perUnitAmount,
            disabledDelete: false,
          },
        ])
      })
    })

    describe('handleUpdate()', () => {
      it('should correctly udpate data', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '100',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.2',
          },
        ]
        const { result } = await prepare({
          filterIndex: 0,
          volumeRanges,
        })

        await act(async () => await result.current.handleUpdate(1, 'toValue', ''))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], toValue: '0' }, disabledDelete: false },
          { ...{ ...volumeRanges[2], fromValue: '1', toValue: null }, disabledDelete: false },
        ])

        await act(async () => await result.current.handleUpdate(1, 'toValue', 30))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], toValue: '30' }, disabledDelete: false },
          { ...{ ...volumeRanges[2], fromValue: '31', toValue: null }, disabledDelete: false },
        ])
        await act(async () => await result.current.handleUpdate(1, 'toValue', 500))

        await act(async () => await result.current.handleUpdate(1, 'flatAmount', '10'))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], flatAmount: '10' }, disabledDelete: false },
          { ...volumeRanges[2], disabledDelete: false },
        ])
        await act(async () => await result.current.handleUpdate(1, 'flatAmount', '1'))

        await act(async () => await result.current.handleUpdate(1, 'fromValue', 5))
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[1], flatAmount: '1', fromValue: 5 }, disabledDelete: false },
          { ...volumeRanges[2], disabledDelete: false },
        ])
      })
    })

    describe('deleteRange()', () => {
      it('should correctly udpate data', async () => {
        const volumeRanges = [
          {
            fromValue: '0',
            toValue: '100',
            flatAmount: '1',
            perUnitAmount: '1',
          },
          {
            fromValue: '101',
            toValue: '500',
            flatAmount: '1',
            perUnitAmount: '0.9',
          },
          {
            fromValue: '501',
            toValue: null,
            flatAmount: '1',
            perUnitAmount: '0.2',
          },
        ]
        const { result } = await prepare({
          filterIndex: 0,
          volumeRanges,
        })

        expect(result.current.tableDatas.length).toBe(3)

        await act(async () => await result.current.deleteRange(1))

        expect(result.current.tableDatas.length).toBe(2)
        expect(result.current.tableDatas).toStrictEqual([
          { ...volumeRanges[0], disabledDelete: true },
          { ...{ ...volumeRanges[2], fromValue: '101' }, disabledDelete: false },
        ])
      })
    })
  })
})
