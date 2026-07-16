import type { AnyFormApi } from '@tanstack/react-form'
import { useEffect, useMemo } from 'react'

import { LocalChargeFilterInput } from '~/components/plans/types'
import { GraduatedPercentageRangeInput, PropertiesInput } from '~/generated/graphql'
import { formatAnyToValueForChargeFormArrays } from '~/hooks/plans/utils'

type RangeType = GraduatedPercentageRangeInput & { disabledDelete: boolean }
type InfoCalculationRow = {
  units: number
  rate: number
  flatAmount: number
}

type UseGraduatedPercentageChargeForm = ({
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
  infosCalculation: InfoCalculationRow[]
}

export const DEFAULT_GRADUATED_PERCENTAGE_CHARGES = [
  {
    fromValue: 0,
    toValue: 1,
    rate: undefined,
    flatAmount: undefined,
  },
  {
    fromValue: 2,
    toValue: null,
    rate: undefined,
    flatAmount: undefined,
  },
]

export const useGraduatedPercentageChargeForm: UseGraduatedPercentageChargeForm = ({
  disabled,
  propertyCursor,
  form,
  valuePointer,
}) => {
  const setFieldValue = (path: string, value: unknown) => form.setFieldValue(path, value)
  const attributeIdentifier = `${propertyCursor}.graduatedPercentageRanges`
  const graduatedPercentageRanges = useMemo(
    () => valuePointer?.graduatedPercentageRanges || [],
    [valuePointer],
  )

  useEffect(() => {
    if (!graduatedPercentageRanges.length) {
      // if no existing charge, initialize it with 2 pre-filled lines
      setFieldValue(attributeIdentifier, DEFAULT_GRADUATED_PERCENTAGE_CHARGES)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [attributeIdentifier])

  return {
    tableDatas: useMemo(
      () =>
        graduatedPercentageRanges.map((range, i) => {
          return {
            ...range,
            // First and last rows can't be deleted
            disabledDelete: [0].includes(i) || !!disabled,
          }
        }),
      [graduatedPercentageRanges, disabled],
    ),
    infosCalculation: useMemo(
      () =>
        graduatedPercentageRanges.reduce<InfoCalculationRow[]>((acc, range, i) => {
          const units =
            i === 0
              ? Number(range.toValue || 0)
              : Number(graduatedPercentageRanges[i - 1].toValue || 0)
          const rate = Number(range.rate || 0)
          const flatAmount = Number(range.flatAmount || 0)

          acc.push({
            units,
            rate,
            flatAmount,
          })

          return acc
        }, []),
      [graduatedPercentageRanges],
    ),
    addRange: () => {
      const addIndex = graduatedPercentageRanges?.length - 1 // Add before the last range
      const newgraduatedPercentageRanges = graduatedPercentageRanges.reduce<
        Partial<GraduatedPercentageRangeInput>[]
      >((acc, range, i) => {
        if (i < addIndex) {
          acc.push(range)
        } else if (i === addIndex) {
          const newToValue =
            addIndex === 0 ? 0 : Number(graduatedPercentageRanges[addIndex - 1]?.toValue || 0) + 1

          acc.push({
            fromValue: newToValue,
            toValue: newToValue + 1,
            rate: undefined,
            flatAmount: undefined,
          })
          acc.push({
            ...range,
            fromValue:
              Number(range.fromValue || 0) <= newToValue + 1
                ? newToValue + 2
                : Number(range.fromValue),
          })
        }

        return acc
      }, [])

      setFieldValue(`${propertyCursor}.graduatedPercentageRanges`, newgraduatedPercentageRanges)
    },
    handleUpdate: (rangeIndex, fieldName, value) => {
      if (fieldName !== 'toValue') {
        setFieldValue(
          `${attributeIdentifier}.${rangeIndex}.${fieldName}`,
          value !== '' ? Number(value) : value,
        )
      } else {
        const newgraduatedPercentageRanges = graduatedPercentageRanges.reduce<
          GraduatedPercentageRangeInput[]
        >((acc, range, i) => {
          if (rangeIndex === i) {
            acc.push({ ...range, toValue: Number(value || 0) })
          } else if (i > rangeIndex) {
            // fromValue should always be toValueOfPreviousRange + 1
            const { toValue } = acc[i - 1]
            const fromValue = Number(toValue || 0) + 1
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

        setFieldValue(attributeIdentifier, newgraduatedPercentageRanges)
      }
    },
    deleteRange: (rangeIndex) => {
      const newgraduatedPercentageRanges = graduatedPercentageRanges.reduce<
        GraduatedPercentageRangeInput[]
      >((acc, range, i) => {
        if (i < rangeIndex) acc.push({ ...range })
        // fromValue should always be toValueOfPreviousRange + 1
        if (i > rangeIndex) {
          const { toValue } = acc[acc.length - 1]

          acc.push({
            ...range,
            fromValue: Number(toValue || 0) + 1,
          })
        }
        return acc
      }, [])

      // Last row needs to has toValue equal to null (infinite)
      newgraduatedPercentageRanges[newgraduatedPercentageRanges.length - 1].toValue = null

      setFieldValue(attributeIdentifier, newgraduatedPercentageRanges)
    },
  }
}
