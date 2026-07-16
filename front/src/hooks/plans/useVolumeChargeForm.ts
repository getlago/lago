import type { AnyFormApi } from '@tanstack/react-form'
import Decimal from 'decimal.js'
import { useEffect, useMemo } from 'react'

import { LocalChargeFilterInput } from '~/components/plans/types'
import { ONE_TIER_EXAMPLE_UNITS } from '~/core/constants/form'
import { PropertiesInput, VolumeRangeInput } from '~/generated/graphql'
import { formatAnyToValueForChargeFormArrays } from '~/hooks/plans/utils'

export const DEFAULT_VOLUME_CHARGES = [
  {
    fromValue: '0',
    toValue: '1',
    flatAmount: undefined,
    perUnitAmount: undefined,
  },
  {
    fromValue: '2',
    toValue: null,
    flatAmount: undefined,
    perUnitAmount: undefined,
  },
]

type RangeType = VolumeRangeInput & { disabledDelete: boolean }
type InfoCalculationRow = {
  lastRowFirstUnit: number
  lastRowPerUnit: number
  lastRowFlatFee: number
  value: number
}

type UseVolumeChargeForm = ({
  disabled,
  propertyCursor,
  form,
  valuePointer,
}: {
  disabled?: boolean
  propertyCursor: string
  form: Pick<AnyFormApi, 'setFieldValue'>
  valuePointer: PropertiesInput | LocalChargeFilterInput['properties'] | undefined
}) => {
  handleUpdate: (rangeIndex: number, fieldName: string, value?: number | string) => void
  addRange: () => void
  deleteRange: (rangeIndex: number) => void
  tableDatas: RangeType[]
  infosCalculation: InfoCalculationRow
}

export const useVolumeChargeForm: UseVolumeChargeForm = ({
  disabled,
  propertyCursor,
  form,
  valuePointer,
}) => {
  const setFieldValue = (path: string, value: unknown) => form.setFieldValue(path, value)
  const attributeIdentifier = `${propertyCursor}.volumeRanges`
  const volumeRanges = useMemo(() => valuePointer?.volumeRanges || [], [valuePointer])

  useEffect(() => {
    if (!volumeRanges.length) {
      // if no existing charge, initialize it with 2 pre-filled lines
      setFieldValue(attributeIdentifier, DEFAULT_VOLUME_CHARGES)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [attributeIdentifier])

  return {
    tableDatas: useMemo(
      () =>
        volumeRanges.map((range, i) => {
          return {
            ...range,
            // First and last rows can't be deleted
            disabledDelete: [0].includes(i) || !!disabled,
          }
        }),
      [volumeRanges, disabled],
    ),
    infosCalculation: useMemo(() => {
      const lastRow = volumeRanges[volumeRanges.length - 1]
      const lastRowFirstUnit =
        volumeRanges.length === 1 ? ONE_TIER_EXAMPLE_UNITS : Number(lastRow?.fromValue || 0)
      const lastRowPerUnit = Number(lastRow?.perUnitAmount || 0)
      const lastRowFlatFee = Number(lastRow?.flatAmount || 0)
      const value = new Decimal(lastRowFirstUnit).mul(lastRowPerUnit).add(lastRowFlatFee).toNumber()

      return { lastRowFirstUnit, lastRowPerUnit, lastRowFlatFee, value }
    }, [volumeRanges]),

    addRange: () => {
      const addIndex = volumeRanges?.length - 1 // Add before the last range
      const newVolumeRanges = volumeRanges.reduce<Partial<VolumeRangeInput>[]>((acc, range, i) => {
        if (i < addIndex) {
          acc.push(range)
        } else if (i === addIndex) {
          const newToValue =
            addIndex === 0 ? '0' : String(Number(volumeRanges[addIndex - 1]?.toValue || 0) + 1)

          acc.push({
            fromValue: newToValue,
            toValue: String(Number(newToValue) + 1),
            flatAmount: undefined,
            perUnitAmount: undefined,
          })
          acc.push({
            ...range,
            fromValue:
              Number(range.fromValue) <= Number(newToValue) + 1
                ? String(Number(newToValue) + 2)
                : String(range.fromValue),
          })
        }

        return acc
      }, [])

      setFieldValue(`${propertyCursor}.volumeRanges`, newVolumeRanges)
    },
    handleUpdate: (rangeIndex, fieldName, value) => {
      if (fieldName !== 'toValue') {
        setFieldValue(`${attributeIdentifier}.${rangeIndex}.${fieldName}`, value)
      } else {
        const newVolumeRanges = volumeRanges.reduce<VolumeRangeInput[]>((acc, range, i) => {
          if (rangeIndex === i) {
            acc.push({ ...range, toValue: String(Number(value || 0)) })
          } else if (i > rangeIndex) {
            // fromValue should always be toValueOfPreviousRange + 1
            const { toValue } = acc[i - 1]
            const fromValue = String(Number(toValue || 0) + 1)
            const formattedToValue = formatAnyToValueForChargeFormArrays(range.toValue, fromValue)

            acc.push({
              ...range,
              fromValue,
              toValue: formattedToValue,
            })
          } else {
            acc.push(range)
          }

          return acc
        }, [])

        setFieldValue(attributeIdentifier, newVolumeRanges)
      }
    },
    deleteRange: (rangeIndex) => {
      const newVolumeRanges = volumeRanges.reduce<VolumeRangeInput[]>((acc, range, i) => {
        if (i < rangeIndex) acc.push({ ...range })
        // fromValue should always be toValueOfPreviousRange + 1
        if (i > rangeIndex) {
          const { toValue } = acc[acc.length - 1]

          acc.push({
            ...range,
            fromValue: String(Number(toValue || 0) + 1),
          })
        }
        return acc
      }, [])

      // Last row needs to has toValue null
      newVolumeRanges[newVolumeRanges.length - 1].toValue = null

      setFieldValue(attributeIdentifier, newVolumeRanges)
    },
  }
}
