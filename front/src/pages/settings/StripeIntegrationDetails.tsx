import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from '~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog'
import {
  AddStripeDialog,
  AddStripeDialogRef,
} from '~/components/settings/integrations/AddStripeDialog'
import { useDeleteStripeIntegrationDialog } from '~/components/settings/integrations/DeleteStripeIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { INTEGRATIONS_ROUTE, STRIPE_INTEGRATION_ROUTE, useNavigate } from '~/core/router'
import {
  AddStripeProviderDialogFragmentDoc,
  DeleteStripeIntegrationDialogFragmentDoc,
  ProviderTypeEnum,
  StripeForCreateAndEditSuccessRedirectUrlFragmentDoc,
  StripeIntegrationDetailsFragment,
  useGetStripeIntegrationsDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import Stripe from '~/public/images/stripe.svg'
import { MenuPopper, PopperOpener } from '~/styles'

const PROVIDER_CONNECTION_LIMIT = 2

gql`
  fragment StripeIntegrationDetails on StripeProvider {
    id
    code
    name
    secretKey
    successRedirectUrl
    supports3ds
  }

  query getStripeIntegrationsDetails($id: ID!, $limit: Int, $type: ProviderTypeEnum) {
    paymentProvider(id: $id) {
      ... on StripeProvider {
        id
        ...StripeIntegrationDetails
        ...DeleteStripeIntegrationDialog
        ...AddStripeProviderDialog
        ...StripeForCreateAndEditSuccessRedirectUrl
      }
    }

    paymentProviders(limit: $limit, type: $type) {
      collection {
        ... on StripeProvider {
          id
        }
      }
    }
  }

  ${DeleteStripeIntegrationDialogFragmentDoc}
  ${AddStripeProviderDialogFragmentDoc}
  ${StripeForCreateAndEditSuccessRedirectUrlFragmentDoc}
`

const StripeIntegrationDetails = () => {
  const navigate = useNavigate()
  const { integrationId } = useParams()
  const { hasPermissions } = usePermissions()
  const addDialogRef = useRef<AddStripeDialogRef>(null)
  const { openDeleteStripeIntegrationDialog } = useDeleteStripeIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetStripeIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      type: ProviderTypeEnum.Stripe,
    },
    skip: !integrationId,
  })
  const stripePaymentProvider = data?.paymentProvider as StripeIntegrationDetailsFragment
  const deleteDialogCallback = () => {
    if ((data?.paymentProviders?.collection.length || 0) >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(STRIPE_INTEGRATION_ROUTE, {
          integrationGroup: IntegrationsTabsOptionsEnum.Lago,
        }),
      )
    } else {
      navigate(
        generatePath(INTEGRATIONS_ROUTE, { integrationGroup: IntegrationsTabsOptionsEnum.Lago }),
      )
    }
  }

  const canEditIntegration = hasPermissions(['organizationIntegrationsUpdate'])
  const canDeleteIntegration = hasPermissions(['organizationIntegrationsDelete'])

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: translate('text_62b1edddbf5f461ab9712750'),
            path: generatePath(INTEGRATIONS_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
          {
            label: translate('text_67db6a10cb0b8031ca538909'),
            path: generatePath(STRIPE_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: stripePaymentProvider?.name || '',
          viewNameLoading: loading,
          metadata: `${translate('text_62b1edddbf5f461ab9712707')} • ${translate('text_62b1edddbf5f461ab971271f')}`,
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Stripe />,
        }}
        actions={{
          items: [
            {
              type: 'dropdown',
              label: translate('text_626162c62f790600f850b6fe'),
              items: [
                {
                  label: translate('text_65845f35d7d69c3ab4793dac'),
                  hidden: !canEditIntegration,
                  onClick: (closePopper) => {
                    addDialogRef.current?.openDialog({
                      provider: stripePaymentProvider,
                      onDelete: (provider) =>
                        openDeleteStripeIntegrationDialog({
                          provider,
                          callback: deleteDialogCallback,
                        }),
                    })
                    closePopper()
                  },
                },
                {
                  label: translate('text_65845f35d7d69c3ab4793dad'),
                  hidden: !canDeleteIntegration,
                  onClick: (closePopper) => {
                    openDeleteStripeIntegrationDialog({
                      provider: stripePaymentProvider,
                      callback: deleteDialogCallback,
                    })
                    closePopper()
                  },
                },
              ],
            },
          ],
          loading,
        }}
      />

      <IntegrationsPage.Container>
        <section>
          <IntegrationsPage.Headline label={translate('text_657078c28394d6b1ae1b9725')}>
            {canEditIntegration && (
              <Button
                variant="inline"
                disabled={loading}
                onClick={() => {
                  addDialogRef.current?.openDialog({
                    provider: stripePaymentProvider,
                    onDelete: (provider) =>
                      openDeleteStripeIntegrationDialog({
                        provider,
                        callback: deleteDialogCallback,
                      }),
                  })
                }}
              >
                {translate('text_62b1edddbf5f461ab9712787')}
              </Button>
            )}
          </IntegrationsPage.Headline>

          {loading &&
            [0, 1, 2].map((i) => <IntegrationsPage.ItemSkeleton key={`item-skeleton-item-${i}`} />)}
          {!loading && (
            <>
              <IntegrationsPage.DetailsItem
                icon="text"
                label={translate('text_626162c62f790600f850b76a')}
                value={stripePaymentProvider?.name}
              />
              <IntegrationsPage.DetailsItem
                icon="id"
                label={translate('text_62876e85e32e0300e1803127')}
                value={stripePaymentProvider?.code}
              />
              <IntegrationsPage.DetailsItem
                icon="key"
                label={translate('text_62b1edddbf5f461ab9712748')}
                value={stripePaymentProvider?.secretKey ?? undefined}
              />
              <IntegrationsPage.DetailsItem
                icon="switch"
                label={translate('text_1764107468210ibi78qsrukx')}
                value={
                  stripePaymentProvider?.supports3ds
                    ? translate('text_1764160009979jzn4xunn1z8')
                    : translate('text_176416000997957yqelmt2m2')
                }
              />
            </>
          )}
        </section>

        <section>
          <IntegrationsPage.Headline label={translate('text_65367cb78324b77fcb6af21c')}>
            {canEditIntegration && (
              <Button
                variant="inline"
                disabled={!!stripePaymentProvider?.successRedirectUrl || loading}
                onClick={() => {
                  successRedirectUrlDialogRef.current?.openDialog({
                    mode: 'Add',
                    type: 'Stripe',
                    provider: stripePaymentProvider,
                  })
                }}
              >
                {translate('text_65367cb78324b77fcb6af20e')}
              </Button>
            )}
          </IntegrationsPage.Headline>

          {loading && <IntegrationsPage.ItemSkeleton />}
          {!loading && (
            <>
              {!stripePaymentProvider?.successRedirectUrl ? (
                <Typography variant="caption" color="grey600">
                  {translate('text_65367cb78324b77fcb6af226', {
                    connectionName: translate('text_62b1edddbf5f461ab971277d'),
                  })}
                </Typography>
              ) : (
                <IntegrationsPage.DetailsItem
                  icon="globe"
                  label={translate('text_65367cb78324b77fcb6af1c6')}
                  value={stripePaymentProvider?.successRedirectUrl}
                >
                  {(canEditIntegration || canDeleteIntegration) && (
                    <Popper
                      className="relative"
                      PopperProps={{ placement: 'bottom-end' }}
                      opener={({ isOpen }) => (
                        <PopperOpener className="-top-4 right-0 md:right-0">
                          <Tooltip
                            placement="top-end"
                            disableHoverListener={isOpen}
                            title={translate('text_629728388c4d2300e2d3810d')}
                          >
                            <Button icon="dots-horizontal" variant="quaternary" />
                          </Tooltip>
                        </PopperOpener>
                      )}
                    >
                      {({ closePopper }) => (
                        <MenuPopper>
                          {canEditIntegration && (
                            <Button
                              startIcon="pen"
                              variant="quaternary"
                              fullWidth
                              align="left"
                              onClick={() => {
                                successRedirectUrlDialogRef.current?.openDialog({
                                  mode: 'Edit',
                                  type: 'Stripe',
                                  provider: stripePaymentProvider,
                                })
                                closePopper()
                              }}
                            >
                              {translate('text_65367cb78324b77fcb6af24d')}
                            </Button>
                          )}

                          {canDeleteIntegration && (
                            <Button
                              startIcon="trash"
                              variant="quaternary"
                              align="left"
                              fullWidth
                              onClick={() => {
                                successRedirectUrlDialogRef.current?.openDialog({
                                  mode: 'Delete',
                                  type: 'Stripe',
                                  provider: stripePaymentProvider,
                                })
                                closePopper()
                              }}
                            >
                              {translate('text_65367cb78324b77fcb6af243')}
                            </Button>
                          )}
                        </MenuPopper>
                      )}
                    </Popper>
                  )}
                </IntegrationsPage.DetailsItem>
              )}
            </>
          )}
        </section>
      </IntegrationsPage.Container>

      <AddStripeDialog ref={addDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </>
  )
}

export default StripeIntegrationDetails
