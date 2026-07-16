import { RefObject } from 'react'

import { SelectorActionItem } from '~/components/designSystem/Selector'
import { RemoveChargeWarningDialogRef } from '~/components/plans/RemoveChargeWarningDialog'
import {
  ALL_FILTER_VALUES,
  AnyChargeModel,
  chargeModelLookupTranslation,
  getIntervalTranslationKey,
} from '~/core/constants/form'
import { PlanInterval, PrivilegeValueTypeEnum } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

const BooleanTranslationKey = {
  true: 'text_65251f46339c650084ce0d57',
  false: 'text_65251f4cd55aeb004e5aa5ef',
}

export const transformFilterObjectToString = (key: string, value?: string): string => {
  return `{ "${[key]}": "${value || ALL_FILTER_VALUES}" }`
}

export const getEntitlementFormattedValue = (
  value: string | string[] | null | undefined,
  valueType: PrivilegeValueTypeEnum,
  translate: TranslateFunc,
) => {
  switch (true) {
    case valueType === PrivilegeValueTypeEnum.Boolean:
      return translate(BooleanTranslationKey[value as keyof typeof BooleanTranslationKey]) || ''
    case valueType === PrivilegeValueTypeEnum.Select && Array.isArray(value):
      return value?.join(', ') || ''
    default:
      return value
  }
}

export const mapChargeIntervalCopy = (
  interval: PlanInterval,
  forceMonthlyCharge: boolean,
): string => {
  if (forceMonthlyCharge || interval === PlanInterval.Monthly) {
    return getIntervalTranslationKey[PlanInterval.Monthly]
  } else if (interval === PlanInterval.Yearly) {
    return getIntervalTranslationKey[PlanInterval.Yearly]
  } else if (interval === PlanInterval.Semiannual) {
    return getIntervalTranslationKey[PlanInterval.Semiannual]
  } else if (interval === PlanInterval.Quarterly) {
    return getIntervalTranslationKey[PlanInterval.Quarterly]
  } else if (interval === PlanInterval.Weekly) {
    return getIntervalTranslationKey[PlanInterval.Weekly]
  }

  return ''
}

export const returnFirstDefinedArrayRatesSumAsString = (
  arr1: Array<{ rate: number }>,
  arr2?: Array<{ rate: number }>,
): string | undefined => {
  if (arr1.length) {
    return String(arr1.reduce((acc, curr) => acc + curr.rate, 0))
  }

  if (arr2?.length) {
    return String(arr2.reduce((acc, curr) => acc + curr.rate, 0))
  }

  return undefined
}

export const isPlanIntervalAnnual = (interval: PlanInterval | undefined): boolean => {
  if (!interval) return false

  return [PlanInterval.Semiannual, PlanInterval.Yearly].includes(interval)
}

export const getFormattedChargeSelectorSubtitle = ({
  chargeModel,
  code,
  translate,
}: {
  chargeModel: AnyChargeModel
  code: string
  translate: TranslateFunc
}): string => {
  return [translate(chargeModelLookupTranslation[chargeModel]), code].filter(Boolean).join(' • ')
}

export const buildChargeHoverActions = ({
  showDelete,
  showWarningOnDelete,
  onDelete,
  onEdit,
  removeChargeWarningDialogRef,
  translate,
}: {
  showDelete: boolean
  showWarningOnDelete: boolean
  onDelete: () => void
  onEdit: () => void
  removeChargeWarningDialogRef: RefObject<RemoveChargeWarningDialogRef>
  translate: TranslateFunc
}): SelectorActionItem[] => {
  const actions: SelectorActionItem[] = []

  if (showDelete) {
    const onTrashClick = (e: React.MouseEvent) => {
      e.stopPropagation()
      e.preventDefault()

      if (showWarningOnDelete) {
        removeChargeWarningDialogRef.current?.openDialog({ callback: onDelete })
      } else {
        onDelete()
      }
    }

    actions.push({
      icon: 'trash',
      tooltipCopy: translate('text_63ea0f84f400488553caa786'),
      onClick: onTrashClick,
    })
  }

  actions.push({
    icon: 'pen',
    tooltipCopy: translate('text_63e51ef4985f0ebd75c212fc'),
    onClick: onEdit,
  })

  return actions
}
