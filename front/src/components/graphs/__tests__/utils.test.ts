import { DateTime, Settings } from 'luxon'

import {
  formatDataForAreaChart,
  getLastTwelveMonthsNumbersUntilNow,
  GRAPH_YEAR_MONTH_DATE_FORMAT,
  padAndTransformDataOverLastTwelveMonth,
  TAreaChartDataResult,
} from '~/components/graphs/utils'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'

const originalDefaultZone = Settings.defaultZone

afterEach(() => {
  Settings.defaultZone = originalDefaultZone
})

describe('components/graphs/utils', () => {
  beforeEach(() => {
    Settings.defaultZone = 'UTC'
  })
  describe('getLastTwelveMonthsNumbersUntilNow', () => {
    it('should return an array of 12 months', () => {
      const builtArray = getLastTwelveMonthsNumbersUntilNow()

      expect(builtArray.length).toBe(13)
      expect(getLastTwelveMonthsNumbersUntilNow()).toStrictEqual([
        DateTime.utc().startOf('month').minus({ month: 12 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 11 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 10 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 9 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 8 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 7 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 6 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 5 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 4 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 3 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 2 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').minus({ month: 1 }).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        DateTime.utc().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      ])
    })
  })

  describe('padAndTransformDataOverLastTwelveMonth', () => {
    it('should return an array of 12 months if the data is less than 12 months', () => {
      const data: TAreaChartDataResult = [
        {
          month: DateTime.utc().startOf('month').minus({ month: 1 }).toISO(),
          amountCents: 100,
          currency: CurrencyEnum.Eur,
        },
      ]

      const builtArray = padAndTransformDataOverLastTwelveMonth(data, CurrencyEnum.Eur)

      expect(builtArray.length).toBe(13)
      expect(builtArray).toStrictEqual([
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 12 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 11 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 10 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 9 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 8 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 7 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 6 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 5 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 4 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 3 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 2 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc()
            .startOf('month')
            .minus({ month: 1 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 100,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: 0,
          currency: CurrencyEnum.Eur,
        },
      ])
    })

    it('should return the exact same array of data if it contains 12 items', () => {
      const data: TAreaChartDataResult = [
        {
          month: DateTime.utc().startOf('month').minus({ month: 12 }).toISO(),
          amountCents: 1100,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 11 }).toISO(),
          amountCents: 1100,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 10 }).toISO(),
          amountCents: 1000,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 9 }).toISO(),
          amountCents: 900,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 8 }).toISO(),
          amountCents: 800,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 7 }).toISO(),
          amountCents: 700,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 6 }).toISO(),
          amountCents: 600,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 5 }).toISO(),
          amountCents: 500,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 4 }).toISO(),
          amountCents: 400,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 3 }).toISO(),
          amountCents: 300,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 2 }).toISO(),
          amountCents: 200,
          currency: CurrencyEnum.Eur,
        },

        {
          month: DateTime.utc().startOf('month').minus({ month: 1 }).toISO(),
          amountCents: 100,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').toISO(),
          amountCents: 1200,
          currency: CurrencyEnum.Eur,
        },
      ]

      const builtArray = padAndTransformDataOverLastTwelveMonth(data, CurrencyEnum.Eur)

      expect(builtArray.length).toBe(13)
      expect(builtArray).toStrictEqual(
        data.map((d) => ({
          month: DateTime.fromISO(d.month as string).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
          amountCents: d.amountCents,
          currency: d.currency,
        })),
      )
    })

    it('should sum amountCents when multiple rows share the same calendar month', () => {
      const lastMonthISO = DateTime.utc().startOf('month').minus({ month: 1 }).toISO()
      const data: TAreaChartDataResult = [
        { month: lastMonthISO, amountCents: 100, currency: CurrencyEnum.Eur },
        { month: lastMonthISO, amountCents: 250, currency: CurrencyEnum.Eur },
      ]

      const builtArray = padAndTransformDataOverLastTwelveMonth(data, CurrencyEnum.Eur)
      const lastMonthSlot = builtArray[builtArray.length - 2]

      expect(lastMonthSlot).toStrictEqual({
        month: DateTime.utc()
          .startOf('month')
          .minus({ month: 1 })
          .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        amountCents: 350,
        currency: CurrencyEnum.Eur,
      })
    })
  })

  describe('formatDataForAreaChart', () => {
    it('should return an array of 12 months if the data is less than 12 months', () => {
      const data: TAreaChartDataResult = [
        {
          month: DateTime.utc().startOf('month').minus({ month: 1 }).toISO(),
          amountCents: 100,
          currency: CurrencyEnum.Eur,
        },
      ]

      const builtArray = formatDataForAreaChart(data, CurrencyEnum.Eur)

      expect(builtArray.length).toBe(13)
      expect(builtArray).toStrictEqual([
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 12 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 12 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 11 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 11 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 10 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 10 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 9 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 9 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 8 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 8 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 7 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 7 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 6 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 6 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 5 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 5 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 4 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 4 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 3 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 3 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 2 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 2 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 1 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(1, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 100,
          axisName: DateTime.utc()
            .startOf('month')
            .minus({ month: 1 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(0, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 0,
          axisName: DateTime.utc().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
        },
      ])
    })

    it('should return the exact same array of data if it contains 12 items', () => {
      const data: TAreaChartDataResult = [
        {
          month: DateTime.utc().startOf('month').minus({ month: 12 }).toISO(),
          amountCents: 1100,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 11 }).toISO(),
          amountCents: 1100,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 10 }).toISO(),
          amountCents: 1000,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 9 }).toISO(),
          amountCents: 900,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 8 }).toISO(),
          amountCents: 800,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 7 }).toISO(),
          amountCents: 700,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 6 }).toISO(),
          amountCents: 600,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 5 }).toISO(),
          amountCents: 500,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 4 }).toISO(),
          amountCents: 400,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 3 }).toISO(),
          amountCents: 300,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').minus({ month: 2 }).toISO(),
          amountCents: 200,
          currency: CurrencyEnum.Eur,
        },

        {
          month: DateTime.utc().startOf('month').minus({ month: 1 }).toISO(),
          amountCents: 100,
          currency: CurrencyEnum.Eur,
        },
        {
          month: DateTime.utc().startOf('month').toISO(),
          amountCents: 1200,
          currency: CurrencyEnum.Eur,
        },
      ]

      const builtArray = formatDataForAreaChart(data, CurrencyEnum.Eur)

      expect(builtArray.length).toBe(13)
      expect(builtArray).toStrictEqual([
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 12 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(11, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 1100,
          axisName: builtArray[0].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 11 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(11, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 1100,
          axisName: builtArray[1].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 10 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(10, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 1000,
          axisName: builtArray[2].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 9 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(9, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 900,
          axisName: builtArray[3].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 8 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(8, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 800,
          axisName: builtArray[4].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 7 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(7, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 700,
          axisName: builtArray[5].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 6 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(6, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 600,
          axisName: builtArray[6].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 5 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(5, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 500,
          axisName: builtArray[7].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 4 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(4, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 400,
          axisName: builtArray[8].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 3 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(3, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 300,
          axisName: builtArray[9].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 2 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(2, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 200,
          axisName: builtArray[10].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .minus({ month: 1 })
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(1, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 100,
          axisName: builtArray[11].axisName,
        },
        {
          tooltipLabel: `${DateTime.utc()
            .startOf('month')
            .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)}: ${intlFormatNumber(12, {
            currency: CurrencyEnum.Eur,
          })}`,
          value: 1200,
          axisName: builtArray[12].axisName,
        },
      ])
    })
  })
})
