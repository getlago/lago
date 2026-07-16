import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { useCallback } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { useDeleteAlertDialog } from '~/components/subscriptions/alerts/DeleteAlertDialog'
import { useNavigate } from '~/core/router'
import {
  CREATE_ALERT_CUSTOMER_SUBSCRIPTION_ROUTE,
  CREATE_ALERT_PLAN_SUBSCRIPTION_ROUTE,
  UPDATE_ALERT_CUSTOMER_SUBSCRIPTION_ROUTE,
  UPDATE_ALERT_PLAN_SUBSCRIPTION_ROUTE,
} from '~/core/router/ObjectsRoutes'
import { DateFormat, intlFormatDateTime } from '~/core/timezone/utils'
import { useGetAlertsOfSubscriptionQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query getAlertsOfSubscription($subscriptionExternalId: String!, $limit: Int, $page: Int) {
    subscriptionAlerts(
      subscriptionExternalId: $subscriptionExternalId
      limit: $limit
      page: $page
    ) {
      collection {
        id
        code
        createdAt
        name
      }
    }
  }
`
export const SubscriptionAlertsList = ({
  subscriptionExternalId,
}: {
  subscriptionExternalId?: string | null
}) => {
  const { customerId = '', planId = '', subscriptionId = '' } = useParams()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { openDeleteAlertDialog } = useDeleteAlertDialog()
  const canCreateOrUpdateAlert = hasPermissions(['subscriptionsCreate', 'subscriptionsUpdate'])

  const getEditAlertUrl = useCallback(
    (alertId: string) => {
      if (!!customerId) {
        return generatePath(UPDATE_ALERT_CUSTOMER_SUBSCRIPTION_ROUTE, {
          customerId,
          subscriptionId,
          alertId,
        })
      } else if (!!planId) {
        return generatePath(UPDATE_ALERT_PLAN_SUBSCRIPTION_ROUTE, {
          planId,
          subscriptionId,
          alertId,
        })
      }

      return ''
    },
    [customerId, planId, subscriptionId],
  )

  const {
    data: alertsData,
    loading: alertsLoading,
    error: alertsError,
  } = useGetAlertsOfSubscriptionQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      subscriptionExternalId: subscriptionExternalId || '',
      limit: 20,
    },
    skip: !isPremium || !subscriptionExternalId,
  })

  return (
    <section className="flex flex-col gap-4 pt-6">
      <div className="flex items-center justify-between gap-4">
        <div className="flex flex-col gap-2">
          <Typography variant="subhead1" color="grey700">
            {translate('text_17465238490269pahbvl3s2m')}
          </Typography>
          <Typography variant="caption" color="grey600">
            {translate('text_17465238490260r2325jwada')}
          </Typography>
        </div>

        {isPremium && canCreateOrUpdateAlert && (
          <Button
            variant="inline"
            onClick={() => {
              if (!!customerId) {
                navigate(
                  generatePath(CREATE_ALERT_CUSTOMER_SUBSCRIPTION_ROUTE, {
                    customerId,
                    subscriptionId,
                  }),
                )
              } else if (!!planId) {
                navigate(
                  generatePath(CREATE_ALERT_PLAN_SUBSCRIPTION_ROUTE, { planId, subscriptionId }),
                )
              }
            }}
          >
            {translate('text_174652384902646b3ma52uws')}
          </Button>
        )}
      </div>

      {!isPremium && (
        <div className="flex items-center justify-between gap-4 rounded-lg bg-grey-100 px-6 py-4">
          <div>
            <Typography className="flex items-center gap-2" variant="bodyHl" color="textSecondary">
              {translate('text_1746523849026gmu98qidikp')} <Icon name="sparkles" />
            </Typography>
            <Typography variant="caption">{translate('text_1746523849026ljzi79afhmc')}</Typography>
          </div>
          <ButtonLink
            buttonProps={{
              variant: 'tertiary',
              size: 'medium',
              endIcon: 'sparkles',
            }}
            type="button"
            external
            to={`mailto:hello@getlago.com?subject=${translate('text_174652384902646b3ma52uww')}&body=${translate('text_1746523849026ljzi79afhmq')}`}
          >
            {translate('text_65ae73ebe3a66bec2b91d72d')}
          </ButtonLink>
        </div>
      )}

      {!!isPremium && (
        <>
          {!alertsLoading && !alertsData?.subscriptionAlerts.collection.length ? (
            <Typography variant="body" color="grey500">
              {translate('text_1746523849026ljzi79afhmr')}
            </Typography>
          ) : (
            <Table
              name="alerts-list"
              containerSize={0}
              data={alertsData?.subscriptionAlerts.collection || []}
              hasError={!!alertsError}
              isLoading={alertsLoading}
              rowSize={72}
              placeholder={{
                errorState: {
                  title: translate('text_634812d6f16b31ce5cbf4111'),
                  subtitle: translate('text_634812d6f16b31ce5cbf411f'),
                  buttonTitle: translate('text_634812d6f16b31ce5cbf4123'),
                  buttonAction: () => location.reload(),
                },
                emptyState: {
                  title: translate('text_174652384902646b3ma52uwq'),
                  subtitle: translate('text_1746523849026ljzi79afhmr'),
                },
              }}
              columns={[
                {
                  key: 'name',
                  maxSpace: true,
                  minWidth: 200,
                  title: translate('text_6388b923e514213fed58331c'),
                  content: ({ name, code }) => (
                    <div className="flex flex-col gap-1">
                      <Typography color="grey700" variant="bodyHl">
                        {name || '-'}
                      </Typography>
                      <Typography color="grey600" variant="caption">
                        {code || '-'}
                      </Typography>
                    </div>
                  ),
                },
                {
                  key: 'createdAt',
                  minWidth: 140,
                  title: translate('text_62442e40cea25600b0b6d858'),
                  content: ({ createdAt }) => {
                    return (
                      <Typography color="grey600" variant="body">
                        {
                          intlFormatDateTime(createdAt, {
                            formatDate: DateFormat.DATE_FULL,
                          }).date
                        }
                      </Typography>
                    )
                  },
                },
              ]}
              actionColumnTooltip={() => translate('text_6256de3bba111e00b3bfa51b')}
              onRowActionLink={({ id }) => {
                return getEditAlertUrl(id)
              }}
              actionColumn={({ id }) => {
                if (!canCreateOrUpdateAlert) {
                  return []
                }

                return [
                  {
                    title: translate('text_1746546924392wfvshvfrjos'),
                    startIcon: 'pen',
                    onAction: () => {
                      navigate(getEditAlertUrl(id))
                    },
                  },
                  {
                    title: translate('text_17465469243924wwxl5pgoxi'),
                    startIcon: 'trash',
                    onAction: () => {
                      openDeleteAlertDialog({ id })
                    },
                  },
                ]
              }}
            />
          )}
        </>
      )}
    </section>
  )
}
