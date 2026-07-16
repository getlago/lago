import { DateTime } from 'luxon'

import { AvailableFiltersEnum, filterDataInlineSeparator } from '../types'
import {
  defineDefaultToDateValue,
  escapeFilterLabel,
  FILTER_VALUE_MAP,
  formatActiveFilterValueDisplay,
  formatFiltersForCreditNotesQuery,
  formatFiltersForCustomerQuery,
  formatFiltersForInvoiceQuery,
  formatFiltersForMrrQuery,
  formatFiltersForOrderFormsQuery,
  formatFiltersForOrdersQuery,
  formatFiltersForQuery,
  formatFiltersForQuotesQuery,
  formatFiltersForRevenueStreamsQuery,
  formatFiltersForSecurityLogsQuery,
  formatFiltersForSubscriptionQuery,
  formatFiltersForWebhookLogsQuery,
  formatMetadataFilter,
  getFilterValue,
  keyWithPrefix,
  parseFromToValue,
  parseMetadataFilter,
  unescapeFilterLabel,
} from '../utils'

describe('Filters utils', () => {
  describe('formatFiltersForInvoiceQuery', () => {
    it('should format filters for invoice query', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('paymentStatus', 'failed,pending')
      searchParams.set('invoiceType', 'advance_charges,credit,one_off,subscription')
      searchParams.set('status', 'finalized')
      searchParams.set('paymentDisputeLost', 'false')
      searchParams.set('paymentOverdue', 'true')
      searchParams.set(
        'customerExternalId',
        `externalCustomerIdValue${filterDataInlineSeparator}my name to be displayed`,
      )
      searchParams.set('randomSearchUrlParam', 'anditsvalue')

      const result = formatFiltersForInvoiceQuery(searchParams)

      expect(result).toEqual({
        customerExternalId: 'externalCustomerIdValue',
        invoiceType: ['advance_charges', 'credit', 'one_off', 'subscription'],
        paymentDisputeLost: false,
        paymentOverdue: true,
        paymentStatus: ['failed', 'pending'],
        status: ['finalized'],
      })

      expect(result).not.toHaveProperty('randomSearchUrlParam')
    })

    it('should return empty object when filters are not valid', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('invalidFilter', 'value')

      const result = formatFiltersForInvoiceQuery(searchParams)

      expect(result).toEqual({})
    })
  })

  describe('formatFiltersForRevenueStreamsQuery', () => {
    it('should format filters for revenue streams query', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('timeGranularity', 'day')
      searchParams.set('customerType', 'company')
      searchParams.set('invoiceType', 'advance_charges,credit,one_off,subscription')
      searchParams.set('status', 'finalized')
      searchParams.set('currency', 'USD')
      searchParams.set('paymentOverdue', 'true')
      searchParams.set('date', '2022-01-01,2022-01-31')
      searchParams.set('country', 'US')
      searchParams.set(
        'customerExternalId',
        `externalCustomerIdValue${filterDataInlineSeparator}my name to be displayed`,
      )
      searchParams.set('planCode', 'planCodeValue')
      searchParams.set('partiallyPaid', 'true')
      searchParams.set('selfBilled', 'true')

      const result = formatFiltersForRevenueStreamsQuery(searchParams)

      expect(result).toEqual({
        customerType: 'company',
        fromDate: '2022-01-01',
        planCode: 'planCodeValue',
        timeGranularity: 'day',
        toDate: '2022-01-31',
        currency: 'USD',
        customerCountry: 'US',
        externalCustomerId: 'externalCustomerIdValue',
      })
    })
  })

  describe('formatFiltersForCreditNotesQuery', () => {
    it('should format filters for credit notes query', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('cn_creditNoteCreditStatus', 'available,consumed')
      searchParams.set('cn_creditNoteRefundStatus', 'pending,succeeded')
      searchParams.set('cn_creditNoteReason', 'duplicated_charge,order_change')
      searchParams.set('cn_creditNoteType', 'credit,refund')
      searchParams.set('cn_currency', 'USD')
      searchParams.set('cn_invoiceNumber', 'INV-001')
      searchParams.set('cn_selfBilled', 'true')
      searchParams.set(
        'cn_customerExternalId',
        `externalCustomerIdValue${filterDataInlineSeparator}my name to be displayed`,
      )

      const result = formatFiltersForCreditNotesQuery(searchParams)

      expect(result).toEqual({
        creditStatus: ['available', 'consumed'],
        refundStatus: ['pending', 'succeeded'],
        reason: ['duplicated_charge', 'order_change'],
        types: ['credit', 'refund'],
        currency: 'USD',
        invoiceNumber: 'INV-001',
        selfBilled: true,
        customerExternalId: 'externalCustomerIdValue',
      })
    })

    it('should format credit note type filter with all types', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('cn_creditNoteType', 'credit,refund,offset')

      const result = formatFiltersForCreditNotesQuery(searchParams)

      expect(result).toEqual({
        types: ['credit', 'refund', 'offset'],
      })
    })

    it('should format credit note type filter with single type', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('cn_creditNoteType', 'offset')

      const result = formatFiltersForCreditNotesQuery(searchParams)

      expect(result).toEqual({
        types: ['offset'],
      })
    })

    it('should return empty object when filters are not valid', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('invalidFilter', 'value')

      const result = formatFiltersForCreditNotesQuery(searchParams)

      expect(result).toEqual({})
    })
  })

  describe('formatFiltersForCustomerQuery', () => {
    it('should format filters for customer query', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('cu_externalId', 'customer_external_id_123')
      searchParams.set('cu_customerType', 'company')
      searchParams.set('cu_countries', 'US,FR')
      searchParams.set('cu_currencies', 'USD,EUR')
      searchParams.set('cu_zipcodes', '12345,67890')

      const result = formatFiltersForCustomerQuery(searchParams)

      expect(result).toEqual({
        externalId: 'customer_external_id_123',
        customerType: 'company',
        countries: ['US', 'FR'],
        currencies: ['USD', 'EUR'],
        zipcodes: ['12345', '67890'],
      })
    })

    it('should rename activeSubscriptions keys for customer query', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('cu_activeSubscriptions', 'isBetween,2,5')

      const result = formatFiltersForCustomerQuery(searchParams)

      expect(result).toEqual({
        activeSubscriptionsCountFrom: 2,
        activeSubscriptionsCountTo: 5,
      })
    })

    it('should map isCustomerTinEmpty ("Customer has Tax ID") onto hasTaxIdentificationNumber', () => {
      const searchParams = new URLSearchParams()

      // The URL value reflects the "Customer has Tax ID" label: 'true' means the customer has one
      searchParams.set('cu_isCustomerTinEmpty', 'true')

      expect(formatFiltersForCustomerQuery(searchParams)).toEqual({
        hasTaxIdentificationNumber: true,
      })

      searchParams.set('cu_isCustomerTinEmpty', 'false')

      expect(formatFiltersForCustomerQuery(searchParams)).toEqual({
        hasTaxIdentificationNumber: false,
      })
    })

    it('should return empty object when filters are not valid', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('invalidFilter', 'value')

      const result = formatFiltersForCustomerQuery(searchParams)

      expect(result).toEqual({})
    })
  })

  describe('formatFiltersForSubscriptionQuery', () => {
    it('should format filters for subscription query', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('sub_externalId', 'subscription_external_id_123')
      searchParams.set('sub_planCode', 'planCodeValue')
      searchParams.set('sub_overriden', 'true')
      searchParams.set('sub_subscriptionStatus', 'active,pending')
      searchParams.set(
        'sub_customerExternalId',
        `externalCustomerIdValue${filterDataInlineSeparator}my name to be displayed`,
      )

      const result = formatFiltersForSubscriptionQuery(searchParams)

      expect(result).toEqual({
        externalId: 'subscription_external_id_123',
        planCode: 'planCodeValue',
        overriden: true,
        status: ['active', 'pending'],
        externalCustomerId: 'externalCustomerIdValue',
      })
    })

    it('should return empty object when filters are not valid', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('invalidFilter', 'value')

      const result = formatFiltersForSubscriptionQuery(searchParams)

      expect(result).toEqual({})
    })
  })

  describe('formatFiltersForMrrQuery', () => {
    it('should format filters for MRR query', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('timeGranularity', 'month')
      searchParams.set('customerType', 'individual')
      searchParams.set('invoiceType', 'advance_charges,credit,one_off,subscription')
      searchParams.set('status', 'finalized')
      searchParams.set('currency', 'EUR')
      searchParams.set('paymentOverdue', 'true')
      searchParams.set('date', '2023-01-01,2023-01-31')
      searchParams.set('country', 'FR')
      searchParams.set(
        'customerExternalId',
        `customer123${filterDataInlineSeparator}Customer Display Name`,
      )
      searchParams.set('planCode', 'premium')
      searchParams.set('partiallyPaid', 'true')
      searchParams.set('selfBilled', 'true')

      const result = formatFiltersForMrrQuery(searchParams)

      expect(result).toEqual({
        customerType: 'individual',
        fromDate: '2023-01-01',
        timeGranularity: 'month',
        toDate: '2023-01-31',
        currency: 'EUR',
        customerCountry: 'FR',
        externalCustomerId: 'customer123',
      })
    })
  })

  describe('formatActiveFilterValueDisplay', () => {
    it('should format active filter country value display', () => {
      const result = formatActiveFilterValueDisplay(AvailableFiltersEnum.country, 'US')

      expect(result).toBe('US')
    })
    it('should format active filter currency value display', () => {
      const result = formatActiveFilterValueDisplay(AvailableFiltersEnum.currency, 'USD')

      expect(result).toBe('USD')
    })
    it('should format active filter customerExternalId value display', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.customerExternalId,
        `externalCustomerIdValue${filterDataInlineSeparator}my name to be displayed`,
      )

      expect(result).toBe('my name to be displayed')
    })
    it('should format active filter issuingDate value display', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.issuingDate,
        '2022-01-01,2022-01-31',
      )

      expect(result).toBe('1/1/2022 - 1/31/2022')
    })
    it('should format active filter date value display', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.date,
        '2022-01-01,2022-01-31',
      )

      expect(result).toBe('1/1/2022 - 1/31/2022')
    })
    it('should format active filter paymentStatus value display', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.paymentStatus,
        'failed,pending',
      )

      expect(result).toBe('Failed, Pending')
    })
    it('should format active filter planCode value display', () => {
      const result = formatActiveFilterValueDisplay(AvailableFiltersEnum.planCode, 'planCodeValue')

      expect(result).toBe('PlanCodeValue')
    })
    it('should format active filter paymentDisputeLost value display', () => {
      const result = formatActiveFilterValueDisplay(AvailableFiltersEnum.paymentDisputeLost, 'true')

      expect(result).toBe('True')
    })
    it('should format active filter paymentOverdue value display', () => {
      const result = formatActiveFilterValueDisplay(AvailableFiltersEnum.paymentOverdue, 'true')

      expect(result).toBe('True')
    })
    it('should format active filter invoiceType value display', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.invoiceType,
        'advance_charges,credit,one_off,subscription',
      )

      expect(result).toBe('Advance charges, Credit, One off, Subscription')
    })
    it('should format active filter status value display', () => {
      const result = formatActiveFilterValueDisplay(AvailableFiltersEnum.status, 'finalized')

      expect(result).toBe('Finalized')
    })
    it('should format active filter subscriptionExternalId value display', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.subscriptionExternalId,
        '1234',
      )

      expect(result).toBe('1234')
    })
    it('should format active filter externalId value display keeping the raw value', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.externalId,
        'external_id_123',
      )

      expect(result).toBe('external_id_123')
    })
    it('should format active filter timeGranularity value display', () => {
      const result = formatActiveFilterValueDisplay(AvailableFiltersEnum.timeGranularity, 'daily')

      expect(result).toBe('Daily')
    })
    it('should format active filter quoteCreatedAt value display', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.quoteCreatedAt,
        '2026-01-01,2026-01-31',
      )

      expect(result).toBe('1/1/2026 - 1/31/2026')
    })
    it('should format active filter multipleCustomers value display extracting names', () => {
      const result = formatActiveFilterValueDisplay(
        AvailableFiltersEnum.multipleCustomers,
        `cust-1${filterDataInlineSeparator}Acme Corp,cust-2${filterDataInlineSeparator}Beta Inc`,
      )

      expect(result).toBe('Acme Corp, Beta Inc')
    })
  })

  describe('getFilterValue', () => {
    it('should return null when filter value is not set', () => {
      const searchParams = new URLSearchParams()

      const result = getFilterValue({
        key: AvailableFiltersEnum.timeGranularity,
        searchParams,
      })

      expect(result).toBeNull()
    })

    it('should get filter value', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('timeGranularity', 'day')
      searchParams.set('randomFilter', 'randomValue')

      const result = getFilterValue({
        key: AvailableFiltersEnum.timeGranularity,
        searchParams,
      })

      expect(result).toBe('day')
    })

    it('should get filter value with prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('timeGranularity', 'daily')
      searchParams.set('rs_timeGranularity', 'monthly')
      searchParams.set('rs_randomFilter', 'randomValue')

      const result = getFilterValue({
        key: AvailableFiltersEnum.timeGranularity,
        searchParams,
        prefix: 'rs',
      })

      expect(result).toBe('monthly')
    })
  })

  describe('parseFromToValue', () => {
    it('should handle zero values correctly', () => {
      const result = parseFromToValue('isEqualTo,0,0', { from: 'from', to: 'to' })

      expect(result).toEqual({
        from: 0,
        to: 0,
      })
    })

    it('should handle empty values correctly', () => {
      const result = parseFromToValue('isEqualTo,,', { from: 'from', to: 'to' })

      expect(result).toEqual({
        from: null,
        to: null,
      })
    })

    it('should handle positive numbers correctly', () => {
      const result = parseFromToValue('isBetween,5,10', { from: 'from', to: 'to' })

      expect(result).toEqual({
        from: 5,
        to: 10,
      })
    })

    it('should handle isEqualTo interval', () => {
      const result = parseFromToValue('isEqualTo,7,', { from: 'from', to: 'to' })

      expect(result).toEqual({
        from: 7,
        to: 7,
      })
    })

    it('should handle isBetween interval', () => {
      const result = parseFromToValue('isBetween,3,8', { from: 'from', to: 'to' })

      expect(result).toEqual({
        from: 3,
        to: 8,
      })
    })

    it('should handle isLessThan interval', () => {
      const result = parseFromToValue('isLessThan,,15', { from: 'from', to: 'to' })

      expect(result).toEqual({
        from: null,
        to: 15,
      })
    })

    it('should handle isGreaterThan interval', () => {
      const result = parseFromToValue('isGreaterThan,20,', { from: 'from', to: 'to' })

      expect(result).toEqual({
        from: 20,
        to: null,
      })
    })
  })

  describe('formatFiltersForQuery', () => {
    it('should format filters without prefix and keyMap', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('country', 'US')
      searchParams.set('currency', 'USD')
      searchParams.set('customerType', 'company')
      searchParams.set('invalidFilter', 'shouldBeIgnored')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [
          AvailableFiltersEnum.country,
          AvailableFiltersEnum.currency,
          AvailableFiltersEnum.customerType,
        ],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        country: 'US',
        currency: 'USD',
        customerType: 'company',
      })
      expect(result).not.toHaveProperty('invalidFilter')
    })

    it('should format filters with prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('rs_country', 'FR')
      searchParams.set('rs_currency', 'EUR')
      searchParams.set('rs_timeGranularity', 'month')
      searchParams.set('other_filter', 'shouldBeIgnored')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [
          AvailableFiltersEnum.country,
          AvailableFiltersEnum.currency,
          AvailableFiltersEnum.timeGranularity,
        ],
        filtersNamePrefix: 'rs',
      })

      expect(result).toEqual({
        country: 'FR',
        currency: 'EUR',
        timeGranularity: 'month',
      })
      expect(result).not.toHaveProperty('other_filter')
    })

    it('should format filters with keyMap', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('country', 'US')
      searchParams.set('currency', 'USD')

      const keyMap = {
        [AvailableFiltersEnum.country]: 'customerCountry',
        [AvailableFiltersEnum.currency]: 'customerCurrency',
      }

      const result = formatFiltersForQuery({
        searchParams,
        keyMap,
        availableFilters: [AvailableFiltersEnum.country, AvailableFiltersEnum.currency],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        customerCountry: 'US',
        customerCurrency: 'USD',
      })
    })

    it('should apply filter value transformations', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('paymentStatus', 'failed,pending')
      searchParams.set('paymentOverdue', 'true')
      searchParams.set('amount', 'isBetween,10,100')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [
          AvailableFiltersEnum.paymentStatus,
          AvailableFiltersEnum.paymentOverdue,
          AvailableFiltersEnum.amount,
        ],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        paymentStatus: ['failed', 'pending'],
        paymentOverdue: true,
        amountFrom: 10,
        amountTo: 100,
      })
    })

    it('should handle date filters that return objects', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('date', '2023-01-01,2023-01-31')
      searchParams.set('issuingDate', '2023-02-01,2023-02-28')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [AvailableFiltersEnum.date, AvailableFiltersEnum.issuingDate],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        fromDate: '2023-01-01',
        toDate: '2023-01-31',
        issuingDateFrom: '2023-02-01',
        issuingDateTo: '2023-02-28',
      })
    })

    it('should handle customerExternalId with separator', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'customerExternalId',
        `customer123${filterDataInlineSeparator}Customer Display Name`,
      )

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [AvailableFiltersEnum.customerExternalId],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        customerExternalId: 'customer123',
      })
    })

    it('should handle boolean filters correctly', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('paymentOverdue', 'true')
      searchParams.set('paymentDisputeLost', 'false')
      searchParams.set('selfBilled', 'true')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [
          AvailableFiltersEnum.paymentOverdue,
          AvailableFiltersEnum.paymentDisputeLost,
          AvailableFiltersEnum.selfBilled,
        ],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        paymentOverdue: true,
        paymentDisputeLost: false,
        selfBilled: true,
      })
    })

    it('should handle array filters correctly', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('invoiceType', 'subscription,one_off')
      searchParams.set('status', 'finalized,draft')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [AvailableFiltersEnum.invoiceType, AvailableFiltersEnum.status],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        invoiceType: ['subscription', 'one_off'],
        status: ['finalized', 'draft'],
      })
    })

    it('should handle filters with no transformation function', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('planCode', 'premium')
      searchParams.set('invoiceNumber', 'INV-001')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [AvailableFiltersEnum.planCode, AvailableFiltersEnum.invoiceNumber],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        planCode: 'premium',
        invoiceNumber: 'INV-001',
      })
    })

    it('should return empty object when no valid filters are provided', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('invalidFilter', 'value')
      searchParams.set('anotherInvalid', 'anotherValue')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [AvailableFiltersEnum.country, AvailableFiltersEnum.currency],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({})
    })

    it('should handle mixed valid and invalid filters', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('country', 'US')
      searchParams.set('invalidFilter', 'shouldBeIgnored')
      searchParams.set('currency', 'USD')
      searchParams.set('anotherInvalid', 'alsoIgnored')

      const result = formatFiltersForQuery({
        searchParams,
        availableFilters: [AvailableFiltersEnum.country, AvailableFiltersEnum.currency],
        filtersNamePrefix: '',
      })

      expect(result).toEqual({
        country: 'US',
        currency: 'USD',
      })
      expect(result).not.toHaveProperty('invalidFilter')
      expect(result).not.toHaveProperty('anotherInvalid')
    })

    it('should handle filters with prefix and keyMap together', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('rs_country', 'FR')
      searchParams.set('rs_currency', 'EUR')

      const keyMap = {
        [AvailableFiltersEnum.country]: 'customerCountry',
        [AvailableFiltersEnum.currency]: 'customerCurrency',
      }

      const result = formatFiltersForQuery({
        searchParams,
        keyMap,
        availableFilters: [AvailableFiltersEnum.country, AvailableFiltersEnum.currency],
        filtersNamePrefix: 'rs',
      })

      expect(result).toEqual({
        customerCountry: 'FR',
        customerCurrency: 'EUR',
      })
    })
  })

  describe('defineDefaultToDateValue', () => {
    const filtersNamePrefix = 'test'
    const loggedDateKey = keyWithPrefix(AvailableFiltersEnum.loggedDate, filtersNamePrefix)

    const currentTimeString = '2023-06-15T10:30:00.000Z'
    const mockCurrentTime = DateTime.fromISO(currentTimeString).setZone('utc') as DateTime<true>
    const fromDate = mockCurrentTime.minus({ days: 1 }).toISO()

    let mockNow: jest.SpyInstance

    beforeEach(() => {
      // Mock DateTime.now() to return a consistent date for testing
      mockNow = jest.spyOn(DateTime, 'now').mockImplementation(() => mockCurrentTime)
    })

    afterEach(() => {
      jest.restoreAllMocks()
    })

    it('should set default loggedDate when no existing value is present', () => {
      const searchParams = new URLSearchParams()

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      expect(result.get(loggedDateKey)).toBe(`,${currentTimeString}`)
    })

    it('should set default loggedDate with empty prefix when no existing value is present', () => {
      const searchParams = new URLSearchParams()

      const result = defineDefaultToDateValue(searchParams, '')

      expect(result.get(keyWithPrefix(AvailableFiltersEnum.loggedDate, ''))).toBe(
        `,${currentTimeString}`,
      )
    })

    it('should preserve existing searchParams when setting default loggedDate', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('existingParam', 'existingValue')

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      expect(result.get('existingParam')).toBe('existingValue')
      expect(result.get(loggedDateKey)).toBe(`,${currentTimeString}`)
    })

    it('should use current time as toDate when existing toDate is in the future', () => {
      const searchParams = new URLSearchParams()
      const futureDate = mockCurrentTime.plus({ days: 1 }).toISO()

      searchParams.set(loggedDateKey, `${fromDate},${futureDate}`)

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      expect(result.get(loggedDateKey)).toBe(`${fromDate},${currentTimeString}`)
    })

    it('should preserve existing toDate when it is in the past', () => {
      const searchParams = new URLSearchParams()
      const pastDate = mockCurrentTime.minus({ days: 1 }).toISO()

      searchParams.set(loggedDateKey, `${fromDate},${pastDate}`)

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      // Should use the end of day for the past date
      const expectedEndOfDay = DateTime.fromISO(pastDate).endOf('day').toISO()

      expect(result.get(loggedDateKey)).toBe(`${fromDate},${expectedEndOfDay}`)
    })

    it('should use current time when existing toDate end of day is greater than now', () => {
      const searchParams = new URLSearchParams()
      const currentDate = mockCurrentTime.minus({ hours: 2 }).toISO()

      searchParams.set(loggedDateKey, `${fromDate},${currentDate}`)

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      // Should use current time because end of day for currentDate would be greater than now
      expect(result.get(loggedDateKey)).toBe(`${fromDate},${currentTimeString}`)
    })

    it('should handle existing loggedDate with only fromDate', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(loggedDateKey, `${fromDate},`)

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      expect(result.get(loggedDateKey)).toBe(`${fromDate},${currentTimeString}`)
    })

    it('should handle existing loggedDate with only toDate', () => {
      const searchParams = new URLSearchParams()
      const pastDate = mockCurrentTime.minus({ days: 1 }).toISO()

      searchParams.set(loggedDateKey, `,${pastDate}`)

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      const expectedEndOfDay = DateTime.fromISO(pastDate).endOf('day').toISO()

      expect(result.get(loggedDateKey)).toBe(`,${expectedEndOfDay}`)
    })

    it('should return a new URLSearchParams instance without modifying the original', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('existingParam', 'existingValue')

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      // Original should remain unchanged
      expect(searchParams.get(loggedDateKey)).toBeNull()
      expect(searchParams.get('existingParam')).toBe('existingValue')

      // Result should have the new value
      expect(result.get(loggedDateKey)).toBe(`,${currentTimeString}`)
      expect(result.get('existingParam')).toBe('existingValue')

      // Should be different instances
      expect(result).not.toBe(searchParams)
    })

    it('should handle edge case where toDate is exactly at end of current day', () => {
      // Mock current time to be at start of day
      const startOfDayTimeString = mockCurrentTime.startOf('day').toISO()

      mockNow.mockImplementation(() => DateTime.fromISO(startOfDayTimeString).setZone('utc'))

      const searchParams = new URLSearchParams()
      const endOfCurrentDay = mockCurrentTime.endOf('day').toISO()

      searchParams.set(loggedDateKey, `${fromDate},${endOfCurrentDay}`)

      const result = defineDefaultToDateValue(searchParams, filtersNamePrefix)

      // Since endOfCurrentDay.endOf('day') would be greater than current time (start of day),
      // it should use the current time instead
      expect(result.get(loggedDateKey)).toBe(`${fromDate},${startOfDayTimeString}`)
    })
  })

  describe('parseMetadataFilter', () => {
    it('should parse metadata filter correctly on a single pair', () => {
      const expected = [
        {
          key: 'metadata',
          value: 'value',
        },
      ]

      const result = parseMetadataFilter('metadata=value')

      expect(result).toEqual(expected)
    })

    it('should parse metadata filter correctly on a multi pair', () => {
      const expected = [
        {
          key: 'metadata',
          value: 'value',
        },
        {
          key: 'anotherMetadata',
          value: 'value',
        },
      ]

      const result = parseMetadataFilter('metadata=value&anotherMetadata=value')

      expect(result).toEqual(expected)
    })

    it('should parse metadata filter correctly even without value', () => {
      const expected = [
        {
          key: 'metadata',
          value: '',
        },
      ]

      const result = parseMetadataFilter('metadata')

      expect(result).toEqual(expected)
    })

    it('should parse metadata filter correctly on an empty string', () => {
      const result = parseMetadataFilter('')

      expect(result).toEqual([])
    })
  })

  describe('FILTER_VALUE_MAP', () => {
    it('should parse creditNoteType filter correctly', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.creditNoteType]('credit,refund,offset')

      expect(result).toEqual(['credit', 'refund', 'offset'])
    })

    it('should parse creditNoteType filter with single value', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.creditNoteType]('credit')

      expect(result).toEqual(['credit'])
    })

    it('should parse logEvents filter correctly', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.logEvents](
        'api_key_created,user_signed_up',
      )

      expect(result).toEqual(['api_key_created', 'user_signed_up'])
    })

    it('should parse logTypes filter correctly', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.logTypes]('api_key,user')

      expect(result).toEqual(['api_key', 'user'])
    })

    it('should parse userIds filter and extract ids before separator', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.userIds](
        `user-1${filterDataInlineSeparator}alice@example.com,user-2${filterDataInlineSeparator}bob@example.com`,
      )

      expect(result).toEqual(['user-1', 'user-2'])
    })

    it('should parse multipleCustomers filter and extract ids before separator', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.multipleCustomers](
        `cust-1${filterDataInlineSeparator}Acme Corp,cust-2${filterDataInlineSeparator}Beta Inc`,
      )

      expect(result).toEqual(['cust-1', 'cust-2'])
    })

    it('should parse quoteCreatedAt filter into fromDate and toDate', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.quoteCreatedAt]('2026-01-01,2026-01-31')

      expect(result).toEqual({ fromDate: '2026-01-01', toDate: '2026-01-31' })
    })

    it('should parse quoteNumber filter correctly', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.quoteNumber]('QT-001,QT-002')

      expect(result).toEqual(['QT-001', 'QT-002'])
    })

    it('should parse quoteOrderType filter correctly', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.quoteOrderType](
        'one_off,subscription_creation',
      )

      expect(result).toEqual(['one_off', 'subscription_creation'])
    })

    it('should parse quoteStatus filter correctly', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.quoteStatus]('draft,approved')

      expect(result).toEqual(['draft', 'approved'])
    })
  })

  describe('formatMetadataFilter', () => {
    it('should format metadata filter correctly on a single pair', () => {
      const value = [
        {
          key: 'metadata',
          value: 'value',
        },
      ]

      const expected = 'metadata=value'

      const result = formatMetadataFilter(value)

      expect(result).toEqual(expected)
    })

    it('should format metadata filter correctly on a multi pair', () => {
      const value = [
        {
          key: 'metadata',
          value: 'value',
        },
        {
          key: 'anotherMetadata',
          value: 'value',
        },
      ]

      const expected = 'metadata=value&anotherMetadata=value'

      const result = formatMetadataFilter(value)

      expect(result).toEqual(expected)
    })

    it('should format metadata filter correctly even without value', () => {
      const value = [
        {
          key: 'metadata',
          value: '',
        },
      ]

      const expected = 'metadata='

      const result = formatMetadataFilter(value)

      expect(result).toEqual(expected)
    })

    it('should format metadata filter correctly on an empty array', () => {
      const result = formatMetadataFilter([])

      expect(result).toEqual('')
    })
  })

  describe('formatFiltersForWebhookLogsQuery', () => {
    it('should format webhook status filter with key mapping', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('dw_webhookStatus', 'succeeded,failed')

      const result = formatFiltersForWebhookLogsQuery(searchParams)

      expect(result).toHaveProperty('statuses', ['succeeded', 'failed'])
    })

    it('should format webhook event types filter with key mapping', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('dw_webhookEventTypes', 'invoice.created,customer.created')

      const result = formatFiltersForWebhookLogsQuery(searchParams)

      expect(result).toHaveProperty('eventTypes', ['invoice.created', 'customer.created'])
    })

    it('should format webhook http statuses filter with key mapping', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('dw_webhookHttpStatuses', '200,404,500')

      const result = formatFiltersForWebhookLogsQuery(searchParams)

      expect(result).toHaveProperty('httpStatuses', ['200', '404', '500'])
    })

    it('should format webhook date filter', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('dw_webhookDate', '2024-01-01T00:00:00.000Z,2024-01-31T23:59:59.000Z')

      const result = formatFiltersForWebhookLogsQuery(searchParams)

      expect(result).toHaveProperty('fromDate', '2024-01-01T00:00:00.000Z')
      expect(result).toHaveProperty('toDate')
    })

    it('should set default toDate when no date filter is provided', () => {
      const searchParams = new URLSearchParams()

      const result = formatFiltersForWebhookLogsQuery(searchParams)

      expect(result).toHaveProperty('toDate')
    })

    it('should ignore filters not in WebhookLogsAvailableFilters', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('dw_paymentStatus', 'failed')

      const result = formatFiltersForWebhookLogsQuery(searchParams)

      expect(result).not.toHaveProperty('paymentStatus')
    })

    it('should format all webhook filters together', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('dw_webhookStatus', 'failed')
      searchParams.set('dw_webhookEventTypes', 'invoice.created')
      searchParams.set('dw_webhookHttpStatuses', '500')

      const result = formatFiltersForWebhookLogsQuery(searchParams)

      expect(result).toHaveProperty('statuses', ['failed'])
      expect(result).toHaveProperty('eventTypes', ['invoice.created'])
      expect(result).toHaveProperty('httpStatuses', ['500'])
    })
  })

  describe('FILTER_VALUE_MAP webhook entries', () => {
    it('should parse webhookDate filter', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookDate](
        '2024-01-01T00:00:00.000Z,2024-01-31T23:59:59.000Z',
      )

      expect(result).toEqual({
        fromDate: '2024-01-01T00:00:00.000Z',
        toDate: '2024-01-31T23:59:59.000Z',
      })
    })

    it('should parse webhookDate filter with only fromDate', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookDate]('2024-01-01T00:00:00.000Z,')

      expect(result).toEqual({
        fromDate: '2024-01-01T00:00:00.000Z',
        toDate: undefined,
      })
    })

    it('should parse webhookDate filter with only toDate', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookDate](',2024-01-31T23:59:59.000Z')

      expect(result).toEqual({
        fromDate: undefined,
        toDate: '2024-01-31T23:59:59.000Z',
      })
    })

    it('should parse webhookEventTypes filter', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookEventTypes](
        'invoice.created,customer.created,subscription.updated',
      )

      expect(result).toEqual(['invoice.created', 'customer.created', 'subscription.updated'])
    })

    it('should parse webhookEventTypes filter with single value', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookEventTypes]('invoice.created')

      expect(result).toEqual(['invoice.created'])
    })

    it('should parse webhookHttpStatuses filter', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookHttpStatuses]('200,404,500')

      expect(result).toEqual(['200', '404', '500'])
    })

    it('should parse webhookHttpStatuses filter with single value', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookHttpStatuses]('200')

      expect(result).toEqual(['200'])
    })

    it('should parse webhookStatus filter', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookStatus]('succeeded,failed')

      expect(result).toEqual(['succeeded', 'failed'])
    })

    it('should parse webhookStatus filter with single value', () => {
      const result = FILTER_VALUE_MAP[AvailableFiltersEnum.webhookStatus]('pending')

      expect(result).toEqual(['pending'])
    })
  })
  describe('formatFiltersForSecurityLogsQuery', () => {
    const currentTimeString = '2025-06-15T10:30:00.000Z'
    const mockCurrentTime = DateTime.fromISO(currentTimeString).setZone('utc') as DateTime<true>

    beforeEach(() => {
      jest.spyOn(DateTime, 'now').mockImplementation(() => mockCurrentTime)
    })

    afterEach(() => {
      jest.restoreAllMocks()
    })

    it('should format security log filters with prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('secul_logEvents', 'api_key_created,user_signed_up')
      searchParams.set('secul_logTypes', 'api_key,user')
      searchParams.set(
        'secul_userIds',
        `user-1${filterDataInlineSeparator}alice@example.com,user-2${filterDataInlineSeparator}bob@example.com`,
      )

      const result = formatFiltersForSecurityLogsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          logEvents: ['api_key_created', 'user_signed_up'],
          logTypes: ['api_key', 'user'],
          userIds: ['user-1', 'user-2'],
        }),
      )
    })

    it('should format security log filters with loggedDate', () => {
      const searchParams = new URLSearchParams()
      const pastDate = mockCurrentTime.minus({ days: 30 }).toISO()

      searchParams.set('secul_loggedDate', `${pastDate},${currentTimeString}`)

      const result = formatFiltersForSecurityLogsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          fromDate: pastDate,
          toDate: currentTimeString,
        }),
      )
    })

    it('should inject default toDate when no loggedDate is provided', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('secul_logEvents', 'api_key_created')

      const result = formatFiltersForSecurityLogsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          logEvents: ['api_key_created'],
          fromDate: undefined,
          toDate: currentTimeString,
        }),
      )
    })

    it('should ignore filters with a different prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('actl_logEvents', 'api_key_created')
      searchParams.set('secul_logTypes', 'api_key')

      const result = formatFiltersForSecurityLogsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          logTypes: ['api_key'],
        }),
      )
    })
  })

  describe('formatFiltersForQuotesQuery', () => {
    it('should format quote filters with prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('qu_quoteStatus', 'draft,approved')
      searchParams.set('qu_quoteNumber', 'QT-001,QT-002')
      searchParams.set('qu_quoteOrderType', 'one_off,subscription_creation')

      const result = formatFiltersForQuotesQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          statuses: ['draft', 'approved'],
          numbers: ['QT-001', 'QT-002'],
          orderTypes: ['one_off', 'subscription_creation'],
        }),
      )
    })

    it('should format multipleCustomers filter extracting ids', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'qu_multipleCustomers',
        `cust-1${filterDataInlineSeparator}Acme Corp,cust-2${filterDataInlineSeparator}Beta Inc`,
      )

      const result = formatFiltersForQuotesQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          customers: ['cust-1', 'cust-2'],
        }),
      )
    })

    it('should format quoteCreatedAt filter into fromDate and toDate', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('qu_quoteCreatedAt', '2026-01-01,2026-01-31')

      const result = formatFiltersForQuotesQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          fromDate: '2026-01-01',
          toDate: '2026-01-31',
        }),
      )
    })

    it('should format userIds filter as owners', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'qu_userIds',
        `user-1${filterDataInlineSeparator}alice@example.com,user-2${filterDataInlineSeparator}bob@example.com`,
      )

      const result = formatFiltersForQuotesQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          owners: ['user-1', 'user-2'],
        }),
      )
    })

    it('should ignore filters with a different prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('secul_logTypes', 'api_key')
      searchParams.set('qu_quoteStatus', 'draft')

      const result = formatFiltersForQuotesQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          statuses: ['draft'],
        }),
      )
      expect(result).not.toHaveProperty('logTypes')
    })
  })

  describe('formatFiltersForOrderFormsQuery', () => {
    it('should format order form status filter with prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('of_orderFormStatus', 'generated,signed')

      const result = formatFiltersForOrderFormsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          status: ['generated', 'signed'],
        }),
      )
    })

    it('should format order form number filter as number', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('of_orderFormNumber', 'OF-001,OF-002')

      const result = formatFiltersForOrderFormsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          number: ['OF-001', 'OF-002'],
        }),
      )
    })

    it('should format multipleCustomers filter as customerId extracting ids', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'of_multipleCustomers',
        `cust-1${filterDataInlineSeparator}Acme Corp,cust-2${filterDataInlineSeparator}Beta Inc`,
      )

      const result = formatFiltersForOrderFormsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          customerId: ['cust-1', 'cust-2'],
        }),
      )
    })

    it('should format orderFormCreatedAt into createdAtFrom and createdAtTo', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('of_orderFormCreatedAt', '2026-01-01,2026-01-31')

      const result = formatFiltersForOrderFormsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          createdAtFrom: '2026-01-01',
          createdAtTo: '2026-01-31',
        }),
      )
    })

    it('should format userIds filter as ownerId', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'of_userIds',
        `user-1${filterDataInlineSeparator}alice@example.com,user-2${filterDataInlineSeparator}bob@example.com`,
      )

      const result = formatFiltersForOrderFormsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          ownerId: ['user-1', 'user-2'],
        }),
      )
    })

    it('should ignore filters with a different prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('qu_quoteStatus', 'draft')
      searchParams.set('of_orderFormStatus', 'signed')

      const result = formatFiltersForOrderFormsQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          status: ['signed'],
        }),
      )
      expect(result).not.toHaveProperty('statuses')
    })
  })

  describe('formatFiltersForOrdersQuery', () => {
    it('should format order status filter with prefix', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('or_orderStatus', 'created,executed')

      const result = formatFiltersForOrdersQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          status: ['created', 'executed'],
        }),
      )
    })

    it('should format order number filter as number', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('or_orderNumber', 'OR-001,OR-002')

      const result = formatFiltersForOrdersQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          number: ['OR-001', 'OR-002'],
        }),
      )
    })

    it('should format execution mode filter', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('or_orderExecutionMode', 'execute_in_lago,order_only')

      const result = formatFiltersForOrdersQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          executionMode: ['execute_in_lago', 'order_only'],
        }),
      )
    })

    it('should format multipleCustomers filter as customerId extracting ids', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'or_multipleCustomers',
        `cust-1${filterDataInlineSeparator}Acme Corp,cust-2${filterDataInlineSeparator}Beta Inc`,
      )

      const result = formatFiltersForOrdersQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          customerId: ['cust-1', 'cust-2'],
        }),
      )
    })

    it('should format userIds filter as ownerId extracting ids', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'or_userIds',
        `user-1${filterDataInlineSeparator}Alice,user-2${filterDataInlineSeparator}Bob`,
      )

      const result = formatFiltersForOrdersQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          ownerId: ['user-1', 'user-2'],
        }),
      )
    })

    it('should format orderExecutedAt into executedAtFrom and executedAtTo', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('or_orderExecutedAt', '2026-01-01,2026-01-31')

      const result = formatFiltersForOrdersQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          executedAtFrom: '2026-01-01',
          executedAtTo: '2026-01-31',
        }),
      )
    })

    it('should ignore unknown params', () => {
      const searchParams = new URLSearchParams()

      searchParams.set('or_orderStatus', 'created')
      searchParams.set('randomSearchUrlParam', 'anditsvalue')

      const result = formatFiltersForOrdersQuery(searchParams)

      expect(result).toEqual({ status: ['created'] })
    })
  })

  describe('comma-safe filter labels (escapeFilterLabel / unescapeFilterLabel)', () => {
    it('escapes and unescapes a label containing commas, round-tripping exactly', () => {
      const label = 'Bernhard, Strosin & Rolfson'
      const escaped = escapeFilterLabel(label)

      expect(escaped).not.toContain(',')
      expect(unescapeFilterLabel(escaped)).toBe(label)
    })

    it('is a no-op for labels without commas', () => {
      expect(escapeFilterLabel('Acme Corp')).toBe('Acme Corp')
      expect(unescapeFilterLabel('Acme Corp')).toBe('Acme Corp')
    })

    it('keeps a comma-named customer as a single multipleCustomers chip with the real name', () => {
      const value = `cust-1${filterDataInlineSeparator}${escapeFilterLabel('Bernhard, Strosin & Rolfson')}`

      expect(formatActiveFilterValueDisplay(AvailableFiltersEnum.multipleCustomers, value)).toBe(
        'Bernhard, Strosin & Rolfson',
      )
    })

    it('extracts a single customer id from a comma-named customer in the query filters', () => {
      const searchParams = new URLSearchParams()

      searchParams.set(
        'qu_multipleCustomers',
        `cust-1${filterDataInlineSeparator}${escapeFilterLabel('Bernhard, Strosin & Rolfson')}`,
      )

      const result = formatFiltersForQuotesQuery(searchParams)

      expect(result).toEqual(
        expect.objectContaining({
          customers: ['cust-1'],
        }),
      )
    })
  })
})
