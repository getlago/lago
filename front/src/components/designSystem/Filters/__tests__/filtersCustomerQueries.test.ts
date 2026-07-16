import {
  CUSTOMER_CREDIT_NOTES_FILTER_PREFIX,
  CUSTOMER_INVOICES_DRAFT_FILTER_PREFIX,
  CUSTOMER_INVOICES_FINALIZED_FILTER_PREFIX,
  CUSTOMER_PAYMENTS_FILTER_PREFIX,
} from '~/core/constants/filters'

import { AvailableFiltersEnum, filterDataInlineSeparator } from '../types'
import {
  FILTER_VALUE_MAP,
  formatFiltersForCustomerCreditNotesQuery,
  formatFiltersForCustomerInvoicesQuery,
  formatFiltersForCustomerPaymentsQuery,
} from '../utils'

describe('Customer query filter formatters', () => {
  describe('GIVEN FILTER_VALUE_MAP entries for customer filters', () => {
    describe('WHEN parsing a currency value', () => {
      it('THEN should return the raw currency string', () => {
        const result = FILTER_VALUE_MAP[AvailableFiltersEnum.currency]('USD')

        expect(result).toBe('USD')
      })
    })

    describe('WHEN parsing a billingEntityId with inline separator', () => {
      it('THEN should extract only the ID portion before the separator', () => {
        const raw = `entity-uuid-123${filterDataInlineSeparator}My Billing Entity`
        const result = FILTER_VALUE_MAP[AvailableFiltersEnum.billingEntityId](raw)

        expect(result).toBe('entity-uuid-123')
      })

      it('THEN should return the value as-is when no separator is present', () => {
        const result = FILTER_VALUE_MAP[AvailableFiltersEnum.billingEntityId]('entity-uuid-456')

        expect(result).toBe('entity-uuid-456')
      })
    })
  })

  describe('GIVEN formatFiltersForCustomerCreditNotesQuery', () => {
    describe('WHEN search params are empty', () => {
      it('THEN should return an empty object', () => {
        const searchParams = new URLSearchParams()
        const result = formatFiltersForCustomerCreditNotesQuery(searchParams)

        expect(result).toEqual({})
      })
    })

    describe('WHEN search params contain currency with the correct prefix', () => {
      it('THEN should return the currency value', () => {
        const searchParams = new URLSearchParams()

        searchParams.set(`${CUSTOMER_CREDIT_NOTES_FILTER_PREFIX}_currency`, 'EUR')

        const result = formatFiltersForCustomerCreditNotesQuery(searchParams)

        expect(result).toEqual({ currency: 'EUR' })
      })
    })

    describe('WHEN search params contain billingEntityId with inline separator', () => {
      it('THEN should extract the ID from the value', () => {
        const searchParams = new URLSearchParams()

        searchParams.set(
          `${CUSTOMER_CREDIT_NOTES_FILTER_PREFIX}_billingEntityId`,
          `be-id-001${filterDataInlineSeparator}Billing Entity Label`,
        )

        const result = formatFiltersForCustomerCreditNotesQuery(searchParams)

        expect(result).toEqual({ billingEntityId: 'be-id-001' })
      })
    })

    describe('WHEN search params contain both currency and billingEntityId', () => {
      it('THEN should return both parsed values', () => {
        const searchParams = new URLSearchParams()

        searchParams.set(`${CUSTOMER_CREDIT_NOTES_FILTER_PREFIX}_currency`, 'USD')
        searchParams.set(
          `${CUSTOMER_CREDIT_NOTES_FILTER_PREFIX}_billingEntityId`,
          `be-id-002${filterDataInlineSeparator}Label`,
        )

        const result = formatFiltersForCustomerCreditNotesQuery(searchParams)

        expect(result).toEqual({
          currency: 'USD',
          billingEntityId: 'be-id-002',
        })
      })
    })

    describe('WHEN search params contain unrelated keys', () => {
      it('THEN should ignore them and return an empty object', () => {
        const searchParams = new URLSearchParams()

        searchParams.set('unrelated_key', 'someValue')
        searchParams.set('status', 'finalized')

        const result = formatFiltersForCustomerCreditNotesQuery(searchParams)

        expect(result).toEqual({})
      })
    })
  })

  describe('GIVEN formatFiltersForCustomerInvoicesQuery', () => {
    const prefixes = [
      { name: 'draft', prefix: CUSTOMER_INVOICES_DRAFT_FILTER_PREFIX },
      { name: 'finalized', prefix: CUSTOMER_INVOICES_FINALIZED_FILTER_PREFIX },
    ]

    describe('WHEN search params are empty', () => {
      it.each(prefixes)('THEN should return an empty object for $name prefix', ({ prefix }) => {
        const searchParams = new URLSearchParams()
        const result = formatFiltersForCustomerInvoicesQuery(searchParams, prefix)

        expect(result).toEqual({})
      })
    })

    describe('WHEN search params contain currency with the correct prefix', () => {
      it.each(prefixes)('THEN should return the currency value for $name prefix', ({ prefix }) => {
        const searchParams = new URLSearchParams()

        searchParams.set(`${prefix}_currency`, 'GBP')

        const result = formatFiltersForCustomerInvoicesQuery(searchParams, prefix)

        expect(result).toEqual({ currency: 'GBP' })
      })
    })

    describe('WHEN search params contain billingEntityId with inline separator', () => {
      it.each(prefixes)('THEN should extract the ID for $name prefix', ({ prefix }) => {
        const searchParams = new URLSearchParams()

        searchParams.set(
          `${prefix}_billingEntityId`,
          `inv-be-id${filterDataInlineSeparator}Entity Name`,
        )

        const result = formatFiltersForCustomerInvoicesQuery(searchParams, prefix)

        expect(result).toEqual({ billingEntityId: 'inv-be-id' })
      })
    })

    describe('WHEN search params contain both currency and billingEntityId', () => {
      it.each(prefixes)('THEN should return both values for $name prefix', ({ prefix }) => {
        const searchParams = new URLSearchParams()

        searchParams.set(`${prefix}_currency`, 'JPY')
        searchParams.set(
          `${prefix}_billingEntityId`,
          `inv-be-id-2${filterDataInlineSeparator}Label`,
        )

        const result = formatFiltersForCustomerInvoicesQuery(searchParams, prefix)

        expect(result).toEqual({
          currency: 'JPY',
          billingEntityId: 'inv-be-id-2',
        })
      })
    })

    describe('WHEN search params contain keys with wrong prefix', () => {
      it('THEN should ignore them', () => {
        const searchParams = new URLSearchParams()

        searchParams.set(`${CUSTOMER_CREDIT_NOTES_FILTER_PREFIX}_currency`, 'EUR')

        const result = formatFiltersForCustomerInvoicesQuery(
          searchParams,
          CUSTOMER_INVOICES_DRAFT_FILTER_PREFIX,
        )

        expect(result).toEqual({})
      })
    })
  })

  describe('GIVEN formatFiltersForCustomerPaymentsQuery', () => {
    describe('WHEN search params are empty', () => {
      it('THEN should return an empty object', () => {
        const searchParams = new URLSearchParams()
        const result = formatFiltersForCustomerPaymentsQuery(searchParams)

        expect(result).toEqual({})
      })
    })

    describe('WHEN search params contain currency with the correct prefix', () => {
      it('THEN should return the currency value', () => {
        const searchParams = new URLSearchParams()

        searchParams.set(`${CUSTOMER_PAYMENTS_FILTER_PREFIX}_currency`, 'CHF')

        const result = formatFiltersForCustomerPaymentsQuery(searchParams)

        expect(result).toEqual({ currency: 'CHF' })
      })
    })

    describe('WHEN search params contain unrelated keys', () => {
      it('THEN should ignore them and return an empty object', () => {
        const searchParams = new URLSearchParams()

        searchParams.set('randomKey', 'randomValue')
        searchParams.set(`${CUSTOMER_PAYMENTS_FILTER_PREFIX}_billingEntityId`, 'some-id')

        const result = formatFiltersForCustomerPaymentsQuery(searchParams)

        // billingEntityId is NOT in CustomerPaymentsAvailableFilters, so it should be excluded
        expect(result).toEqual({})
      })
    })

    describe('WHEN search params contain only non-matching prefixed keys', () => {
      it('THEN should return an empty object', () => {
        const searchParams = new URLSearchParams()

        searchParams.set(`${CUSTOMER_CREDIT_NOTES_FILTER_PREFIX}_currency`, 'USD')

        const result = formatFiltersForCustomerPaymentsQuery(searchParams)

        expect(result).toEqual({})
      })
    })
  })
})
