import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { Accordion } from '~/components/designSystem/Accordion'
import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { getEntitlementFormattedValue } from '~/components/plans/utils'
import { useDeleteSubscriptionEntitlementDialog } from '~/components/subscriptions/DeleteSubscriptionEntitlementDialog'
import { POPPER_GROUP_NAME } from '~/core/constants/popper'
import {
  CREATE_ENTITLEMENT_CUSTOMER_SUBSCRIPTION_ROUTE,
  CREATE_ENTITLEMENT_PLAN_SUBSCRIPTION_ROUTE,
  UPDATE_ENTITLEMENT_CUSTOMER_SUBSCRIPTION_ROUTE,
  UPDATE_ENTITLEMENT_PLAN_SUBSCRIPTION_ROUTE,
  useNavigate,
} from '~/core/router'
import { useGetEntitlementsForSubscriptionDetailsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import { MenuPopper } from '~/styles/designSystem'

gql`
  query getEntitlementsForSubscriptionDetails($subscriptionId: ID!) {
    subscriptionEntitlements(subscriptionId: $subscriptionId) {
      collection {
        code
        name
        privileges {
          code
          name
          value
          valueType
          config {
            selectOptions
          }
        }
      }
    }
  }
`

export const SubscriptionEntitlementsTabContent = () => {
  const { customerId = '', planId = '', subscriptionId = '' } = useParams()
  const { translate } = useInternationalization()
  const { openDeleteSubscriptionEntitlementDialog } = useDeleteSubscriptionEntitlementDialog()
  const { hasPermissions } = usePermissions()
  const navigate = useNavigate()

  const canCreateAndUpdateEntitlement = hasPermissions([
    'subscriptionsCreate',
    'subscriptionsUpdate',
  ])

  const { data, loading } = useGetEntitlementsForSubscriptionDetailsQuery({
    variables: {
      subscriptionId,
    },
    skip: !subscriptionId,
  })

  if (!data?.subscriptionEntitlements.collection.length && loading) {
    return <DetailsPage.Skeleton />
  }

  return (
    <section className="flex flex-col gap-4 pt-6">
      <div className="flex items-center justify-between gap-4">
        <div className="flex flex-col gap-2">
          <Typography variant="subhead1" color="grey700">
            {translate('text_63e26d8308d03687188221a6')}
          </Typography>
          <Typography variant="caption" color="grey600">
            {translate('text_17558572087883esukvz2ejb')}
          </Typography>
        </div>

        {canCreateAndUpdateEntitlement && (
          <Button
            variant="inline"
            onClick={() => {
              if (!!customerId) {
                navigate(
                  generatePath(CREATE_ENTITLEMENT_CUSTOMER_SUBSCRIPTION_ROUTE, {
                    customerId,
                    subscriptionId,
                  }),
                )
              } else if (!!planId) {
                navigate(
                  generatePath(CREATE_ENTITLEMENT_PLAN_SUBSCRIPTION_ROUTE, {
                    planId,
                    subscriptionId,
                  }),
                )
              }
            }}
          >
            {translate('text_1753864223060devvklm7vk0')}
          </Button>
        )}
      </div>

      <div className="flex flex-col gap-4">
        {!data?.subscriptionEntitlements?.collection?.length && (
          <Typography variant="body" color="grey700">
            {translate('text_1754570508183hxl33n573yk')}
          </Typography>
        )}

        {data?.subscriptionEntitlements?.collection?.map((entitlement) => (
          <Accordion
            key={`subscription-details-entitlement-${entitlement.code}`}
            summary={
              <div className="flex w-full items-center justify-between gap-3 overflow-hidden">
                <div className="flex flex-col">
                  <Typography variant="bodyHl" color="grey700">
                    {entitlement.name || '-'}
                  </Typography>
                  <Typography variant="caption" color="grey600">
                    {entitlement.code}
                  </Typography>
                </div>
                <div className="flex items-center gap-3 p-1 pl-0">
                  <Popper
                    popperGroupName={POPPER_GROUP_NAME.subscriptionEntitlementActions}
                    PopperProps={{ placement: 'bottom-end' }}
                    opener={(opener) => (
                      <Tooltip
                        placement="top-end"
                        title={translate('text_626162c62f790600f850b7b6')}
                      >
                        <Button
                          disabled={loading}
                          icon="dots-horizontal"
                          variant="quaternary"
                          onClick={(e) => {
                            e.stopPropagation()
                            opener.onClick()
                          }}
                        />
                      </Tooltip>
                    )}
                  >
                    {({ closePopper }) => (
                      <MenuPopper>
                        <Button
                          disabled={loading}
                          startIcon="pen"
                          variant="quaternary"
                          align="left"
                          onClick={(e) => {
                            e.stopPropagation()
                            if (!!customerId) {
                              navigate(
                                generatePath(UPDATE_ENTITLEMENT_CUSTOMER_SUBSCRIPTION_ROUTE, {
                                  customerId,
                                  subscriptionId,
                                  entitlementCode: entitlement.code,
                                }),
                              )
                            } else if (!!planId) {
                              navigate(
                                generatePath(UPDATE_ENTITLEMENT_PLAN_SUBSCRIPTION_ROUTE, {
                                  planId,
                                  subscriptionId,
                                  entitlementCode: entitlement.code,
                                }),
                              )
                            }
                            closePopper()
                          }}
                        >
                          {translate('text_17561254890571tcj63iu382')}
                        </Button>
                        <Button
                          disabled={loading}
                          startIcon="trash"
                          variant="quaternary"
                          align="left"
                          onClick={(e) => {
                            e.stopPropagation()
                            openDeleteSubscriptionEntitlementDialog({
                              subscriptionId,
                              featureCode: entitlement.code,
                              featureName: entitlement.name,
                            })
                            closePopper()
                          }}
                        >
                          {translate('text_1756125489057n75k4pb2lbu')}
                        </Button>
                      </MenuPopper>
                    )}
                  </Popper>
                </div>
              </div>
            }
          >
            <div className="flex flex-col gap-4 overflow-x-auto">
              <Typography variant="captionHl" color="grey700">
                {translate('text_1754570508183nhpg3qqdpt8')}
              </Typography>

              {!entitlement.privileges.length && (
                <Typography variant="body" color="grey700">
                  {translate('text_1754570508183hxl33n573yk')}
                </Typography>
              )}

              {!!entitlement.privileges.length && (
                <ChargeTable
                  className="w-full"
                  name={`feature-entitlement-${entitlement.code}-privilege-table`}
                  data={entitlement.privileges || []}
                  columns={[
                    {
                      size: 190,
                      title: (
                        <Typography variant="captionHl" className="px-4">
                          {translate('text_175386422306019wldpp8h5q')}
                        </Typography>
                      ),
                      content: (row) => (
                        <Typography variant="body" color="grey700" className="px-4">
                          {row.name || row.code}
                        </Typography>
                      ),
                    },
                    {
                      size: 190,
                      title: (
                        <Typography variant="captionHl" className="px-4">
                          {translate('text_63fcc3218d35b9377840f5ab')}
                        </Typography>
                      ),
                      content: (row) => (
                        <Typography variant="body" color="grey700" className="px-4">
                          {getEntitlementFormattedValue(row.value, row.valueType, translate)}
                        </Typography>
                      ),
                    },
                  ]}
                />
              )}
            </div>
          </Accordion>
        ))}
      </div>
    </section>
  )
}
