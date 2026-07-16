import { Icon, IconColor, IconName } from 'lago-design-system'
import { FC } from 'react'

import { Locale, TranslateData } from '~/core/translations'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { tw } from '~/styles/utils'

import { Typography, TypographyColor } from './Typography'

export enum StatusType {
  success = 'success',
  warning = 'warning',
  outline = 'outline',
  default = 'default',
  danger = 'danger',
  disabled = 'disabled',
}

type StatusLabelSuccess =
  'succeeded' | 'finalized' | 'active' | 'pay' | 'available' | 'refunded' | 'delivered' | number
type StatusLabelWarning = 'failed' | 'incomplete'
type StatusLabelOutline = 'draft'
type StatusLabelDefault = 'downgrade' | 'scheduled' | 'pending' | 'toPay' | 'processing' | 'n/a'
type StatusLabelDanger =
  | 'disputed'
  | 'disputeLost'
  | 'disputeLostOn'
  | 'terminated'
  | 'consumed'
  | 'voided'
  | 'overdue'
  | 'canceled'
  | 'failed'
  | number

type StatusLabelDisabled = 'voided'

type StatusLabel =
  | StatusLabelSuccess
  | StatusLabelWarning
  | StatusLabelOutline
  | StatusLabelDefault
  | StatusLabelDanger
  | StatusLabelDisabled

const statusLabelMapping: Record<StatusLabel, string> = {
  succeeded: 'text_63e27c56dfe64b846474ef4d',
  finalized: 'text_65269c2e471133226211fd74',
  active: 'text_624efab67eb2570101d1180e',
  available: 'text_637655cb50f04bf1c8379d0c',
  refunded: 'text_637656ef3d876b0269edc79d',
  failed: 'text_637656ef3d876b0269edc7a1',
  draft: 'text_63ac86d797f728a87b2f9f91',
  pending: 'text_62da6db136909f52c2704c30',
  incomplete: 'text_1779882021466dr07sleoyk9',
  disputed: 'text_668fe99c939c8800dfeb504e',
  disputeLostOn: 'text_66141e30699a0631f0b2ed2c',
  disputeLost: 'text_66141e30699a0631f0b2ec9c',
  terminated: 'text_624efab67eb2570101d11826',
  consumed: 'text_6376641a2a9c70fff5bddcd1',
  voided: 'text_6376641a2a9c70fff5bddcd5',
  overdue: 'text_666c5b12fea4aa1e1b26bf55',
  downgrade: 'text_1736972452609qdjngeuqsz0',
  scheduled: 'text_1736972452609g2v8mzgvi2t',
  processing: 'text_1740135074392314rc3ldv02',
  canceled: 'text_17429854230668s8zhn9ujq6',
  delivered: 'text_1746621029319goh9pr7g67d',
  ['n/a']: 'text_1754570508183hxl33n573yi',
  // These keys below are displayed in the customer portal
  // Hence they must be translated in all available languages
  pay: 'text_6419c64eace749372fc72b54',
  toPay: 'text_6419c64eace749372fc72b44',
}

export type StatusProps = {
  labelVariables?: TranslateData
  locale?: Locale
  endIcon?: IconName
  type: StatusType
  label: StatusLabel | string
  'data-test'?: string
}

type StatusConfig = Record<
  StatusType,
  {
    color: TypographyColor
    iconColor: IconColor
    backgroundColor: string
    borderColor: string
  }
>

const STATUS_CONFIG: StatusConfig = {
  success: {
    color: 'success600',
    iconColor: 'success',
    backgroundColor: 'bg-green-100',
    borderColor: 'outline-green-200',
  },
  default: {
    color: 'grey700',
    iconColor: 'black',
    backgroundColor: 'bg-grey-100',
    borderColor: 'outline-grey-400',
  },
  outline: {
    color: 'grey600',
    iconColor: 'dark',
    backgroundColor: 'bg-white',
    borderColor: 'outline-grey-400',
  },
  warning: {
    color: 'warning700',
    iconColor: 'warning',
    backgroundColor: 'bg-yellow-100',
    borderColor: 'outline-yellow-300',
  },
  danger: {
    color: 'danger600',
    iconColor: 'error',
    backgroundColor: 'bg-red-100',
    borderColor: 'outline-red-200',
  },
  disabled: {
    color: 'grey500',
    iconColor: 'disabled',
    backgroundColor: 'bg-grey-100',
    borderColor: 'outline-grey-400',
  },
}

export const Status: FC<StatusProps> = ({
  type,
  label,
  labelVariables,
  locale = 'en',
  endIcon,
  'data-test': dataTest,
}) => {
  const { translateWithContextualLocal: translate } = useContextualLocale(locale)

  const config = STATUS_CONFIG[type ?? 'default']
  const checkIsLabelStatus = (labelToTest: StatusProps['label']): labelToTest is StatusLabel => {
    return !!labelToTest && labelToTest in statusLabelMapping
  }

  return (
    <div
      className={tw(
        'flex h-fit min-h-8 w-fit items-center gap-2 rounded-lg px-2 outline outline-1 -outline-offset-1',
        config.backgroundColor,
        config.borderColor,
      )}
      data-test={dataTest || 'status'}
    >
      <Typography variant="captionHl" color={config.color} noWrap>
        {checkIsLabelStatus(label)
          ? translate(statusLabelMapping[label], labelVariables ?? {})
          : label}
      </Typography>
      {endIcon && <Icon name={endIcon} size="medium" color={config.iconColor} />}
    </div>
  )
}
