import { DateTime } from 'luxon'

import { ALL_ADJUSTMENT_VALUES, ALL_ANCHOR_VALUES } from '~/core/constants/issuingDatePolicy'
import { DateFormat, intlFormatDateTime } from '~/core/timezone'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const INVOICE_ISSUING_DATE_ANCHOR_OPTIONS_TRANSLATIONS: Record<
  (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES],
  string
> = {
  [ALL_ANCHOR_VALUES.CurrentPeriodEnd]: 'text_1763407743132mchch2fgr8s',
  [ALL_ANCHOR_VALUES.NextPeriodStart]: 'text_1763407743132k9nlpbl5hj6',
}

const INVOICE_ISSUING_DATE_ADJUSTMENT_OPTIONS_TRANSLATIONS: Record<
  (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES],
  string
> = {
  [ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate]: 'text_1763407743132izf3n3zshx5',
  [ALL_ADJUSTMENT_VALUES.KeepAnchor]: 'text_1763407743132x933206zqdo',
}

type IssuingDateComputationParams = {
  finalizationDate: DateTime
  periodEndDate: DateTime
}

type ExpectedIssuingDateMatrix = Record<
  (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES],
  Record<
    (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES],
    (params: IssuingDateComputationParams) => DateTime
  >
>

const EXPECTED_ISSUING_DATE_MATRIX: ExpectedIssuingDateMatrix = {
  [ALL_ANCHOR_VALUES.CurrentPeriodEnd]: {
    [ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate]: ({ finalizationDate }) => finalizationDate,
    [ALL_ADJUSTMENT_VALUES.KeepAnchor]: ({ periodEndDate }) => periodEndDate,
  },
  [ALL_ANCHOR_VALUES.NextPeriodStart]: {
    [ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate]: ({ finalizationDate }) =>
      finalizationDate.plus({ days: 1 }),
    [ALL_ADJUSTMENT_VALUES.KeepAnchor]: ({ periodEndDate }) => periodEndDate.plus({ days: 1 }),
  },
}

type GetIssuingDateInfoForAlertProps = {
  gracePeriod: number | undefined
  subscriptionInvoiceIssuingDateAdjustment:
    (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES] | undefined | null
  subscriptionInvoiceIssuingDateAnchor:
    (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES] | undefined | null
}

const getExpectedIssuingDateFromMatrix = ({
  periodEndDate,
  finalizationDate,
  subscriptionInvoiceIssuingDateAdjustment,
  subscriptionInvoiceIssuingDateAnchor,
}: {
  periodEndDate: DateTime
  finalizationDate: DateTime
  subscriptionInvoiceIssuingDateAdjustment:
    (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES] | undefined | null
  subscriptionInvoiceIssuingDateAnchor:
    (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES] | undefined | null
}): DateTime => {
  const normalizedAdjustment =
    subscriptionInvoiceIssuingDateAdjustment ?? ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate
  const normalizedAnchor = subscriptionInvoiceIssuingDateAnchor ?? ALL_ANCHOR_VALUES.NextPeriodStart

  const dateCalculator = EXPECTED_ISSUING_DATE_MATRIX[normalizedAnchor]?.[normalizedAdjustment]

  if (!dateCalculator) {
    return periodEndDate
  }

  return dateCalculator({ finalizationDate, periodEndDate })
}

const toIsoOrThrow = (date: DateTime): string => {
  const isoString = date.toISO()

  if (!isoString) {
    throw new Error('Invalid date provided to toIsoOrThrow')
  }

  return isoString
}

type UseIssuingDatePolicyProps = () => {
  adjustmentComboboxData: {
    label: string
    value: (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES]
  }[]
  anchorComboboxData: {
    label: string
    value: (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES]
  }[]
  getIssuingDateInfoForAlert: (props: GetIssuingDateInfoForAlertProps) => {
    descriptionCopyAsHtml: string
    expectedIssuingDateCopy: string
  }
}

export const useIssuingDatePolicy: UseIssuingDatePolicyProps = () => {
  const { translate } = useInternationalization()

  const anchorComboboxData = [
    {
      label: translate(
        INVOICE_ISSUING_DATE_ANCHOR_OPTIONS_TRANSLATIONS[ALL_ANCHOR_VALUES.CurrentPeriodEnd],
      ),
      value: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
      description: translate('text_1763418788157c3on0ci6osi'),
    },
    {
      label: translate(
        INVOICE_ISSUING_DATE_ANCHOR_OPTIONS_TRANSLATIONS[ALL_ANCHOR_VALUES.NextPeriodStart],
      ),
      value: ALL_ANCHOR_VALUES.NextPeriodStart,
      description: translate('text_17634187881589jfd2riv1pr'),
    },
  ]

  const adjustmentComboboxData = [
    {
      label: translate(
        INVOICE_ISSUING_DATE_ADJUSTMENT_OPTIONS_TRANSLATIONS[ALL_ADJUSTMENT_VALUES.KeepAnchor],
      ),
      value: ALL_ADJUSTMENT_VALUES.KeepAnchor,
      description: translate('text_17634187881585jurckihq30'),
    },
    {
      label: translate(
        INVOICE_ISSUING_DATE_ADJUSTMENT_OPTIONS_TRANSLATIONS[
          ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate
        ],
      ),
      value: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
      description: translate('text_1763418788158j8nzvbz85yj'),
    },
  ]

  const formatDate = (date: DateTime): string =>
    intlFormatDateTime(toIsoOrThrow(date), { formatDate: DateFormat.DATE_MED_SHORT }).date

  const getIssuingDateInfoForAlert = ({
    gracePeriod,
    subscriptionInvoiceIssuingDateAdjustment,
    subscriptionInvoiceIssuingDateAnchor,
  }: GetIssuingDateInfoForAlertProps) => {
    const periodStartDate = DateTime.local().startOf('year').startOf('month').startOf('day')
    const periodEndDate = periodStartDate.endOf('month')
    const finalizationDate = !!gracePeriod
      ? periodEndDate.plus({ days: gracePeriod })
      : periodEndDate
    const expectedIssuingDate = getExpectedIssuingDateFromMatrix({
      periodEndDate,
      finalizationDate,
      subscriptionInvoiceIssuingDateAdjustment,
      subscriptionInvoiceIssuingDateAnchor,
    })

    const descriptionCopyAsHtml = translate('text_1763407530094k0lsbmuh6a1', {
      periodStartDate: formatDate(periodStartDate),
      periodEndDate: formatDate(periodEndDate),
      gracePeriod: gracePeriod || 0,
      expectedIssuingDate: formatDate(expectedIssuingDate),
    })

    const expectedIssuingDateCopy = translate('text_1763407530094w9q8pwx1m0j', {
      expectedIssuingDate: formatDate(expectedIssuingDate),
    })

    return {
      descriptionCopyAsHtml,
      expectedIssuingDateCopy,
    }
  }

  return {
    adjustmentComboboxData,
    anchorComboboxData,
    getIssuingDateInfoForAlert,
  }
}
