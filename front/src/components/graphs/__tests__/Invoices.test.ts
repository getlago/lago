import { DateTime } from 'luxon'

import { InvoiceCollectionsFakeData } from '~/components/designSystem/graphs/fixtures'
import {
  extractDataForDisplay,
  fillInvoicesDataPerMonthForPaymentStatus,
  formatInvoiceCollectionsData,
  getAllDataForInvoicesDisplay,
} from '~/components/graphs/Invoices'
import { AnalyticsPeriodScopeEnum } from '~/components/graphs/MonthSelectorDropdown'
import { GRAPH_YEAR_MONTH_DATE_FORMAT } from '~/components/graphs/utils'
import { CurrencyEnum, InvoicePaymentStatusTypeEnum } from '~/generated/graphql'

jest.mock('~/components/designSystem/Filters', () => ({
  buildUrlForInvoicesWithFilters: jest.fn(),
}))

describe('components/graphs/Invoices', () => {
  describe('fillInvoicesDataPerMonthForPaymentStatus', () => {
    it('should return a map with 13 entries', () => {
      const currentMonthData = {
        paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
        invoicesCount: '6',
        amountCents: '4197400',
        currency: CurrencyEnum.Eur,
        month: DateTime.now().startOf('month').toISO(),
      }
      const res = fillInvoicesDataPerMonthForPaymentStatus(
        [currentMonthData],
        InvoicePaymentStatusTypeEnum.Succeeded,
        CurrencyEnum.Eur,
      )

      expect(res.length).toBe(13)
      expect(res[0]).toStrictEqual({
        paymentStatus: currentMonthData.paymentStatus,
        invoicesCount: '0',
        amountCents: '0',
        currency: currentMonthData.currency,
        month: DateTime.now()
          .minus({ month: 12 })
          .startOf('month')
          .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      })
      expect(res[12]).toStrictEqual({
        ...currentMonthData,
        month: DateTime.fromISO(currentMonthData.month as string).toFormat(
          GRAPH_YEAR_MONTH_DATE_FORMAT,
        ),
      })
    })
  })

  describe('formatInvoiceCollectionsData', () => {
    it('should return a map with 3 entries', () => {
      const res = formatInvoiceCollectionsData([], CurrencyEnum.Usd)

      expect(res.size).toBe(3)
      expect(res.get(InvoicePaymentStatusTypeEnum.Succeeded)).toBeDefined()
      expect(res.get(InvoicePaymentStatusTypeEnum.Succeeded)?.length).toBe(13)
      expect(res.get(InvoicePaymentStatusTypeEnum.Failed)).toBeDefined()
      expect(res.get(InvoicePaymentStatusTypeEnum.Failed)?.length).toBe(13)
      expect(res.get(InvoicePaymentStatusTypeEnum.Pending)).toBeDefined()
      expect(res.get(InvoicePaymentStatusTypeEnum.Pending)?.length).toBe(13)
    })

    it('should return data included in the default 0 one', () => {
      const currentMonthData = {
        paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
        invoicesCount: '6',
        amountCents: '4197400',
        currency: CurrencyEnum.Eur,
        month: DateTime.now().startOf('month').toISO(),
      }

      const res = formatInvoiceCollectionsData([currentMonthData], CurrencyEnum.Eur)

      expect(res.get(InvoicePaymentStatusTypeEnum.Succeeded)?.[0]).toStrictEqual({
        paymentStatus: currentMonthData.paymentStatus,
        invoicesCount: '0',
        amountCents: '0',
        currency: currentMonthData.currency,
        month: DateTime.now()
          .minus({ month: 12 })
          .startOf('month')
          .toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      })
      expect(res.get(InvoicePaymentStatusTypeEnum.Succeeded)?.[12]).toStrictEqual({
        ...currentMonthData,
        month: DateTime.fromISO(currentMonthData.month as string).toFormat(
          GRAPH_YEAR_MONTH_DATE_FORMAT,
        ),
      })
    })
  })

  describe('extractDataForDisplay', () => {
    it('returns data correctly formated for display', () => {
      const currentMonthData = formatInvoiceCollectionsData(
        [
          {
            paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
            invoicesCount: '6',
            amountCents: '4197400',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
        ],
        CurrencyEnum.Eur,
      )

      const res = extractDataForDisplay(currentMonthData)

      expect(res.size).toBe(4)
      expect(res.has(InvoicePaymentStatusTypeEnum.Succeeded)).toEqual(true)
      expect(res.has(InvoicePaymentStatusTypeEnum.Failed)).toEqual(true)
      expect(res.has(InvoicePaymentStatusTypeEnum.Pending)).toEqual(true)
      expect(res.get(InvoicePaymentStatusTypeEnum.Succeeded)?.invoicesCount).toBe(6)
      expect(res.get(InvoicePaymentStatusTypeEnum.Succeeded)?.amountCents).toBe(4197400)
      expect(res.get(InvoicePaymentStatusTypeEnum.Failed)?.invoicesCount).toBe(0)
      expect(res.get(InvoicePaymentStatusTypeEnum.Failed)?.amountCents).toBe(0)
      expect(res.get(InvoicePaymentStatusTypeEnum.Pending)?.invoicesCount).toBe(0)
      expect(res.get(InvoicePaymentStatusTypeEnum.Pending)?.amountCents).toBe(0)
    })
  })

  describe('getAllDataForInvoicesDisplay', () => {
    it('should return data for year blur mode', () => {
      const res = getAllDataForInvoicesDisplay({
        data: InvoiceCollectionsFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: true,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(res.lineData.size).toBe(4)
      expect(typeof res.totalAmount).toBe('number')
      Object.values(InvoicePaymentStatusTypeEnum).forEach((status) => {
        expect(Object.keys(res.lineData.get(status) as object).sort()).toEqual([
          'amountCents',
          'invoicesCount',
        ])
      })
      expect(res.barGraphData.length).toBe(1)
      expect(Object.keys(res.barGraphData[0]).length).toBe(3)
      expect(Object.keys(res.barGraphData[0]).sort()).toEqual([
        InvoicePaymentStatusTypeEnum.Failed,
        InvoicePaymentStatusTypeEnum.Pending,
        InvoicePaymentStatusTypeEnum.Succeeded,
      ])
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should return data for year demo mode', () => {
      const res = getAllDataForInvoicesDisplay({
        data: InvoiceCollectionsFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(res.lineData.size).toBe(4)
      Object.values(InvoicePaymentStatusTypeEnum).forEach((status) => {
        expect(Object.keys(res.lineData.get(status) as object).sort()).toEqual([
          'amountCents',
          'invoicesCount',
        ])
      })
      expect(res.barGraphData.length).toBe(1)
      expect(Object.keys(res.barGraphData[0]).length).toBe(3)
      expect(Object.keys(res.barGraphData[0]).sort()).toEqual([
        InvoicePaymentStatusTypeEnum.Failed,
        InvoicePaymentStatusTypeEnum.Pending,
        InvoicePaymentStatusTypeEnum.Succeeded,
      ])
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 12 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should return data for quarter demo mode', () => {
      const res = getAllDataForInvoicesDisplay({
        data: InvoiceCollectionsFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Quarter,
      })

      expect(res.lineData.size).toBe(4)
      Object.values(InvoicePaymentStatusTypeEnum).forEach((status) => {
        expect(Object.keys(res.lineData.get(status) as object).sort()).toEqual([
          'amountCents',
          'invoicesCount',
        ])
      })
      expect(res.barGraphData.length).toBe(1)
      expect(Object.keys(res.barGraphData[0]).length).toBe(3)
      expect(Object.keys(res.barGraphData[0]).sort()).toEqual([
        InvoicePaymentStatusTypeEnum.Failed,
        InvoicePaymentStatusTypeEnum.Pending,
        InvoicePaymentStatusTypeEnum.Succeeded,
      ])
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 3 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should return data for month demo mode', () => {
      const res = getAllDataForInvoicesDisplay({
        data: InvoiceCollectionsFakeData,
        currency: CurrencyEnum.Eur,
        demoMode: true,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Month,
      })

      expect(res.lineData.size).toBe(4)
      Object.values(InvoicePaymentStatusTypeEnum).forEach((status) => {
        expect(Object.keys(res.lineData.get(status) as object).sort()).toEqual([
          'amountCents',
          'invoicesCount',
        ])
      })
      expect(res.barGraphData.length).toBe(1)
      expect(Object.keys(res.barGraphData[0]).length).toBe(3)
      expect(Object.keys(res.barGraphData[0]).sort()).toEqual([
        InvoicePaymentStatusTypeEnum.Failed,
        InvoicePaymentStatusTypeEnum.Pending,
        InvoicePaymentStatusTypeEnum.Succeeded,
      ])
      expect(res.dateFrom).toBe(
        DateTime.now().minus({ month: 1 }).startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
      expect(res.dateTo).toBe(
        DateTime.now().startOf('month').toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      )
    })

    it('should return custom barGraphData if all values are 0', () => {
      const res = getAllDataForInvoicesDisplay({
        data: [
          {
            paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
            invoicesCount: '0',
            amountCents: '0',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
          {
            paymentStatus: InvoicePaymentStatusTypeEnum.Failed,
            invoicesCount: '0',
            amountCents: '0',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
          {
            paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
            invoicesCount: '0',
            amountCents: '0',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(res.barGraphData.length).toBe(1)
      expect(Object.keys(res.barGraphData[0]).length).toBe(3)
      expect(Object.keys(res.barGraphData[0]).sort()).toEqual([
        InvoicePaymentStatusTypeEnum.Failed,
        InvoicePaymentStatusTypeEnum.Pending,
        InvoicePaymentStatusTypeEnum.Succeeded,
      ])
      expect(res.barGraphData[0][InvoicePaymentStatusTypeEnum.Succeeded]).toBe(1)
      expect(res.barGraphData[0][InvoicePaymentStatusTypeEnum.Pending]).toBe(1)
      expect(res.barGraphData[0][InvoicePaymentStatusTypeEnum.Failed]).toBe(1)
    })

    it('should return correct totalAmount', () => {
      const res = getAllDataForInvoicesDisplay({
        data: [
          {
            paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
            invoicesCount: '1',
            amountCents: '1',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
          {
            paymentStatus: InvoicePaymentStatusTypeEnum.Failed,
            invoicesCount: '1',
            amountCents: '1',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
          {
            paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
            invoicesCount: '1',
            amountCents: '1',
            currency: CurrencyEnum.Eur,
            month: DateTime.now().startOf('month').toISO(),
          },
        ],
        currency: CurrencyEnum.Eur,
        demoMode: false,
        blur: false,
        period: AnalyticsPeriodScopeEnum.Year,
      })

      expect(res.totalAmount).toBe(2)
    })
  })
})
