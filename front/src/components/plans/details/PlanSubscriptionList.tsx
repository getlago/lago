import { gql } from '@apollo/client'
import { generatePath } from 'react-router-dom'

import { computeCustomerInitials } from '~/components/customers/utils'
import { Avatar } from '~/components/designSystem/Avatar'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { PLAN_SUBSCRIPTION_DETAILS_ROUTE } from '~/core/router/ObjectsRoutes'
import { intlFormatDateTime } from '~/core/timezone'
import { StatusTypeEnum, useGetSubscribtionsForPlanDetailsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  query getSubscribtionsForPlanDetails(
    $page: Int
    $limit: Int
    $planCode: String
    $status: [StatusTypeEnum!]
  ) {
    subscriptions(page: $page, limit: $limit, planCode: $planCode, status: $status) {
      collection {
        id
        endingAt
        subscriptionAt
        plan {
          id
          parent {
            id
          }
        }
        customer {
          id
          name
          displayName
          externalId
        }
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`

const PlanSubscriptionList = ({ planCode }: { planCode?: string }) => {
  const { translate } = useInternationalization()
  const {
    data: subscriptionResult,
    loading: areSubscriptionsLoading,
    error: subscriptionsError,
    fetchMore: fetchMoreSubscriptions,
  } = useGetSubscribtionsForPlanDetailsQuery({
    variables: { planCode: planCode as string, limit: 20, status: [StatusTypeEnum.Active] },
    skip: !planCode,
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
  })

  return (
    <section>
      <DetailsPage.SectionTitle variant="subhead1" noWrap>
        {translate('text_65281f686a80b400c8e2f6be')}
      </DetailsPage.SectionTitle>

      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } =
            subscriptionResult?.subscriptions?.metadata || {}

          currentPage < totalPages &&
            !areSubscriptionsLoading &&
            fetchMoreSubscriptions({
              variables: { page: currentPage + 1 },
            })
        }}
      >
        <Table
          name="plan-subscriptions"
          data={subscriptionResult?.subscriptions?.collection || []}
          containerSize={0}
          isLoading={areSubscriptionsLoading}
          hasError={!!subscriptionsError}
          rowSize={72}
          onRowActionLink={({ id, plan }) =>
            generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
              planId: plan?.id as string,
              subscriptionId: id as string,
              tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
            })
          }
          placeholder={{
            emptyState: {
              title: translate('text_65281f686a80b400c8e2f6c3'),
              subtitle: translate('text_65281f686a80b400c8e2f6c6'),
            },
            errorState: {
              title: translate('text_62bb102b66ff57dbfe7905c0'),
              subtitle: translate('text_62c3f3fca8a1625624e8337e'),
              buttonTitle: translate('text_62c3f3fca8a1625624e83382'),
              buttonAction: () => location.reload(),
            },
          }}
          columns={[
            {
              key: 'customer.name',
              title: translate('text_624efab67eb2570101d117be'),
              maxSpace: true,
              minWidth: 340,
              content: ({ customer }) => {
                const customerName = customer?.displayName
                const customerInitials = computeCustomerInitials(customer)

                return (
                  <div className="flex items-center gap-3">
                    <Avatar
                      size="big"
                      variant="user"
                      identifier={customerName as string}
                      initials={customerInitials}
                    />
                    <div className="flex flex-col">
                      <Typography variant="bodyHl" color="textSecondary" noWrap>
                        {customerName}
                      </Typography>
                      <TypographyWithCopy variant="caption" color="grey600" noWrap>
                        {customer?.externalId ?? ''}
                      </TypographyWithCopy>
                    </div>
                  </div>
                )
              },
            },
            {
              key: 'plan.parent.id',
              title: translate('text_65281f686a80b400c8e2f6c4'),
              minWidth: 120,
              content: ({ plan }) => (
                <Typography variant="body" color="grey700">
                  {!!plan?.parent?.id
                    ? translate('text_65281f686a80b400c8e2f6dd')
                    : translate('text_65281f686a80b400c8e2f6d1')}
                </Typography>
              ),
            },
            {
              key: 'subscriptionAt',
              title: translate('text_65201c5a175a4b0238abf29e'),
              minWidth: 150,
              content: ({ subscriptionAt }) => (
                <Typography variant="body" color="grey700">
                  {intlFormatDateTime(subscriptionAt).date}
                </Typography>
              ),
            },
            {
              key: 'endingAt',
              title: translate('text_65201c5a175a4b0238abf2a0'),
              minWidth: 150,
              content: ({ endingAt }) => (
                <Typography variant="body" color="grey700">
                  {!!endingAt ? intlFormatDateTime(endingAt).date : '-'}
                </Typography>
              ),
            },
          ]}
        />
      </InfiniteScroll>
    </section>
  )
}

export default PlanSubscriptionList
