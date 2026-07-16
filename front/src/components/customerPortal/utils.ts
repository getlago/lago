import { DateTime } from 'luxon'

import { getTimezoneConfig } from '~/core/timezone/utils'
import { LocaleEnum } from '~/core/translations'
import { TimezoneEnum } from '~/generated/graphql'

type PlanRenewalDateProps = {
  currentBillingPeriodEndingAt: string
  applicableTimezone?: TimezoneEnum | null
  locale?: LocaleEnum
}

const formatAndAddDay = (
  date: string,
  timezone: TimezoneEnum | null | undefined,
  locale?: LocaleEnum,
) => {
  return DateTime.fromISO(date, {
    zone: getTimezoneConfig(timezone).name,
    locale: locale,
  })
    .plus({ days: 1 })
    .toLocaleString(DateTime.DATE_MED)
}

export const planRenewalDate = ({
  currentBillingPeriodEndingAt,
  applicableTimezone,
  locale,
}: PlanRenewalDateProps) =>
  formatAndAddDay(currentBillingPeriodEndingAt, applicableTimezone, locale)
