import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { useDeleteCustomerDialog } from '~/components/customers/DeleteCustomerDialog'
import { computeCustomerInitials } from '~/components/customers/utils'
import { Avatar } from '~/components/designSystem/Avatar'
import { formatFiltersForCustomerQuery } from '~/components/designSystem/Filters'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { PaymentProviderChip } from '~/components/PaymentProviderChip'
import {
  CREATE_CUSTOMER_ROUTE,
  CUSTOMER_DETAILS_ROUTE,
  UPDATE_CUSTOMER_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  AddCustomerDrawerFragmentDoc,
  CustomerAccountTypeEnum,
  CustomerItemFragmentDoc,
  useCustomersLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomersListHeaderActions } from '~/hooks/customer/useCustomersListHeaderActions'
import { useCustomersListHeaderFilters } from '~/hooks/customer/useCustomersListHeaderFilters'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  fragment CustomerItem on Customer {
    id
    name
    displayName
    firstname
    lastname
    externalId
    createdAt
    activeSubscriptionsCount
    ...AddCustomerDrawer
  }

  query customers(
    $page: Int
    $limit: Int
    $searchTerm: String
    $accountType: [CustomerAccountTypeEnum!]
    $billingEntityIds: [ID!]
    $activeSubscriptionsCountFrom: Int
    $activeSubscriptionsCountTo: Int
    $countries: [CountryCode!]
    $zipcodes: [String!]
    $states: [String!]
    $currencies: [CurrencyEnum!]
    $customerType: CustomerTypeEnum
    $externalId: String
    $hasTaxIdentificationNumber: Boolean
    $hasCustomerType: Boolean
    $metadata: [CustomerMetadataFilter!]
  ) {
    customers(
      page: $page
      limit: $limit
      searchTerm: $searchTerm
      accountType: $accountType
      billingEntityIds: $billingEntityIds
      activeSubscriptionsCountFrom: $activeSubscriptionsCountFrom
      activeSubscriptionsCountTo: $activeSubscriptionsCountTo
      countries: $countries
      zipcodes: $zipcodes
      states: $states
      currencies: $currencies
      customerType: $customerType
      externalId: $externalId
      hasTaxIdentificationNumber: $hasTaxIdentificationNumber
      hasCustomerType: $hasCustomerType
      metadata: $metadata
    ) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        ...CustomerItem
      }
    }
  }

  ${CustomerItemFragmentDoc}
  ${AddCustomerDrawerFragmentDoc}
`

const CustomersList = () => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()

  const filtersForCustomerQuery = useMemo(() => {
    return formatFiltersForCustomerQuery(searchParams)
  }, [searchParams])

  const [getCustomers, { data, error, loading, fetchMore, variables }] = useCustomersLazyQuery({
    variables: {
      limit: 20,
      ...filtersForCustomerQuery,
      accountType: [
        (filtersForCustomerQuery.accountType as CustomerAccountTypeEnum) ??
          CustomerAccountTypeEnum.Customer,
      ],
    },
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  })

  const { openDeleteCustomerDialog } = useDeleteCustomerDialog()

  const { debouncedSearch, isLoading } = useDebouncedSearch(getCustomers, loading)

  const headerActions = useCustomersListHeaderActions()
  const headerFilters = useCustomersListHeaderFilters({ debouncedSearch })

  const customersTotalCount = data?.customers?.metadata?.totalCount

  const hasSearchOrFilters = useMemo(() => {
    const hasPopperFilters = Object.keys(filtersForCustomerQuery).some(
      (key) => key !== 'accountType',
    )

    return !!variables?.searchTerm || hasPopperFilters
  }, [filtersForCustomerQuery, variables?.searchTerm])

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_624efab67eb2570101d117a5'),
          metadata: formatCountToMetadata(customersTotalCount, translate),
          metadataLoading: isLoading,
        }}
        actions={{ items: headerActions }}
        filtersSection={headerFilters}
      />

      <div className="border-t border-grey-300">
        <InfiniteScroll
          onBottom={() => {
            const { currentPage = 0, totalPages = 0 } = data?.customers?.metadata || {}

            currentPage < totalPages &&
              !isLoading &&
              fetchMore({
                variables: { page: currentPage + 1 },
              })
          }}
        >
          <Table
            name="customers-list"
            data={data?.customers?.collection || []}
            isLoading={loading}
            hasError={!!error}
            containerSize={{
              default: 16,
              md: 48,
            }}
            onRowActionLink={({ id }) => generatePath(CUSTOMER_DETAILS_ROUTE, { customerId: id })}
            columns={[
              {
                key: 'displayName',
                title: translate('text_624efab67eb2570101d117cc'),
                minWidth: 200,
                maxWidth: 600,
                content: (customer) => {
                  const customerInitials = computeCustomerInitials(customer)

                  return (
                    <div className="flex items-center gap-3">
                      <Avatar
                        variant="user"
                        size="medium"
                        identifier={customer.displayName as string}
                        initials={customerInitials}
                      />
                      <Typography variant="bodyHl" color="textSecondary" noWrap>
                        {customer.displayName || '-'}
                      </Typography>
                    </div>
                  )
                },
              },
              {
                key: 'email',
                title: translate('text_6419c64eace749372fc72b27'),
                content: ({ email }) =>
                  email ? (
                    <TypographyWithCopy compact noWrap variant="body">
                      {email}
                    </TypographyWithCopy>
                  ) : (
                    '-'
                  ),
                maxSpace: true,
                minWidth: 200,
              },
              {
                key: 'billingEntity.name',
                title: translate('text_17436114971570doqrwuwhf0'),
                content: ({ billingEntity }) => billingEntity.name || billingEntity.code || '-',
              },
              {
                key: 'activeSubscriptionsCount',
                title: translate('text_1734452833961chacuky8218'),
                content: ({ activeSubscriptionsCount }) => activeSubscriptionsCount,
                textAlign: 'right',
              },
              {
                key: 'paymentProvider',
                title: translate('text_6419c64eace749372fc72b40'),
                content: ({ paymentProvider }) =>
                  paymentProvider ? (
                    <PaymentProviderChip paymentProvider={paymentProvider} />
                  ) : null,
              },
              {
                key: 'createdAt',
                title: translate('text_624efab67eb2570101d117e3'),
                content: ({ createdAt }) => intlFormatDateTimeOrgaTZ(createdAt).date,
              },
            ]}
            actionColumnTooltip={() => translate('text_626162c62f790600f850b7b6')}
            actionColumn={(customer) => {
              if (!hasPermissions(['customersUpdate']) && !hasPermissions(['customersDelete'])) {
                return undefined
              }

              return [
                hasPermissions(['customersUpdate'])
                  ? {
                      startIcon: 'pen',
                      title: translate('text_6261640f28a49700f1290df3'),
                      onAction: () =>
                        navigate(
                          generatePath(UPDATE_CUSTOMER_ROUTE, {
                            customerId: customer.id,
                          }),
                        ),
                    }
                  : null,
                hasPermissions(['customersDelete'])
                  ? {
                      startIcon: 'trash',
                      title: translate('text_6261640f28a49700f1290df5'),
                      onAction: () => {
                        openDeleteCustomerDialog({ customer })
                      },
                    }
                  : null,
              ]
            }}
            placeholder={{
              errorState: hasSearchOrFilters
                ? {
                    title: translate('text_623b53fea66c76017eaebb6e'),
                    subtitle: translate('text_63bab307a61c62af497e0599'),
                  }
                : {
                    title: translate('text_63ac86d797f728a87b2f9fea'),
                    subtitle: translate('text_63ac86d797f728a87b2f9ff2'),
                    buttonTitle: translate('text_63ac86d797f728a87b2f9ffa'),
                    buttonAction: () => location.reload(),
                    buttonVariant: 'primary',
                  },
              emptyState: {
                ...(hasSearchOrFilters && {
                  title: translate('text_63befc65efcd9374da45b813'),
                  subtitle: translate('text_66ab48ea4ed9cd01084c60b8'),
                }),
                ...(!hasSearchOrFilters &&
                  !hasPermissions(['customersCreate']) && {
                    title: translate('text_664deb061ac6860101f40d1d'),
                    subtitle: translate('text_1734452833961ix7z38723pg'),
                  }),
                ...(!hasSearchOrFilters &&
                  hasPermissions(['customersCreate']) && {
                    title: translate('text_17344528339611v83lf47q5m'),
                    subtitle: translate('text_1734452833961ix7z38723pg'),
                    buttonTitle: translate('text_1734452833961s338w0x3b4s'),
                    buttonAction: () => navigate(CREATE_CUSTOMER_ROUTE),
                    buttonVariant: 'primary',
                  }),
                ...(!hasSearchOrFilters &&
                  hasPermissions(['customersCreate']) &&
                  filtersForCustomerQuery.accountType === CustomerAccountTypeEnum.Partner && {
                    title: translate('text_1739870196554qh3i1j3twdo'),
                    subtitle: translate('text_1739870196554eghdpihly57'),
                    buttonTitle: translate('text_1734452833961s338w0x3b4s'),
                    buttonAction: () => navigate(CREATE_CUSTOMER_ROUTE),
                    buttonVariant: 'primary',
                  }),
              },
            }}
          />
        </InfiniteScroll>
      </div>
    </>
  )
}

export default CustomersList
