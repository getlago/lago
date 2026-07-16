import { DateTime, Settings } from 'luxon'

import { DateFormat, intlFormatDateTime } from '~/core/timezone/utils'
import { LocaleEnum } from '~/core/translations'
import { TimezoneEnum } from '~/generated/graphql'

import { TimeFormat, TimezoneFormat } from './../utils'

const originalNow = Settings.now

afterEach(() => {
  Settings.now = originalNow
})

describe('intlFormatDateTime', () => {
  describe('In summer date', () => {
    beforeEach(() => {
      const summerDate = DateTime.fromISO('2025-08-01T12:00:00', { zone: 'Europe/Paris' })

      Settings.now = () => summerDate.toMillis()
    })

    describe('it should format dates correctly', () => {
      it('should format to "Apr 18, 2025"', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_MED,
        })

        expect(date).toEqual('Apr 18, 2025')
      })

      it('should format to "Apr 18"', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_MED_SHORT,
        })

        expect(date).toEqual('Apr 18')
      })

      it('should format to "4/18/2025"', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_SHORT,
        })

        expect(date).toEqual('4/18/2025')
      })

      it('should format to "18/04/2025" in French', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_SHORT,
          locale: LocaleEnum.fr,
        })

        expect(date).toEqual('18/04/2025')
      })

      it('should format to "April 18, 2025"', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_FULL,
        })

        expect(date).toEqual('April 18, 2025')
      })

      it('should format to "Friday, April 18, 2025"', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_HUGE,
        })

        expect(date).toEqual('Friday, April 18, 2025')
      })

      it('should format to "Fri, Apr 18, 2025"', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_MED_WITH_WEEKDAY,
        })

        expect(date).toEqual('Fri, Apr 18, 2025')
      })

      it('should format to "Apr 18, 25"', () => {
        const { date } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_MED_SHORT_YEAR,
        })

        expect(date).toEqual('Apr 18, 25')
      })

      it('should format to "Apr 2024"', () => {
        const { date } = intlFormatDateTime('2024-04-18T00:00:00Z', {
          formatDate: DateFormat.DATE_MONTH_YEAR,
        })

        expect(date).toEqual('Apr 2024')
      })
    })

    describe('it should format times correctly', () => {
      it('should format to "1:41 AM"', () => {
        const { time } = intlFormatDateTime('2025-04-18T01:41:39Z', {
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        expect(time).toEqual('1:41\u202FAM')
      })

      it('should format to "1:41 PM"', () => {
        const { time } = intlFormatDateTime('2025-04-18T13:41:39Z', {
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        expect(time).toEqual('1:41\u202FPM')
      })

      it('should format to "6:00:39\u202FPM"', () => {
        const { time } = intlFormatDateTime('2025-04-18T18:00:39Z', {
          formatTime: TimeFormat.TIME_WITH_SECONDS,
        })

        expect(time).toEqual('6:00:39\u202FPM')
      })

      it('should format to "13:41"', () => {
        const { time } = intlFormatDateTime('2025-04-18T13:41:39Z', {
          formatTime: TimeFormat.TIME_24_SIMPLE,
        })

        expect(time).toEqual('13:41')
      })

      it('should format to "13:41:39"', () => {
        const { time } = intlFormatDateTime('2025-04-18T13:41:39Z', {
          formatTime: TimeFormat.TIME_24_WITH_SECONDS,
        })

        expect(time).toEqual('13:41:39')
      })
    })

    describe('it should format timezones correctly', () => {
      it('should format to "UTC±0:00"', () => {
        const { timezone } = intlFormatDateTime('2025-04-18T00:00:00Z')

        expect(timezone).toEqual('UTC±0:00')
      })

      it('should format to "UTC+12:00" (Auckland in April - standard time)', () => {
        const { timezone } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          timezone: TimezoneEnum.TzPacificAuckland,
        })

        expect(timezone).toEqual('UTC+12:00')
      })

      it('should format to "UTC-4:00"', () => {
        const { timezone } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaNewYork,
        })

        expect(timezone).toEqual('UTC-4:00')
      })

      it('should format to "PDT"', () => {
        const { timezone } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaLosAngeles,
          formatTimezone: TimezoneFormat.TIMEZONE_SHORT,
        })

        expect(timezone).toEqual('PDT')
      })

      it('should format to "Pacific Daylight Time"', () => {
        const { timezone } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaLosAngeles,
          formatTimezone: TimezoneFormat.TIMEZONE_LONG,
        })

        expect(timezone).toEqual('Pacific Daylight Time')
      })

      it('should format to "GMT-7"', () => {
        const { timezone } = intlFormatDateTime('2025-04-18T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaLosAngeles,
          formatTimezone: TimezoneFormat.TIMEZONE_OFFSET,
        })

        expect(timezone).toEqual('GMT-7')
      })
    })

    describe('it should format date time and timezones correctly', () => {
      it('should format to "From Apr 2024 to Apr 2025"', () => {
        const { date: from } = intlFormatDateTime('2024-04-01T00:00:00Z', {
          formatDate: DateFormat.DATE_MONTH_YEAR,
        })

        const { date: to } = intlFormatDateTime('2025-04-01T00:00:00Z', {
          formatDate: DateFormat.DATE_MONTH_YEAR,
        })

        const result = `From ${from} to ${to}`

        expect(result).toEqual('From Apr 2024 to Apr 2025')
      })

      it('should format to "Apr 3, 2025, 6:06 PM UTC±0:00"', () => {
        const { date, time, timezone } = intlFormatDateTime('2025-04-03T18:06:33Z', {
          timezone: TimezoneEnum.TzUtc,
          formatDate: DateFormat.DATE_MED,
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        const result = `${date}, ${time} ${timezone}`

        expect(result).toEqual('Apr 3, 2025, 6:06 PM UTC±0:00')
      })

      it('should format to "Apr 18, 2025 UTC-11:00"', () => {
        const { date, timezone } = intlFormatDateTime('2025-04-18T18:25:33Z', {
          timezone: TimezoneEnum.TzPacificMidway,
          formatDate: DateFormat.DATE_MED,
        })

        const result = `${date} ${timezone}`

        expect(result).toEqual('Apr 18, 2025 UTC-11:00')
      })

      it('should format to "Saturday, April 19, 2025 UTC+8:00"', () => {
        const { date, timezone } = intlFormatDateTime('2025-04-18T18:25:33Z', {
          timezone: TimezoneEnum.TzAsiaSingapore,
          formatDate: DateFormat.DATE_HUGE,
        })

        const result = `${date} ${timezone}`

        expect(result).toEqual('Saturday, April 19, 2025 UTC+8:00')
      })

      it('should format to "April 2, 2025 at 3:30:13 PM UTC±0:00"', () => {
        const { date, time, timezone } = intlFormatDateTime('2025-04-02T15:30:13Z', {
          formatDate: DateFormat.DATE_FULL,
          formatTime: TimeFormat.TIME_WITH_SECONDS,
        })

        const result = `${date} at ${time} ${timezone}`

        expect(result).toEqual('April 2, 2025 at 3:30:13 PM UTC±0:00')
      })

      it('should format to "Thu, Apr 3, 2025 09:32:01"', () => {
        const { date, time } = intlFormatDateTime('2025-04-03T09:32:01Z', {
          formatDate: DateFormat.DATE_MED_WITH_WEEKDAY,
          formatTime: TimeFormat.TIME_24_WITH_SECONDS,
        })

        const result = `${date} ${time}`

        expect(result).toEqual('Thu, Apr 3, 2025 09:32:01')
      })

      it('should format to "Apr 18, 2025 18:25:33 UTC±0:00"', () => {
        const { date, time, timezone } = intlFormatDateTime('2025-04-18T18:25:33Z', {
          formatDate: DateFormat.DATE_MED,
          formatTime: TimeFormat.TIME_24_WITH_SECONDS,
        })

        const result = `${date} ${time} ${timezone}`

        expect(result).toEqual('Apr 18, 2025 18:25:33 UTC±0:00')
      })

      it('should convert UTC time to New York EDT correctly', () => {
        const { date, time } = intlFormatDateTime('2025-04-18T18:25:33Z', {
          timezone: TimezoneEnum.TzAmericaNewYork,
          formatDate: DateFormat.DATE_MED,
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        const result = `${date} ${time}`

        expect(result).toEqual('Apr 18, 2025 2:25 PM')
      })
    })
  })

  describe('In winter date', () => {
    beforeEach(() => {
      const winterDate = DateTime.fromISO('2025-01-01T12:00:00', { zone: 'Europe/Paris' })

      Settings.now = () => winterDate.toMillis()
    })

    describe('it should format dates correctly', () => {
      it('should format to "Jan 15, 2025"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_MED,
        })

        expect(date).toEqual('Jan 15, 2025')
      })

      it('should format to "Jan 15"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_MED_SHORT,
        })

        expect(date).toEqual('Jan 15')
      })

      it('should format to "1/15/2025"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_SHORT,
        })

        expect(date).toEqual('1/15/2025')
      })

      it('should format to "15/01/2025" in French', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_SHORT,
          locale: LocaleEnum.fr,
        })

        expect(date).toEqual('15/01/2025')
      })

      it('should format to "January 15, 2025"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_FULL,
        })

        expect(date).toEqual('January 15, 2025')
      })

      it('should format to "Wednesday, January 15, 2025"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_HUGE,
        })

        expect(date).toEqual('Wednesday, January 15, 2025')
      })

      it('should format to "Wed, Jan 15, 2025"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_MED_WITH_WEEKDAY,
        })

        expect(date).toEqual('Wed, Jan 15, 2025')
      })

      it('should format to "Jan 15, 25"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_MED_SHORT_YEAR,
        })

        expect(date).toEqual('Jan 15, 25')
      })

      it('should format to "Jan 2025"', () => {
        const { date } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          formatDate: DateFormat.DATE_MONTH_YEAR,
        })

        expect(date).toEqual('Jan 2025')
      })
    })

    describe('it should format times correctly', () => {
      it('should format to "1:41 AM"', () => {
        const { time } = intlFormatDateTime('2025-01-15T01:41:39Z', {
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        expect(time).toEqual('1:41\u202FAM')
      })

      it('should format to "1:41 PM"', () => {
        const { time } = intlFormatDateTime('2025-01-15T13:41:39Z', {
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        expect(time).toEqual('1:41\u202FPM')
      })

      it('should format to "6:00:39 PM"', () => {
        const { time } = intlFormatDateTime('2025-01-15T18:00:39Z', {
          formatTime: TimeFormat.TIME_WITH_SECONDS,
        })

        expect(time).toEqual('6:00:39\u202FPM')
      })

      it('should format to "13:41"', () => {
        const { time } = intlFormatDateTime('2025-01-15T13:41:39Z', {
          formatTime: TimeFormat.TIME_24_SIMPLE,
        })

        expect(time).toEqual('13:41')
      })

      it('should format to "13:41:39"', () => {
        const { time } = intlFormatDateTime('2025-01-15T13:41:39Z', {
          formatTime: TimeFormat.TIME_24_WITH_SECONDS,
        })

        expect(time).toEqual('13:41:39')
      })
    })

    describe('it should format timezones correctly in winter (DST differences)', () => {
      it('should format to "UTC±0:00"', () => {
        const { timezone } = intlFormatDateTime('2025-01-15T00:00:00Z')

        expect(timezone).toEqual('UTC±0:00')
      })

      it('should format to "UTC+13:00"', () => {
        const { timezone } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          timezone: TimezoneEnum.TzPacificAuckland,
        })

        expect(timezone).toEqual('UTC+13:00')
      })

      it('should format to "UTC-5:00" (New York in winter - EST)', () => {
        const { timezone } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaNewYork,
        })

        expect(timezone).toEqual('UTC-5:00')
      })

      it('should format to "EST" (Eastern Standard Time in winter)', () => {
        const { timezone } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaNewYork,
          formatTimezone: TimezoneFormat.TIMEZONE_SHORT,
        })

        expect(timezone).toEqual('EST')
      })

      it('should format to "Eastern Standard Time"', () => {
        const { timezone } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaNewYork,
          formatTimezone: TimezoneFormat.TIMEZONE_LONG,
        })

        expect(timezone).toEqual('Eastern Standard Time')
      })

      it('should format to "GMT-5" (correct for actual date)', () => {
        const { timezone } = intlFormatDateTime('2025-01-15T00:00:00Z', {
          timezone: TimezoneEnum.TzAmericaNewYork,
          formatTimezone: TimezoneFormat.TIMEZONE_OFFSET,
        })

        expect(timezone).toEqual('GMT-5')
      })
    })

    describe('it should format date time and timezones correctly', () => {
      it('should format to "From Jan 2024 to Jan 2025"', () => {
        const { date: from } = intlFormatDateTime('2024-01-01T00:00:00Z', {
          formatDate: DateFormat.DATE_MONTH_YEAR,
        })

        const { date: to } = intlFormatDateTime('2025-01-01T00:00:00Z', {
          formatDate: DateFormat.DATE_MONTH_YEAR,
        })

        const result = `From ${from} to ${to}`

        expect(result).toEqual('From Jan 2024 to Jan 2025')
      })

      it('should format to "Jan 15, 2025, 6:06 PM UTC±0:00"', () => {
        const { date, time, timezone } = intlFormatDateTime('2025-01-15T18:06:33Z', {
          timezone: TimezoneEnum.TzUtc,
          formatDate: DateFormat.DATE_MED,
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        const result = `${date}, ${time} ${timezone}`

        expect(result).toEqual('Jan 15, 2025, 6:06\u202FPM UTC±0:00')
      })

      it('should format to "Jan 15, 2025 UTC-11:00"', () => {
        const { date, timezone } = intlFormatDateTime('2025-01-15T18:25:33Z', {
          timezone: TimezoneEnum.TzPacificMidway,
          formatDate: DateFormat.DATE_MED,
        })

        const result = `${date} ${timezone}`

        expect(result).toEqual('Jan 15, 2025 UTC-11:00')
      })

      it('should format to "Thursday, January 16, 2025 UTC+8:00"', () => {
        const { date, timezone } = intlFormatDateTime('2025-01-15T18:25:33Z', {
          timezone: TimezoneEnum.TzAsiaSingapore,
          formatDate: DateFormat.DATE_HUGE,
        })

        const result = `${date} ${timezone}`

        expect(result).toEqual('Thursday, January 16, 2025 UTC+8:00')
      })

      it('should format to "January 15, 2025 at 3:30:13 PM UTC±0:00"', () => {
        const { date, time, timezone } = intlFormatDateTime('2025-01-15T15:30:13Z', {
          formatDate: DateFormat.DATE_FULL,
          formatTime: TimeFormat.TIME_WITH_SECONDS,
        })

        const result = `${date} at ${time} ${timezone}`

        expect(result).toEqual('January 15, 2025 at 3:30:13\u202FPM UTC±0:00')
      })

      it('should format to "Wed, Jan 15, 2025 09:32:01"', () => {
        const { date, time } = intlFormatDateTime('2025-01-15T09:32:01Z', {
          formatDate: DateFormat.DATE_MED_WITH_WEEKDAY,
          formatTime: TimeFormat.TIME_24_WITH_SECONDS,
        })

        const result = `${date} ${time}`

        expect(result).toEqual('Wed, Jan 15, 2025 09:32:01')
      })

      it('should format to "Jan 15, 2025 18:25:33 UTC±0:00"', () => {
        const { date, time, timezone } = intlFormatDateTime('2025-01-15T18:25:33Z', {
          formatDate: DateFormat.DATE_MED,
          formatTime: TimeFormat.TIME_24_WITH_SECONDS,
        })

        const result = `${date} ${time} ${timezone}`

        expect(result).toEqual('Jan 15, 2025 18:25:33 UTC±0:00')
      })

      it('should convert UTC time to New York EST correctly', () => {
        const { date, time } = intlFormatDateTime('2025-01-15T18:25:33Z', {
          timezone: TimezoneEnum.TzAmericaNewYork,
          formatDate: DateFormat.DATE_MED,
          formatTime: TimeFormat.TIME_SIMPLE,
        })

        const result = `${date} ${time}`

        expect(result).toEqual('Jan 15, 2025 1:25 PM')
      })
    })
  })
})
