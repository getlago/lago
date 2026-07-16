import { gql } from '@apollo/client'

import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { PaymentsList } from '~/components/invoices/PaymentsList'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SearchInput } from '~/components/SearchInput'
import { CREATE_PAYMENT_ROUTE, useNavigate } from '~/core/router'
import { PaymentForPaymentsListFragmentDoc, useGetPaymentsListLazyQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'

gql`
  query getPaymentsList(
    $invoiceId: ID
    $externalCustomerId: ID
    $limit: Int
    $page: Int
    $searchTerm: String
    $currency: CurrencyEnum
  ) {
    payments(
      invoiceId: $invoiceId
      externalCustomerId: $externalCustomerId
      limit: $limit
      page: $page
      searchTerm: $searchTerm
      currency: $currency
    ) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        ...PaymentForPaymentsList
      }
    }
  }

  ${PaymentForPaymentsListFragmentDoc}
`

const PaymentsPage = () => {
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const navigate = useNavigate()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()

  const [getPayments, { data, loading, error, fetchMore, variables }] = useGetPaymentsListLazyQuery(
    {
      notifyOnNetworkStatusChange: true,
      fetchPolicy: 'network-only',
      nextFetchPolicy: 'network-only',
      variables: {
        limit: 20,
      },
    },
  )

  const { debouncedSearch: paymentsDebounceSearch, isLoading: paymentsIsLoading } =
    useDebouncedSearch(getPayments, loading)

  const paymentsTotalCount = data?.payments?.metadata?.totalCount

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_6672ebb8b1b50be550eccbed'),
          metadata: formatCountToMetadata(paymentsTotalCount, translate),
          metadataLoading: paymentsIsLoading,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_1737471851634wpeojigr27w'),
              variant: 'primary',
              endIcon: isPremium ? undefined : 'sparkles',
              onClick: () => {
                if (isPremium) {
                  navigate(CREATE_PAYMENT_ROUTE)
                } else {
                  openPremiumWarningDialog()
                }
              },
            },
          ],
        }}
        filtersSection={
          <SearchInput
            onChange={paymentsDebounceSearch}
            placeholder={translate('text_17370296250897aidak5kjcg')}
          />
        }
      />

      <PaymentsList
        error={error}
        fetchMore={fetchMore}
        payments={data?.payments?.collection}
        isLoading={paymentsIsLoading}
        metadata={data?.payments?.metadata}
        variables={variables}
      />
    </>
  )
}

export default PaymentsPage
