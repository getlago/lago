import { gql } from '@apollo/client'
import { debounce } from 'lodash'
import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import CreditNotesTable from '~/components/creditNote/CreditNotesTable'
import { CustomerCreditNotesBreakdown } from '~/components/customers/CustomerCreditNotesBreakdown'
import { CustomerCreditNotesLegacyCard } from '~/components/customers/CustomerCreditNotesLegacyCard'
import { Filters } from '~/components/designSystem/Filters'
import { formatFiltersForCustomerCreditNotesQuery } from '~/components/designSystem/Filters/utils'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { PageSectionTitle } from '~/components/layouts/Section'
import { SearchInput } from '~/components/SearchInput'
import { CUSTOMER_CREDIT_NOTES_FILTER_PREFIX } from '~/core/constants/filters'
import {
  CreditNotesForTableFragmentDoc,
  CurrencyEnum,
  CustomerCreditNotesBalance,
  FeatureFlagEnum,
  TimezoneEnum,
  useGetCustomerCreditNotesLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerFilterDefaults } from '~/hooks/useCustomerFilterDefaults'
import { DEBOUNCE_SEARCH_MS } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  query getCustomerCreditNotes(
    $customerId: ID!
    $page: Int
    $limit: Int
    $searchTerm: String
    $currency: CurrencyEnum
    $billingEntityIds: [ID!]
  ) {
    creditNotes(
      customerId: $customerId
      page: $page
      limit: $limit
      searchTerm: $searchTerm
      currency: $currency
      billingEntityIds: $billingEntityIds
    ) {
      ...CreditNotesForTable
    }
  }

  ${CreditNotesForTableFragmentDoc}
`

type CreditNotesBalanceRow = Pick<
  CustomerCreditNotesBalance,
  'currency' | 'billingEntityId' | 'amountCents' | 'creditsAvailableCount'
>

const CREDIT_NOTES_LIST_CONTAINER = 'credit-notes-list-container'

interface CustomerCreditNotesListProps {
  customerId: string
  customerBillingEntity?: { id: string; code: string; name?: string | null } | null
  creditNotesBalances?: CreditNotesBalanceRow[]
  userCurrency?: CurrencyEnum
  customerTimezone?: TimezoneEnum
}

export const CustomerCreditNotesList = ({
  customerId,
  customerBillingEntity,
  creditNotesBalances,
  userCurrency,
  customerTimezone,
}: CustomerCreditNotesListProps) => {
  const { translate } = useInternationalization()
  const { hasFeatureFlag } = useOrganizationInfos()
  const hasMultiCurrency = hasFeatureFlag(FeatureFlagEnum.MultiCurrency)
  const hasMultiEntityBilling = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)
  const showBreakdown = hasMultiCurrency || hasMultiEntityBilling

  const filtersProps = useCustomerFilterDefaults({
    customerCurrency: userCurrency,
    filtersNamePrefix: CUSTOMER_CREDIT_NOTES_FILTER_PREFIX,
    include: ['currency', 'entity'],
  })
  const [searchParams] = useSearchParams()

  const { currency, billingEntityId } = formatFiltersForCustomerCreditNotesQuery(searchParams)

  const [getCreditNotes, { data, loading, error, fetchMore, variables }] =
    useGetCustomerCreditNotesLazyQuery({
      variables: { customerId, limit: 20 },
    })

  const [searchTerm, setSearchTerm] = useState<string | undefined>(undefined)

  useEffect(() => {
    getCreditNotes({
      variables: {
        customerId,
        limit: 20,
        searchTerm,
        currency,
        billingEntityIds: billingEntityId ? [billingEntityId] : undefined,
      },
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [customerId, searchTerm, currency, billingEntityId])

  const debouncedSetSearchTerm = useMemo(
    () => debounce((value: string) => setSearchTerm(value || undefined), DEBOUNCE_SEARCH_MS),
    [],
  )

  useEffect(() => {
    return () => {
      debouncedSetSearchTerm.cancel()
    }
  }, [debouncedSetSearchTerm])

  const creditNotes = data?.creditNotes?.collection

  return (
    <div data-test={CREDIT_NOTES_LIST_CONTAINER}>
      <PageSectionTitle
        title={translate('text_1779269934897no61nlpm9qz')}
        subtitle={translate('text_1737895765672pwk47419syk')}
      />

      <div className="mb-12">
        {showBreakdown ? (
          <CustomerCreditNotesBreakdown
            creditNotesBalances={creditNotesBalances}
            customerBillingEntity={customerBillingEntity}
          />
        ) : (
          <CustomerCreditNotesLegacyCard
            creditNotesBalances={creditNotesBalances}
            userCurrency={userCurrency}
          />
        )}
      </div>

      <PageSectionTitle
        title={translate('text_63725b30957fd5b26b308dd3')}
        subtitle={translate('text_1779712287978i7laolg3ga4')}
      />

      <div className="mb-4 flex items-center gap-3">
        <SearchInput
          onChange={debouncedSetSearchTerm}
          placeholder={translate('text_63c6edd80c57d0dfaae3898e')}
        />
        {filtersProps && (
          <Filters.Provider {...filtersProps}>
            <Filters.Component />
          </Filters.Provider>
        )}
      </div>

      {!!error && !loading ? (
        <GenericPlaceholder
          title={translate('text_636d023ce11a9d038819b579')}
          subtitle={translate('text_636d023ce11a9d038819b57b')}
          buttonTitle={translate('text_636d023ce11a9d038819b57d')}
          buttonVariant="primary"
          buttonAction={() => location.reload()}
          image={<ErrorImage width="136" height="104" />}
        />
      ) : (
        <CreditNotesTable
          creditNotes={creditNotes}
          fetchMore={fetchMore}
          isLoading={loading}
          metadata={data?.creditNotes?.metadata}
          customerTimezone={customerTimezone}
          error={error}
          variables={variables}
        />
      )}
    </div>
  )
}
