import { gql } from '@apollo/client'
import { debounce } from 'lodash'
import { useEffect, useMemo, useState } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { CustomerOverview } from '~/components/customers/overview/CustomerOverview'
import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { Filters } from '~/components/designSystem/Filters'
import { formatFiltersForCustomerInvoicesQuery } from '~/components/designSystem/Filters/utils'
import { PageSectionTitle } from '~/components/layouts/Section'
import { SearchInput } from '~/components/SearchInput'
import {
  CUSTOMER_INVOICES_DRAFT_FILTER_PREFIX,
  CUSTOMER_INVOICES_FINALIZED_FILTER_PREFIX,
} from '~/core/constants/filters'
import { CUSTOMER_DRAFT_INVOICES_LIST_ROUTE } from '~/core/router'
import {
  CurrencyEnum,
  InvoiceForInvoiceListFragmentDoc,
  InvoiceStatusTypeEnum,
  TimezoneEnum,
  useGetCustomerInvoicesQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerFilterDefaults } from '~/hooks/useCustomerFilterDefaults'
import { DEBOUNCE_SEARCH_MS } from '~/hooks/useDebouncedSearch'

import { CustomerInvoicesList } from './CustomerInvoicesList'

const DRAFT_INVOICES_ITEMS_COUNT = 4

gql`
  query getCustomerInvoices(
    $customerId: ID!
    $limit: Int
    $page: Int
    $status: [InvoiceStatusTypeEnum!]
    $searchTerm: String
    $currency: CurrencyEnum
    $billingEntityIds: [ID!]
  ) {
    customerInvoices(
      customerId: $customerId
      limit: $limit
      page: $page
      status: $status
      searchTerm: $searchTerm
      currency: $currency
      billingEntityIds: $billingEntityIds
    ) {
      ...InvoiceForInvoiceList
    }
  }

  ${InvoiceForInvoiceListFragmentDoc}
`

export const INVOICES_TAB_CONTAINER = 'invoices-tab-container'
export const INVOICES_TAB_SEE_MORE = 'invoices-tab-see-more'
export const INVOICES_TAB_DRAFT_SECTION = 'invoices-tab-draft-section'
export const INVOICES_TAB_FINALIZED_SECTION = 'invoices-tab-finalized-section'

interface CustomerInvoicesTabProps {
  customerId: string
  customerTimezone?: TimezoneEnum
  customerBillingEntity?: { id: string; code: string; name?: string | null } | null
  externalId?: string
  userCurrency?: CurrencyEnum
  isPartner?: boolean
}

export const CustomerInvoicesTab = ({
  customerId,
  customerTimezone,
  customerBillingEntity,
  isPartner,
  externalId,
  userCurrency,
}: CustomerInvoicesTabProps) => {
  const { translate } = useInternationalization()
  const baseFiltersProps = useCustomerFilterDefaults({
    filtersNamePrefix: CUSTOMER_INVOICES_DRAFT_FILTER_PREFIX,
    include: ['currency', 'entity'],
  })

  const draftFiltersProps = baseFiltersProps
    ? { ...baseFiltersProps, filtersNamePrefix: CUSTOMER_INVOICES_DRAFT_FILTER_PREFIX }
    : null

  const finalizedFiltersProps = baseFiltersProps
    ? { ...baseFiltersProps, filtersNamePrefix: CUSTOMER_INVOICES_FINALIZED_FILTER_PREFIX }
    : null
  const [searchParams] = useSearchParams()

  const draftFilters = formatFiltersForCustomerInvoicesQuery(
    searchParams,
    CUSTOMER_INVOICES_DRAFT_FILTER_PREFIX,
  )
  const finalizedFilters = formatFiltersForCustomerInvoicesQuery(
    searchParams,
    CUSTOMER_INVOICES_FINALIZED_FILTER_PREFIX,
  )

  const {
    data: dataDraft,
    error: errorDraft,
    loading: loadingDraft,
  } = useGetCustomerInvoicesQuery({
    variables: {
      customerId,
      limit: DRAFT_INVOICES_ITEMS_COUNT,
      status: [InvoiceStatusTypeEnum.Draft],
      currency: draftFilters.currency,
      billingEntityIds: draftFilters.billingEntityId ? [draftFilters.billingEntityId] : undefined,
    },
  })

  const [searchTerm, setSearchTerm] = useState<string | undefined>(undefined)

  const {
    data: dataFinalized,
    error: errorFinalized,
    fetchMore: fetchMoreFinalized,
    loading: loadingFinalized,
  } = useGetCustomerInvoicesQuery({
    variables: {
      customerId,
      limit: 20,
      status: [
        InvoiceStatusTypeEnum.Finalized,
        InvoiceStatusTypeEnum.Voided,
        InvoiceStatusTypeEnum.Failed,
        InvoiceStatusTypeEnum.Pending,
      ],
      searchTerm,
      currency: finalizedFilters.currency,
      billingEntityIds: finalizedFilters.billingEntityId
        ? [finalizedFilters.billingEntityId]
        : undefined,
    },
    notifyOnNetworkStatusChange: true,
  })

  const debouncedSetSearchTerm = useMemo(
    () => debounce((value: string) => setSearchTerm(value || undefined), DEBOUNCE_SEARCH_MS),
    [],
  )

  useEffect(() => {
    return () => {
      debouncedSetSearchTerm.cancel()
    }
  }, [debouncedSetSearchTerm])

  const invoicesDraftCount = dataDraft?.customerInvoices.metadata.totalCount || 0

  const isDraftFiltering = !!draftFilters.currency || !!draftFilters.billingEntityId
  const isFiltering =
    !!searchTerm || !!finalizedFilters.currency || !!finalizedFilters.billingEntityId

  const showSeeMore = invoicesDraftCount > DRAFT_INVOICES_ITEMS_COUNT

  // Hide the Draft section entirely when the customer has no drafts AND the
  // user is not currently filtering. If a filter returns zero rows we keep
  // the section visible so the operator can clear the filter without
  // navigating away.
  const showDraftSection = isDraftFiltering || loadingDraft || invoicesDraftCount > 0

  return (
    <div className="flex flex-col gap-12" data-test={INVOICES_TAB_CONTAINER}>
      {!isPartner && (
        <CustomerOverview
          externalCustomerId={externalId}
          userCurrency={userCurrency}
          customerBillingEntity={customerBillingEntity}
        />
      )}

      {showDraftSection && (
        <div data-test={INVOICES_TAB_DRAFT_SECTION}>
          <PageSectionTitle
            title={translate('text_638f4d756d899445f18a49ee')}
            subtitle={translate('text_1737655039923xyw73dt51ee')}
          />

          {draftFiltersProps && (
            <Filters.Provider {...draftFiltersProps}>
              <div className="mb-4 flex items-center gap-2">
                <Filters.Component />
              </div>
            </Filters.Provider>
          )}

          <CustomerInvoicesList
            isSearching={isDraftFiltering}
            isLoading={loadingDraft}
            hasError={!!errorDraft}
            customerTimezone={customerTimezone}
            customerId={customerId}
            invoiceData={dataDraft?.customerInvoices}
          />

          {showSeeMore && (
            <div
              className="flex flex-col items-center justify-center py-2 shadow-b"
              data-test={INVOICES_TAB_SEE_MORE}
            >
              <ButtonLink
                type="button"
                to={generatePath(CUSTOMER_DRAFT_INVOICES_LIST_ROUTE, { customerId })}
                buttonProps={{
                  variant: 'quaternary',
                }}
              >
                {translate('text_638f4d756d899445f18a4a0e')}
              </ButtonLink>
            </div>
          )}
        </div>
      )}

      <div data-test={INVOICES_TAB_FINALIZED_SECTION}>
        <PageSectionTitle
          title={translate('text_6250304370f0f700a8fdc291')}
          subtitle={translate('text_1737654864705k68zqvg5u9d')}
        />

        <div className="mb-4 flex items-center gap-3">
          <SearchInput
            onChange={debouncedSetSearchTerm}
            placeholder={translate('text_63c6861d9991cdd5a92c1419')}
          />
          {finalizedFiltersProps && (
            <Filters.Provider {...finalizedFiltersProps}>
              <Filters.Component />
            </Filters.Provider>
          )}
        </div>

        <CustomerInvoicesList
          isSearching={isFiltering}
          isLoading={loadingFinalized}
          hasError={!!errorFinalized}
          customerTimezone={customerTimezone}
          customerId={customerId}
          invoiceData={dataFinalized?.customerInvoices}
          fetchMore={fetchMoreFinalized}
        />
      </div>
    </div>
  )
}
