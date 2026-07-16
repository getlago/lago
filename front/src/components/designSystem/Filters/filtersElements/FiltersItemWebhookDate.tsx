import { DateTime } from 'luxon'

import { DatePicker } from '~/components/form'
import { getTimezoneConfig } from '~/core/timezone'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { Typography } from '../../Typography'
import { FiltersFormValues } from '../types'

type FiltersItemWebhookDateProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemWebhookDate = ({
  value = ',',
  setFilterValue,
}: FiltersItemWebhookDateProps) => {
  const { translate } = useInternationalization()
  const { timezone } = useOrganizationInfos()
  const defaultZone = getTimezoneConfig(timezone).name

  const [givenValueFrom, givenValueTo] = value.split(',')

  const handleFromChange = (dateFrom: unknown) => {
    const from = DateTime.fromISO(dateFrom as string).startOf('day')

    // If fromDate > toDate, adjust toDate to end of fromDate day
    if (givenValueTo) {
      const to = DateTime.fromISO(givenValueTo)

      if (from > to) {
        setFilterValue(`${from.toISO()},${from.endOf('day').toISO()}`)
        return
      }
    }

    setFilterValue(`${from.toISO()},${givenValueTo}`)
  }

  const handleToChange = (dateTo: unknown) => {
    const to = DateTime.fromISO(dateTo as string).endOf('day')

    // If toDate < fromDate, adjust fromDate to start of toDate day
    if (givenValueFrom) {
      const from = DateTime.fromISO(givenValueFrom)

      if (to < from) {
        setFilterValue(`${to.startOf('day').toISO()},${to.toISO()}`)
        return
      }
    }

    setFilterValue(`${givenValueFrom},${to.toISO()}`)
  }

  return (
    <div className="flex items-center gap-2 lg:gap-3">
      <DatePicker
        disableFuture
        showErrorInTooltip
        placement="auto"
        className="flex-1"
        defaultZone={defaultZone}
        onChange={handleFromChange}
        value={givenValueFrom}
      />
      <Typography variant="body" color="grey700">
        <div className="block lg:hidden">-</div>
        <div className="hidden lg:block">
          {translate('text_65f8472df7593301061e27d6').toLowerCase()}
        </div>
      </Typography>
      <DatePicker
        disableFuture
        showErrorInTooltip
        placement="auto"
        className="flex-1"
        defaultZone={defaultZone}
        onChange={handleToChange}
        value={givenValueTo}
      />
    </div>
  )
}
