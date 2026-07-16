import { DateTime } from 'luxon'

import { InvoicedUsageFakeData } from '~/components/designSystem/graphs/fixtures'
import { AnalyticsPeriodScopeEnum } from '~/components/graphs/MonthSelectorDropdown'
import { getDataForUsageDisplay, LAST_USAGE_GRAPH_LINE_KEY_NAME } from '~/components/graphs/Usage'
import { GRAPH_YEAR_MONTH_DATE_FORMAT } from '~/components/graphs/utils'
import { CurrencyEnum } from '~/generated/graphql'

describe('components/graphs/Usage', () => {
  describe('getDataForUsageDisplay', () => {
    it('should return data for year blur mode', () => {
      const res = getDataForUsageDisplay({
        data: InvoicedUsageFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: true,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(typeof res.totalAmount).toBe('number')
      expect(res.dataBarForDisplay.length).toBe(1)
      expect(res.hasNoDataToDisplay).toBeFalsy()
      expect(res.dataLinesForDisplay.length).toBe(5)
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should return data for year demo mode', () => {
      const res = getDataForUsageDisplay({
        data: InvoicedUsageFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(typeof res.totalAmount).toBe('number')
      expect(res.dataBarForDisplay.length).toBe(1)
      expect(res.hasNoDataToDisplay).toBeFalsy()
      expect(res.dataLinesForDisplay.length).toBe(5)
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should return data for quarter demo mode', () => {
      const res = getDataForUsageDisplay({
        data: InvoicedUsageFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Quarter,
      })

      expect(typeof res.totalAmount).toBe('number')
      expect(res.dataBarForDisplay.length).toBe(1)
      expect(res.hasNoDataToDisplay).toBeFalsy()
      expect(res.dataLinesForDisplay.length).toBe(5)
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 3 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should return data for month demo mode', () => {
      const res = getDataForUsageDisplay({
        data: InvoicedUsageFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(typeof res.totalAmount).toBe('number')
      expect(res.dataBarForDisplay.length).toBe(1)
      expect(res.hasNoDataToDisplay).toBeFalsy()
      expect(res.dataLinesForDisplay.length).toBe(5)
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 1 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should contain the Other as last items if more than 5 items', () => {
      const res = getDataForUsageDisplay({
        data: [
          {
            amountCents: '42500',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'sum_bm',
          },
          {
            amountCents: '45100',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm',
          },
          {
            amountCents: '43130',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_two_dimensions',
          },
          {
            amountCents: '42300',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_one_dimension',
          },
          {
            amountCents: '42300',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'user_seats',
          },
          {
            amountCents: '40020',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'gb',
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.dataLinesForDisplay[res.dataLinesForDisplay.length - 1][0]).toBe(
        LAST_USAGE_GRAPH_LINE_KEY_NAME,
      )
    })

    it('should contain the last key as last items if contains 5 items', () => {
      const res = getDataForUsageDisplay({
        data: [
          {
            amountCents: '42500',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'sum_bm',
          },
          {
            amountCents: '45100',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm',
          },
          {
            amountCents: '43130',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_two_dimensions',
          },
          {
            amountCents: '42300',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_one_dimension',
          },
          {
            amountCents: '42300',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'user_seats',
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.dataLinesForDisplay[res.dataLinesForDisplay.length - 1][0]).toBe('user_seats')
    })

    it('should contain the last key as last items if contains 4 items', () => {
      const res = getDataForUsageDisplay({
        data: [
          {
            amountCents: '42500',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'sum_bm',
          },
          {
            amountCents: '45100',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm',
          },
          {
            amountCents: '43130',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_two_dimensions',
          },
          {
            amountCents: '42300',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_one_dimension',
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.dataLinesForDisplay[res.dataLinesForDisplay.length - 1][0]).toBe(
        'count_bm_one_dimension',
      )
    })

    it('should group values with the same code', () => {
      const res = getDataForUsageDisplay({
        data: [
          {
            amountCents: '22',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'sum_bm',
          },
          {
            amountCents: '11',
            month: DateTime.now().minus({ month: 1 }).startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm',
          },
          {
            amountCents: '11',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm',
          },
          {
            amountCents: '22',
            month: DateTime.now().minus({ month: 1 }).startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'sum_bm',
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.dataLinesForDisplay.length).toBe(2)
      expect(res.dataBarForDisplay.length).toBe(1)
      expect(res.hasNoDataToDisplay).toBeFalsy()
      expect(res.dataLinesForDisplay[0][0]).toBe('sum_bm')
      expect(res.dataLinesForDisplay[0][1]).toBe(44)
      expect(res.dataLinesForDisplay[1][0]).toBe('count_bm')
      expect(res.dataLinesForDisplay[1][1]).toBe(22)
    })

    it('should group values with the same code and have an other entry for extra data', () => {
      const res = getDataForUsageDisplay({
        data: [
          {
            amountCents: '211112',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'sum_bm',
          },
          {
            amountCents: '111111',
            month: DateTime.now().minus({ month: 1 }).startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm',
          },
          {
            amountCents: '111111',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm',
          },
          {
            amountCents: '211112',
            month: DateTime.now().minus({ month: 1 }).startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'sum_bm',
          },
          {
            amountCents: '45100',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm2',
          },
          {
            amountCents: '43130',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_two_dimensions',
          },
          {
            amountCents: '42300',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'count_bm_one_dimension',
          },
          {
            amountCents: '42300',
            month: DateTime.now().startOf('month').toISO(),
            currency: CurrencyEnum.Eur,
            code: 'user_seats',
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.dataLinesForDisplay.length).toBe(5)
      expect(res.dataBarForDisplay.length).toBe(1)
      expect(res.hasNoDataToDisplay).toBeFalsy()
      expect(res.dataLinesForDisplay[0][0]).toBe('sum_bm')
      expect(res.dataLinesForDisplay[0][1]).toBe(422224)
      expect(res.dataLinesForDisplay[1][0]).toBe('count_bm')
      expect(res.dataLinesForDisplay[1][1]).toBe(222222)
      expect(res.dataLinesForDisplay[2][0]).toBe('count_bm2')
      expect(res.dataLinesForDisplay[2][1]).toBe(45100)
      expect(res.dataLinesForDisplay[3][0]).toBe('count_bm_two_dimensions')
      expect(res.dataLinesForDisplay[3][1]).toBe(43130)
      expect(res.dataLinesForDisplay[4][0]).toBe(LAST_USAGE_GRAPH_LINE_KEY_NAME)
      expect(res.dataLinesForDisplay[4][1]).toBe(84600)
    })
  })
})
