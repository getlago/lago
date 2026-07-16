import { captureMessage } from '@sentry/react'
import { DateTime, DateTimeFormatOptions } from 'luxon'

import { envGlobalVar } from '~/core/apolloClient'
import { getOffset, TimeZonesConfig } from '~/core/timezone/config'
import { LocaleEnum } from '~/core/translations'
import { TimezoneEnum } from '~/generated/graphql'

const { sentryDsn } = envGlobalVar()

export const getTimezoneConfig = (timezone: TimezoneEnum | null | undefined) => {
  if (!timezone) return TimeZonesConfig[TimezoneEnum.TzUtc]

  const doesTimezoneConfigExist = Object.keys(TimeZonesConfig).includes(timezone)

  if (!doesTimezoneConfigExist) {
    // If given timezone is not present in config, we should default to UTC config.
    // However, it's pretty critical as UI and date calculation will be wrong.
    // Calling sentry to make sure we notice and add missing timezone to the TimeZonesConfig enum then.
    if (!!sentryDsn) {
      captureMessage(`Timezone ${timezone} is missing in TimeZonesConfig`)
    }

    return TimeZonesConfig[TimezoneEnum.TzUtc]
  }

  return TimeZonesConfig[timezone as TimezoneEnum]
}

export const isSameDay = (a: DateTime, b: DateTime): boolean => {
  return a.hasSame(b, 'day') && a.hasSame(b, 'month') && a.hasSame(b, 'year')
}

export enum DateFormat {
  /** Apr 18 */
  DATE_MED_SHORT = 'DATE_MED_SHORT',
  /** Apr 18, 2025 */
  DATE_MED = 'DATE_MED',
  /** 4/18/2025 */
  DATE_SHORT = 'DATE_SHORT',
  /** April 18, 2025 */
  DATE_FULL = 'DATE_FULL',
  /** Friday, April 18, 2025 */
  DATE_HUGE = 'DATE_HUGE',
  /** Fri, Apr 18, 2025 */
  DATE_MED_WITH_WEEKDAY = 'DATE_MED_WITH_WEEKDAY',
  /** Apr 18, 25 */
  DATE_MED_SHORT_YEAR = 'DATE_MED_SHORT_YEAR',
  /** Apr 2024 */
  DATE_MONTH_YEAR = 'DATE_MONTH_YEAR',
}

export enum TimeFormat {
  /** 1:41 PM */
  TIME_SIMPLE = 'TIME_SIMPLE',
  /** 1:41:39 PM */
  TIME_WITH_SECONDS = 'TIME_WITH_SECONDS',
  /** 13:41 */
  TIME_24_SIMPLE = 'TIME_24_SIMPLE',
  /** 13:41:39 */
  TIME_24_WITH_SECONDS = 'TIME_24_WITH_SECONDS',
}

export enum TimezoneFormat {
  /** UTC+5 */
  UTC_OFFSET = 'UTC_OFFSET',
  /** PDT */
  TIMEZONE_SHORT = 'TIMEZONE_SHORT',
  /** Pacific Daylight Time */
  TIMEZONE_LONG = 'TIMEZONE_LONG',
  /** GMT-7 */
  TIMEZONE_OFFSET = 'TIMEZONE_OFFSET',
}

const getDateString = (dateTime: DateTime, format: DateFormat) => {
  if (format === DateFormat.DATE_MONTH_YEAR) {
    return dateTime.toLocaleString({
      month: 'short',
      year: 'numeric',
    })
  }

  if (format === DateFormat.DATE_MED_SHORT_YEAR) {
    return dateTime.toLocaleString({
      day: 'numeric',
      month: 'short',
      year: '2-digit',
    })
  }

  if (format === DateFormat.DATE_MED_SHORT) {
    return dateTime.toLocaleString({
      month: 'short',
      day: 'numeric',
    })
  }

  return dateTime.toLocaleString(DateTime[format])
}
const getTimezoneString = (dateTime: DateTime, timezone: TimezoneEnum, format: TimezoneFormat) => {
  let timeZoneName: DateTimeFormatOptions['timeZoneName'] | undefined
  let timezoneString: string | undefined

  switch (format) {
    case 'TIMEZONE_SHORT':
      timeZoneName = 'short'
      break
    case 'TIMEZONE_LONG':
      timeZoneName = 'long'
      break
    case 'TIMEZONE_OFFSET':
      timeZoneName = 'shortOffset'
      break
    default:
      timeZoneName = undefined
      break
  }

  if (timeZoneName) {
    timezoneString =
      dateTime
        .toLocaleParts({
          timeZoneName: timeZoneName,
        })
        .find((part) => part.type === 'timeZoneName')?.value || ''
  } else {
    // Use centralized offset calculation that handles DST properly
    const zoneName = getTimezoneConfig(timezone).name
    const offset = getOffset(zoneName, dateTime.toISO() || undefined)

    timezoneString = `UTC${offset}`
  }
  return timezoneString
}

/**
 * Formats a date/time string according to the specified timezone and locale options.
 *
 * @param date - ISO date string to format
 * @param options - Formatting options
 * @param options.timezone - Target timezone to format the date in. Defaults to UTC.
 * @param options.locale - Locale to use for formatting. Defaults to English.
 * @param options.formatDate - Format to use for the date portion. Default is `DATE_MED` (Apr 18, 2025).
 * @param options.formatTime - Format to use for the time portion. Default is `TIME_SIMPLE` (12:00 AM).
 * @param options.formatTimezone - Format to use for the timezone. Default is `UTC_OFFSET` (UTC±0:00).
 * @returns Object containing formatted date, time and timezone strings
 * @example
 * ```ts
 * // Format a date in UTC
 * intlFormatDateTime('2023-01-01T00:00:00Z')
 * // Returns: { date: 'Jan 1, 2023', time: '12:00 AM', timezone: 'UTC±0:00' }
 *
 * // Format with custom timezone and formats
 * intlFormatDateTime('2023-01-01T00:00:00Z', {
 *   timezone: TimezoneEnum.TzAmericaNewYork,
 *   formatDate: DateFormat.DATE_MED_SHORT_YEAR,
 *   formatTime: TimeFormat.TIME_24_SIMPLE
 * })
 * // Returns: { date: 'Dec 31, 22', time: '19:00', timezone: 'UTC-4:00' }
 * ```
 */

export type IntlFormatDateTimeOptions = {
  timezone?: TimezoneEnum | null | undefined
  locale?: LocaleEnum
  formatDate?: DateFormat
  formatTime?: TimeFormat
  formatTimezone?: TimezoneFormat
}

export type IntlFormatDateTimeReturn = {
  date: string
  time: string
  timezone: string
}

export const intlFormatDateTime = (
  date: string,
  options: IntlFormatDateTimeOptions | undefined = {},
): IntlFormatDateTimeReturn => {
  const timezone = options?.timezone || TimezoneEnum.TzUtc
  const locale = options?.locale || LocaleEnum.en

  const localeDateTime = DateTime.fromISO(date, {
    zone: getTimezoneConfig(timezone).name,
    locale: locale,
  })

  return {
    date: getDateString(localeDateTime, options.formatDate || DateFormat.DATE_MED),
    time: localeDateTime.toLocaleString(DateTime[options?.formatTime || TimeFormat.TIME_SIMPLE]),
    timezone: getTimezoneString(
      localeDateTime,
      timezone,
      options?.formatTimezone || TimezoneFormat.UTC_OFFSET,
    ),
  }
}
