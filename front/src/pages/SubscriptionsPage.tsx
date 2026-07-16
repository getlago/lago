import { gql } from '@apollo/client'
import { Icon, tw } from 'lago-design-system'
import { useMemo } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { BillingEntityLabel } from '~/components/billingEntity/BillingEntityLabel'
import {
  AvailableFiltersEnum,
  Filters,
  formatFiltersForSubscriptionQuery,
  SubscriptionAvailableFilters,
} from '~/components/designSystem/Filters'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SearchInput } from '~/components/SearchInput'
import {
  AnnotatedSubscription,
  SubscriptionsList,
} from '~/components/subscriptions/SubscriptionsList'
import { TimezoneDate } from '~/components/TimezoneDate'
import { SUBSCRIPTION_LIST_FILTER_PREFIX } from '~/core/constants/filters'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE } from '~/core/router'
import {
  FeatureFlagEnum,
  StatusTypeEnum,
  Subscription,
  useGetSubscriptionsListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  fragment SubscriptionForSubscriptionsList on Subscription {
    id
    status
    startedAt
    nextSubscriptionAt
    nextSubscriptionType
    name
    nextName
    externalId
    subscriptionAt
    endingAt
    terminatedAt
    billingEntityId
    customer {
      id
      name
      displayName
      applicableTimezone
      billingEntity {
        id
        code
        name
      }
    }
    plan {
      id
      isOverridden
      payInAdvance
      amountCurrency
      name
      interval
    }
    nextPlan {
      id
      name
      code
      interval
    }
    nextSubscription {
      id
      name
      externalId
      status
    }
  }

  query getSubscriptionsList(
    $limit: Int
    $page: Int
    $searchTerm: String
    $status: [StatusTypeEnum!]
    $externalCustomerId: String
    $externalId: String
    $overriden: Boolean
    $planCode: String
    $billingEntityIds: [ID!]
  ) {
    subscriptions(
      limit: $limit
      page: $page
      status: $status
      searchTerm: $searchTerm
      externalCustomerId: $externalCustomerId
      externalId: $externalId
      overriden: $overriden
      planCode: $planCode
      billingEntityIds: $billingEntityIds
    ) {
      collection {
        ...SubscriptionForSubscriptionsList
      }
      metadata {
        currentPage
        totalPages
        totalCount
      }
    }
  }
`

const SubscriptionsPage = () => {
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()
  const { hasFeatureFlag } = useOrganizationInfos()

  const showBillingEntityColumn = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)

  // Drop the `billingEntityIds` option from the popper when the flag is off
  // so the legacy UX matches the pre-epic state (no entity filter visible).
  const availableFilters = useMemo(
    () =>
      showBillingEntityColumn
        ? SubscriptionAvailableFilters
        : SubscriptionAvailableFilters.filter((f) => f !== AvailableFiltersEnum.billingEntityIds),
    [showBillingEntityColumn],
  )

  const filtersForSubscriptionQuery = useMemo(() => {
    return formatFiltersForSubscriptionQuery(searchParams)
  }, [searchParams])

  const [getSubscriptions, { data, error, loading, variables, fetchMore }] =
    useGetSubscriptionsListLazyQuery({
      notifyOnNetworkStatusChange: true,
      variables: {
        limit: 20,
        ...filtersForSubscriptionQuery,
      },
    })

  const { debouncedSearch, isLoading } = useDebouncedSearch(getSubscriptions, loading)

  const subscriptions = data?.subscriptions.collection as Subscription[]
  const hasSearchParams =
    !!variables &&
    Object.keys(variables).some(
      (key) => key !== 'page' && key !== 'limit' && !!variables[key as keyof typeof variables],
    )

  const subscriptionsTotalCount = data?.subscriptions?.metadata?.totalCount

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_6250304370f0f700a8fdc28d'),
          metadata: formatCountToMetadata(subscriptionsTotalCount, translate),
          metadataLoading: isLoading,
        }}
        filtersSection={
          <Filters.Provider
            filtersNamePrefix={SUBSCRIPTION_LIST_FILTER_PREFIX}
            availableFilters={availableFilters}
          >
            <div className="flex flex-col gap-3 md:flex-row md:items-center">
              <SearchInput
                onChange={debouncedSearch}
                placeholder={translate('text_1751378926655m4bfald61u4')}
              />
              <Filters.Component />
            </div>
          </Filters.Provider>
        }
      />

      <div className="border-t border-grey-300">
        <InfiniteScroll
          onBottom={() => {
            const { currentPage = 0, totalPages = 0 } = data?.subscriptions.metadata || {}

            currentPage < totalPages &&
              !isLoading &&
              fetchMore?.({
                variables: { page: currentPage + 1 },
              })
          }}
        >
          <SubscriptionsList
            name="subscriptions-list"
            isLoading={isLoading}
            hasError={!!error}
            subscriptions={subscriptions}
            containerSize={{
              default: 16,
              md: 48,
            }}
            columns={[
              {
                key: 'name',
                title: translate('text_6419c64eace749372fc72b0f'),
                content: ({ name, isDowngrade, isScheduled }) => (
                  <>
                    <div
                      className={tw('relative flex items-center gap-3', {
                        'pl-4': isDowngrade,
                      })}
                    >
                      {isDowngrade && <Icon name="arrow-indent" />}
                      <Typography variant="bodyHl" color="grey700" noWrap>
                        {name}
                      </Typography>
                      {isDowngrade && <Status type={StatusType.default} label="downgrade" />}
                      {isScheduled && <Status type={StatusType.default} label="scheduled" />}
                    </div>
                  </>
                ),
              },
              {
                key: 'statusType.type',
                title: translate('text_62d7f6178ec94cd09370e5fb'),
                content: ({ statusType }) => <Status {...statusType} />,
              },

              {
                key: 'customer.name',
                title: translate('text_63ac86d797f728a87b2f9fb3'),
                maxSpace: true,
                minWidth: 160,
                content: ({ customer }) => (
                  <Typography variant="body" noWrap>
                    {customer?.displayName || customer?.name || '-'}
                  </Typography>
                ),
              },

              ...(showBillingEntityColumn
                ? [
                    {
                      key: 'billingEntityId' as const,
                      title: translate('text_17436114971570doqrwuwhf0'),
                      minWidth: 140,
                      content: ({ billingEntityId, customer }: AnnotatedSubscription) => (
                        <Typography variant="body" noWrap>
                          <BillingEntityLabel
                            ownId={billingEntityId}
                            customerEntity={customer?.billingEntity}
                          />
                        </Typography>
                      ),
                    },
                  ]
                : []),

              {
                key: 'isOverridden',
                title: translate('text_65281f686a80b400c8e2f6c4'),
                content: ({ isOverridden }) => (
                  <Typography>
                    {isOverridden
                      ? translate('text_65281f686a80b400c8e2f6dd')
                      : translate('text_65281f686a80b400c8e2f6d1')}
                  </Typography>
                ),
              },

              {
                key: 'frequency',
                title: translate('text_1736968618645gg26amx8djq'),
                content: ({ frequency }) => (
                  <Typography>{translate(getIntervalTranslationKey[frequency])}</Typography>
                ),
              },

              {
                key: 'startedAt',
                title: translate('text_65201c5a175a4b0238abf29e'),
                content: ({ startedAt, customer }) =>
                  !!startedAt ? (
                    <TimezoneDate
                      mainTypographyProps={{ variant: 'body', color: 'grey600', noWrap: true }}
                      date={startedAt}
                      customerTimezone={customer.applicableTimezone}
                    />
                  ) : (
                    <Typography>-</Typography>
                  ),
              },
              {
                key: 'endingAt',
                title: translate('text_65201c5a175a4b0238abf2a0'),
                content: ({ endingAt, status, terminatedAt, customer }) =>
                  endingAt || terminatedAt ? (
                    <TimezoneDate
                      mainTypographyProps={{ variant: 'body', color: 'grey600', noWrap: true }}
                      date={status === StatusTypeEnum.Terminated ? terminatedAt : endingAt}
                      customerTimezone={customer.applicableTimezone}
                    />
                  ) : (
                    <Typography>-</Typography>
                  ),
              },
            ]}
            actionColumnTooltip={() => translate('text_634687079be251fdb438338f')}
            onRowActionLink={({ id, customer }) =>
              generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
                customerId: customer.id,
                subscriptionId: id,
                tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
              })
            }
            placeholder={{
              errorState: hasSearchParams
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
              emptyState: hasSearchParams
                ? {
                    title: translate('text_1751969008731sd4e2mssx90'),
                    subtitle: translate('text_66ab48ea4ed9cd01084c60b8'),
                  }
                : {
                    title: translate('text_1751969008731m6hlinilrky'),
                    subtitle: translate('text_1751969070668mwxq0nou1x9'),
                  },
            }}
          />
        </InfiniteScroll>
      </div>
    </>
  )
}

export default SubscriptionsPage
