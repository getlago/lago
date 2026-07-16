import { DateTime } from 'luxon'

import { DatePicker } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { Typography } from '../../Typography'
import { FiltersFormValues } from '../types'

type FiltersItemIssuingDateProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemIssuingDate = ({
  value = ',',
  setFilterValue,
}: FiltersItemIssuingDateProps) => {
  const { translate } = useInternationalization()

  return (
    <div className="flex items-center gap-2 lg:gap-3">
      <DatePicker
        showErrorInTooltip
        className="flex-1"
        onChange={(issuingDateFrom) => {
          // replace the value.split(',')[0] with the new value
          setFilterValue(
            `${DateTime.fromISO(issuingDateFrom as string).startOf('day')},${value.split(',')[1]}`,
          )
        }}
        value={value.split(',')[0]}
      />
      <Typography variant="body" color="grey700">
        <div className="block lg:hidden">-</div>
        <div className="hidden lg:block">
          {translate('text_65f8472df7593301061e27d6').toLowerCase()}
        </div>
      </Typography>
      <DatePicker
        showErrorInTooltip
        className="flex-1"
        onChange={(issuingDateTo) => {
          // replace the value.split(',')[1] with the new value
          setFilterValue(
            `${value.split(',')[0]},${DateTime.fromISO(issuingDateTo as string).endOf('day')}`,
          )
        }}
        value={value.split(',')[1]}
      />
    </div>
  )
}
