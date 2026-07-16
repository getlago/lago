import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { generatePath, useParams } from 'react-router-dom'

import { Status, StatusProps, StatusType } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import { PageSectionTitle } from '~/components/layouts/Section'
import { SubscriptionsList } from '~/components/subscriptions/SubscriptionsList'
import { TimezoneDate } from '~/components/TimezoneDate'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CREATE_SUBSCRIPTION,
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  StatusTypeEnum,
  Subscription,
  useGetCustomerSubscriptionForListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import { tw } from '~/styles/utils'

gql`
  query getCustomerSubscriptionForList($id: ID!) {
    customer(id: $id) {
      id
      applicableTimezone
      subscriptions {
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
        plan {
          id
          isOverridden
          amountCurrency
          name
          interval
          payInAdvance
          parent {
            id
          }
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
    }
  }
`

export const CustomerSubscriptionsList = () => {
  const { customerId } = useParams()
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { data, loading } = useGetCustomerSubscriptionForListQuery({
    variables: { id: customerId as string },
    skip: !customerId,
    notifyOnNetworkStatusChange: true,
  })
  const subscriptions = data?.customer?.subscriptions as Subscription[]
  const hasNoSubscription = !subscriptions || !subscriptions.length

  return (
    <div>
      <PageSectionTitle
        title={translate('text_6250304370f0f700a8fdc28d')}
        subtitle={translate('text_1736968199827r2u2gd7pypg')}
        action={
          hasPermissions(['subscriptionsCreate'])
            ? {
                title: translate('text_6250304370f0f700a8fdc28b'),
                dataTest: 'add-subscription',
                onClick: () => {
                  navigate(
                    generatePath(CREATE_SUBSCRIPTION, {
                      customerId: customerId as string,
                    }),
                  )
                },
              }
            : undefined
        }
      />

      {!loading && hasNoSubscription && (
        <Typography className="text-grey-500">
          {translate('text_6250304370f0f700a8fdc28f')}
        </Typography>
      )}

      {(!hasNoSubscription || !!loading) && (
        <>
          <SubscriptionsList
            name="customer-subscriptions"
            subscriptions={subscriptions}
            customerId={data?.customer?.id}
            customerTimezone={data?.customer?.applicableTimezone}
            containerSize={4}
            isLoading={loading}
            actionColumnTooltip={() => translate('text_634687079be251fdb438338f')}
            onRowActionLink={({ id }) =>
              generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
                customerId: customerId as string,
                subscriptionId: id,
                tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
              })
            }
            columns={[
              {
                key: 'statusType.type',
                title: translate('text_62d7f6178ec94cd09370e5fb'),
                content: ({ statusType }) => <Status {...(statusType as StatusProps)} />,
              },
              {
                key: 'name',
                maxSpace: true,
                title: translate('text_6253f11816f710014600b9ed'),
                content: ({ name, isDowngrade, isScheduled }) => (
                  <>
                    <div
                      className={tw('relative flex items-center gap-3', {
                        'pl-4': isDowngrade,
                      })}
                    >
                      {isDowngrade && <Icon name="arrow-indent" />}

                      <Typography variant="bodyHl" color="grey700">
                        {name}
                      </Typography>

                      {isDowngrade && <Status type={StatusType.default} label="downgrade" />}

                      {isScheduled && <Status type={StatusType.default} label="scheduled" />}
                    </div>
                  </>
                ),
              },
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
          />
        </>
      )}
    </div>
  )
}

CustomerSubscriptionsList.displayName = 'CustomerSubscriptionsList'
