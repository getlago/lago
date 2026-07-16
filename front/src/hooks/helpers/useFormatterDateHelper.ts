/*
 * This hook serves as a central point for ONLY common formatting logic for dates
 * that can be shared across multiple components
 * NB:
 * A new method is supposed to be added here only when we have duplication in formatting logic
 * across multiple components. If the formatting logic is specific to a single component,
 * it should reside within that component or, in case, its dedicated hook.
 */
import { intlFormatDateTime, TimeFormat } from '~/core/timezone/utils'
import { TimezoneEnum } from '~/generated/graphql'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

type useFormatterDateHelper = () => {
  formattedDateTimeWithSecondsOrgaTZ: (date: string) => string
  formattedDateWithTimezone: (date: string, timezone?: TimezoneEnum) => string
}

export const useFormatterDateHelper: useFormatterDateHelper = () => {
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  // Formatter for date-time with seconds considering organization's timezone
  const formattedDateTimeWithSecondsOrgaTZ = (date: string) => {
    const { date: d, time } = intlFormatDateTimeOrgaTZ(date, {
      formatTime: TimeFormat.TIME_WITH_SECONDS,
    })

    return `${d} ${time}`
  }

  // Formatter for date-timezone
  const formattedDateWithTimezone = (date: string, applicableTimezone?: TimezoneEnum) => {
    const { date: d, timezone } = intlFormatDateTime(date, {
      timezone: applicableTimezone,
    })

    return `${d} ${timezone}`
  }

  return {
    formattedDateTimeWithSecondsOrgaTZ,
    formattedDateWithTimezone,
  }
}
