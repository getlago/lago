import { useFormik } from 'formik'
import { useEffect } from 'react'

import {
  ACTIVE_SUBSCRIPTIONS_INTERVALS_TRANSLATION_MAP,
  ActiveSubscriptionsFilterInterval,
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

const ACTIVE_SUBSCRIPTIONS_INTERVALS = [
  ActiveSubscriptionsFilterInterval.isBetween,
  ActiveSubscriptionsFilterInterval.isEqualTo,
  ActiveSubscriptionsFilterInterval.isGreaterThan,
  ActiveSubscriptionsFilterInterval.isLessThan,
].map((interval) => ({
  value: interval,
  label: ACTIVE_SUBSCRIPTIONS_INTERVALS_TRANSLATION_MAP[interval],
}))

const FROM_INTERVALS = [
  ActiveSubscriptionsFilterInterval.isGreaterThan,
  ActiveSubscriptionsFilterInterval.isEqualTo,
  ActiveSubscriptionsFilterInterval.isBetween,
]

const TO_INTERVALS = [
  ActiveSubscriptionsFilterInterval.isLessThan,
  ActiveSubscriptionsFilterInterval.isBetween,
]

export const FiltersItemActiveSubscriptions = ({
  value = '',
  setFilterValue,
}: FiltersItemAmountProps) => {
  const { translate } = useInternationalization()

  const formikProps = useFormik({
    initialValues: {
      interval: value.split(',')?.[0],
      activeSubscriptionsFrom: value.split(',')?.[1],
      activeSubscriptionsTo: value.split(',')?.[2],
    },
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: () => {},
  })

  const showFrom = FROM_INTERVALS.includes(
    formikProps.values.interval as ActiveSubscriptionsFilterInterval,
  )
  const showTo = TO_INTERVALS.includes(
    formikProps.values.interval as ActiveSubscriptionsFilterInterval,
  )

  useEffect(() => {
    const { interval, activeSubscriptionsFrom, activeSubscriptionsTo } = formikProps.values

    const { activeSubscriptionsFrom: from, activeSubscriptionsTo: to } = parseFromToValue(
      `${interval},${activeSubscriptionsFrom},${activeSubscriptionsTo}`,
      { from: 'activeSubscriptionsFrom', to: 'activeSubscriptionsTo' },
    )

    setFilterValue?.(`${interval},${from !== null ? from : ''},${to !== null ? to : ''}`)

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formikProps.values])

  return (
    <div className="flex items-center gap-2 lg:gap-3">
      <ComboBoxField
        name="interval"
        data={ACTIVE_SUBSCRIPTIONS_INTERVALS.map((interval) => ({
          value: interval.value,
          label: translate(interval.label),
        }))}
        placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
        formikProps={formikProps}
        disableClearable={true}
      />

      {showFrom && (
        <TextInputField
          name="activeSubscriptionsFrom"
          beforeChangeFormatter={['int', 'positiveNumber']}
          type="number"
          placeholder="0"
          formikProps={formikProps}
        />
      )}

      {showFrom && showTo && <Typography className="text-grey-700">and</Typography>}

      {showTo && (
        <TextInputField
          name="activeSubscriptionsTo"
          beforeChangeFormatter={['int', 'positiveNumber']}
          type="number"
          placeholder="0"
          formikProps={formikProps}
        />
      )}
    </div>
  )
}
