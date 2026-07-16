import { useFormik } from 'formik'
import { useEffect } from 'react'

import {
  AMOUNT_INTERVALS_TRANSLATION_MAP,
  AmountFilterInterval,
  FiltersFormValues,
} from '~/components/designSystem/Filters/types'
import { parseFromToValue } from '~/components/designSystem/Filters/utils'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBoxField, TextInputField } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type FiltersItemAmountProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

const AMOUNT_INTERVALS = [
  AmountFilterInterval.isBetween,
  AmountFilterInterval.isEqualTo,
  AmountFilterInterval.isUpTo,
  AmountFilterInterval.isAtLeast,
].map((interval) => ({ value: interval, label: AMOUNT_INTERVALS_TRANSLATION_MAP[interval] }))

const FROM_INTERVALS = [
  AmountFilterInterval.isAtLeast,
  AmountFilterInterval.isEqualTo,
  AmountFilterInterval.isBetween,
]

const TO_INTERVALS = [AmountFilterInterval.isUpTo, AmountFilterInterval.isBetween]

export const FiltersItemAmount = ({ value = '', setFilterValue }: FiltersItemAmountProps) => {
  const { translate } = useInternationalization()

  const formikProps = useFormik({
    initialValues: {
      interval: value.split(',')?.[0],
      amountFrom: value.split(',')?.[1],
      amountTo: value.split(',')?.[2],
    },
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: () => {},
  })

  const showFrom = FROM_INTERVALS.includes(formikProps.values.interval as AmountFilterInterval)
  const showTo = TO_INTERVALS.includes(formikProps.values.interval as AmountFilterInterval)

  useEffect(() => {
    const { interval, amountFrom, amountTo } = formikProps.values

    const { amountFrom: from, amountTo: to } = parseFromToValue(
      `${interval},${amountFrom},${amountTo}`,
      { from: 'amountFrom', to: 'amountTo' },
    )

    setFilterValue?.(`${interval},${from !== null ? from : ''},${to !== null ? to : ''}`)

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formikProps.values.interval, formikProps.values.amountFrom, formikProps.values.amountTo])

  return (
    <div className="flex items-center gap-2 lg:gap-3">
      <ComboBoxField
        name="interval"
        data={AMOUNT_INTERVALS.map((interval) => ({
          value: interval.value,
          label: translate(interval.label),
        }))}
        placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
        formikProps={formikProps}
        disableClearable={true}
      />

      {showFrom && (
        <TextInputField
          name="amountFrom"
          beforeChangeFormatter={['chargeDecimal']}
          type="number"
          placeholder="0"
          formikProps={formikProps}
        />
      )}

      {showFrom && showTo && <Typography className="text-grey-700">and</Typography>}

      {showTo && (
        <TextInputField
          name="amountTo"
          beforeChangeFormatter={['chargeDecimal']}
          type="number"
          placeholder="0"
          formikProps={formikProps}
        />
      )}
    </div>
  )
}
