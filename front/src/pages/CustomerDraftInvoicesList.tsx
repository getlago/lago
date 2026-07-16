import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { generatePath, useParams } from 'react-router-dom'

import { CustomerInvoicesList } from '~/components/customers/CustomerInvoicesList'
import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { SearchInput } from '~/components/SearchInput'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import { CUSTOMER_DETAILS_TAB_ROUTE } from '~/core/router'
import {
  InvoiceForInvoiceListFragmentDoc,
  InvoiceStatusTypeEnum,
  TimezoneEnum,
  useGetCustomerDraftInvoicesLazyQuery,
  useGetCustomerInfosForDraftInvoicesListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { PageHeader } from '~/styles'

gql`
  query getCustomerDraftInvoices(
    $customerId: ID!
    $limit: Int
    $page: Int
    $status: [InvoiceStatusTypeEnum!]
    $searchTerm: String
  ) {
    customerInvoices(
      customerId: $customerId
      limit: $limit
      page: $page
      status: $status
      searchTerm: $searchTerm
    ) {
      ...InvoiceForInvoiceList
    }
  }

  query getCustomerInfosForDraftInvoicesList($customerId: ID!, $status: [InvoiceStatusTypeEnum!]) {
    customer(id: $customerId) {
      id
      name
      displayName
      applicableTimezone
    }

    customerInvoices(customerId: $customerId, status: $status) {
      metadata {
        totalCount
      }
    }
  }

  ${InvoiceForInvoiceListFragmentDoc}
`

const CustomerDraftInvoicesList = () => {
  const { customerId = '' } = useParams()
  const { goBack } = useLocationHistory()
  const { translate } = useInternationalization()
  const [getDraftInvoices, { data, error, loading, fetchMore }] =
    useGetCustomerDraftInvoicesLazyQuery({
      variables: { customerId, limit: 20, status: [InvoiceStatusTypeEnum.Draft] },
    })
  const { data: customerData, loading: customerLoading } =
    useGetCustomerInfosForDraftInvoicesListQuery({
      variables: {
        customerId,
        status: [InvoiceStatusTypeEnum.Draft],
      },
    })
  const { debouncedSearch, isLoading } = useDebouncedSearch(getDraftInvoices, loading)
  const safeTimezone = customerData?.customer?.applicableTimezone || TimezoneEnum.TzUtc
  const customerName = customerData?.customer?.displayName

  return (
    <>
      <PageHeader.Wrapper withSide>
        <PageHeader.Group>
          <Button
            icon="arrow-left"
            variant="quaternary"
            onClick={() =>
              goBack(
                generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
                  customerId,
                  tab: CustomerDetailsTabsOptions.invoices,
                }),
              )
            }
          />
          <Typography variant="bodyHl" color="textSecondary">
            {translate('text_638f74bb4d41e3f1d0201647')}
          </Typography>
        </PageHeader.Group>
      </PageHeader.Wrapper>
      <div className="px-4 py-8 md:px-12">
        {customerLoading ? (
          <div className="mb-8 flex items-center">
            <Skeleton className="mr-4" variant="userAvatar" size="large" />
            <div>
              <Skeleton variant="text" className="mb-5 w-50" />
              <Skeleton variant="text" className="w-32" />
            </div>
          </div>
        ) : (
          <div className="mb-8 flex items-center">
            <Avatar className="mr-4" size="large" variant="connector">
              <Icon name="document" />
            </Avatar>
            <div>
              <Typography className="mb-1" color="textSecondary" variant="headline">
                {translate('text_638f74bb4d41e3f1d0201649', {
                  customerName,
                })}
              </Typography>
              <Typography>
                {translate('text_638f74bb4d41e3f1d020164b', {
                  count: customerData?.customerInvoices?.metadata?.totalCount,
                })}
              </Typography>
            </div>
          </div>
        )}

        <div className="flex h-18 items-center justify-between">
          <Typography variant="bodyHl" color="textSecondary">
            {translate('text_63c6cac5c1fc58028d0235dd')}
          </Typography>
          <SearchInput
            onChange={debouncedSearch}
            placeholder={translate('text_63c6cac5c1fc58028d0235d9')}
          />
        </div>

        <CustomerInvoicesList
          isLoading={isLoading}
          hasError={!!error}
          customerTimezone={safeTimezone}
          customerId={customerId}
          invoiceData={data?.customerInvoices}
          fetchMore={fetchMore}
        />
      </div>
    </>
  )
}

export default CustomerDraftInvoicesList
