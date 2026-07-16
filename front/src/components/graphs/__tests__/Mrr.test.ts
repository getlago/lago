import { DateTime } from 'luxon'

import { AreaMrrChartFakeData } from '~/components/designSystem/graphs/fixtures'
import { AnalyticsPeriodScopeEnum } from '~/components/graphs/MonthSelectorDropdown'
import { getAllDataForMrrDisplay } from '~/components/graphs/Mrr'
import { GRAPH_YEAR_MONTH_DATE_FORMAT } from '~/components/graphs/utils'
import { CurrencyEnum } from '~/generated/graphql'

describe('components/graphs/Mrr', () => {
  describe('getAllDataForMrrDisplay', () => {
    it('should return 12 months on year blur mode', () => {
      const res = getAllDataForMrrDisplay({
        data: AreaMrrChartFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: true,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(res.dataForAreaChart.length).toBe(13)
      expect(res.dataForAreaChart[0].axisName).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dataForAreaChart[12].axisName).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )

      expect(typeof res.lastMonthMrr).toBe('number')
      expect(res.hasOnlyZeroValues).toBeFalsy()
    })

    it('should return 12 months on year demo mode', () => {
      const res = getAllDataForMrrDisplay({
        data: AreaMrrChartFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(res.dataForAreaChart.length).toBe(13)
      expect(res.dataForAreaChart[0].axisName).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dataForAreaChart[12].axisName).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )

      expect(typeof res.lastMonthMrr).toBe('number')
    })

    it('should return 4 months on quarterly demo mode', () => {
      const res = getAllDataForMrrDisplay({
        data: AreaMrrChartFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Quarter,
      })

      expect(res.dataForAreaChart.length).toBe(4)
      expect(res.dataForAreaChart[0].axisName).toBe(
        DateTime.now().minus({ month: 3 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dataForAreaChart[3].axisName).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 3 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )

      expect(typeof res.lastMonthMrr).toBe('number')
    })

    it('should return 2 months on quarterly demo mode', () => {
      const res = getAllDataForMrrDisplay({
        data: AreaMrrChartFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.dataForAreaChart.length).toBe(2)
      expect(res.dataForAreaChart[0].axisName).toBe(
        DateTime.now().minus({ month: 1 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dataForAreaChart[1].axisName).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 1 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )

      expect(typeof res.lastMonthMrr).toBe('number')
    })

    it('should return correct total amount', () => {
      const res = getAllDataForMrrDisplay({
        data: [
          {
            amountCents: '5810000',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
          {
            amountCents: '3600000',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().minus({ month: 1 }).startOf('month').toISO(),
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.lastMonthMrr).toBe(3600000)
    })

    it('should warn about no values', () => {
      const res = getAllDataForMrrDisplay({
        data: [
          {
            amountCents: '0',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.hasOnlyZeroValues).toBeTruthy()
    })
  })
})
