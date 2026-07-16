import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from '~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog'
import {
  AddGocardlessDialog,
  AddGocardlessDialogRef,
} from '~/components/settings/integrations/AddGocardlessDialog'
import { useDeleteGocardlessIntegrationDialog } from '~/components/settings/integrations/DeleteGocardlessIntegrationDialog'
import { addToast, envGlobalVar } from '~/core/apolloClient'
import { buildGocardlessAuthUrl } from '~/core/constants/externalUrls'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { GOCARDLESS_INTEGRATION_ROUTE, INTEGRATIONS_ROUTE, useNavigate } from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  AddGocardlessProviderDialogFragmentDoc,
  DeleteGocardlessIntegrationDialogFragmentDoc,
  GocardlessIntegrationDetailsFragment,
  ProviderTypeEnum,
  useGetGocardlessIntegrationsDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import GoCardless from '~/public/images/gocardless-large.svg'
import { MenuPopper, PopperOpener } from '~/styles'

const PROVIDER_CONNECTION_LIMIT = 2

gql`
  fragment GocardlessIntegrationDetails on GocardlessProvider {
    id
    code
    name
    successRedirectUrl
    webhookSecret
  }

  query getGocardlessIntegrationsDetails($id: ID!, $limit: Int, $type: ProviderTypeEnum) {
    paymentProvider(id: $id) {
      ... on GocardlessProvider {
        id
        ...GocardlessIntegrationDetails
        ...DeleteGocardlessIntegrationDialog
        ...AddGocardlessProviderDialog
      }
    }

    paymentProviders(limit: $limit, type: $type) {
      collection {
        ... on GocardlessProvider {
          id
        }
      }
    }
  }

  ${DeleteGocardlessIntegrationDialogFragmentDoc}
  ${AddGocardlessProviderDialogFragmentDoc}
`

const GocardlessIntegrationDetails = () => {
  const navigate = useNavigate()
  const { integrationId } = useParams()
  const { lagoOauthProxyUrl } = envGlobalVar()
  const { hasPermissions } = usePermissions()
  const addDialogRef = useRef<AddGocardlessDialogRef>(null)
  const { openDeleteGocardlessIntegrationDialog } = useDeleteGocardlessIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetGocardlessIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      type: ProviderTypeEnum.Gocardless,
    },
    skip: !integrationId,
  })
  const gocardlessPaymentProvider = data?.paymentProvider as GocardlessIntegrationDetailsFragment

  const isConnectionEstablished = true
  // const isConnectionEstablished = !!gocardlessPaymentProvider?.webhookSecret
  const deleteDialogCallback = () => {
    if ((data?.paymentProviders?.collection.length || 0) >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(GOCARDLESS_INTEGRATION_ROUTE, {
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
    <div>
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
            path: generatePath(GOCARDLESS_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: gocardlessPaymentProvider?.name || '',
          viewNameLoading: loading,
          metadata: `${translate('text_634ea0ecc6147de10ddb6648')} • ${translate('text_62b1edddbf5f461ab971271f')}`,
          metadataLoading: loading,
          badges: isConnectionEstablished
            ? [{ type: 'default', label: translate('text_634ea0ecc6147de10ddb662d') }]
            : [],
          icon: <GoCardless />,
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
                      provider: gocardlessPaymentProvider,
                      deleteDialogCallback,
                    })
                    closePopper()
                  },
                },
                {
                  label: translate('text_658567dffff71e31ea5f0d33'),
                  hidden: !canEditIntegration,
                  onClick: (closePopper) => {
                    setTimeout(() => {
                      const myWindow = window.open('', '_blank')

                      if (myWindow?.location?.href) {
                        myWindow.location.href = buildGocardlessAuthUrl(
                          lagoOauthProxyUrl,
                          gocardlessPaymentProvider.name,
                          gocardlessPaymentProvider.code,
                        )
                        closePopper()
                        return myWindow?.focus()
                      }

                      myWindow?.close()
                      addToast({
                        severity: 'danger',
                        translateKey: 'text_62b31e1f6a5b8b1b745ece48',
                      })
                    }, 0)
                  },
                },
                {
                  label: translate('text_65845f35d7d69c3ab4793dad'),
                  hidden: !canDeleteIntegration,
                  onClick: (closePopper) => {
                    openDeleteGocardlessIntegrationDialog({
                      provider: gocardlessPaymentProvider,
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
          <IntegrationsPage.Headline label={translate('text_637f813d31381b1ed90ab315')}>
            {canEditIntegration && (
              <Button
                variant="inline"
                align="left"
                onClick={() => {
                  addDialogRef.current?.openDialog({
                    provider: gocardlessPaymentProvider,
                    deleteDialogCallback,
                  })
                }}
              >
                {translate('text_62b1edddbf5f461ab9712787')}
              </Button>
            )}
          </IntegrationsPage.Headline>

          {loading && (
            <>
              {[0, 1, 2].map((i) => (
                <IntegrationsPage.ItemSkeleton key={`item-skeleton-${i}`} />
              ))}
              <div style={{ height: 20 }} />
              <Skeleton variant="text" className="mb-4 w-60" />
            </>
          )}
          {!loading && isConnectionEstablished && (
            <>
              <IntegrationsPage.DetailsItem
                icon="text"
                label={translate('text_626162c62f790600f850b76a')}
                value={gocardlessPaymentProvider?.name}
              />
              <IntegrationsPage.DetailsItem
                icon="id"
                label={translate('text_62876e85e32e0300e1803127')}
                value={gocardlessPaymentProvider?.code}
              />
              <IntegrationsPage.DetailsItem
                icon="key"
                label={translate('text_658567dffff71e31ea5f0d3e')}
                value={gocardlessPaymentProvider?.webhookSecret ?? undefined}
              >
                <Tooltip title={translate('text_6360ddae753a8b3e11c80c66')} placement="top-end">
                  <Button
                    variant="quaternary"
                    onClick={() => {
                      copyToClipboard(gocardlessPaymentProvider?.webhookSecret as string)
                      addToast({
                        severity: 'info',
                        translateKey: 'text_6360ddae753a8b3e11c80c6c',
                      })
                    }}
                  >
                    <Icon name="duplicate" />
                  </Button>
                </Tooltip>
              </IntegrationsPage.DetailsItem>

              <Typography className="mt-3" variant="caption">
                {translate('text_635bd8acb686f18909a57c93')}
              </Typography>
            </>
          )}
        </section>

        <section>
          <IntegrationsPage.Headline label={translate('text_65367cb78324b77fcb6af21c')}>
            {canEditIntegration && (
              <Button
                variant="inline"
                disabled={!!gocardlessPaymentProvider?.successRedirectUrl}
                onClick={() => {
                  successRedirectUrlDialogRef.current?.openDialog({
                    mode: 'Add',
                    type: 'GoCardless',
                    provider: gocardlessPaymentProvider,
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
              {!gocardlessPaymentProvider?.successRedirectUrl ? (
                <Typography variant="caption" color="grey600">
                  {translate('text_65367cb78324b77fcb6af226', {
                    connectionName: translate('text_634ea0ecc6147de10ddb6625'),
                  })}
                </Typography>
              ) : (
                <>
                  <IntegrationsPage.DetailsItem
                    icon="globe"
                    label={translate('text_65367cb78324b77fcb6af1c6')}
                    value={gocardlessPaymentProvider?.successRedirectUrl}
                  >
                    {(canEditIntegration || canDeleteIntegration) && (
                      <Popper
                        className="relative h-full"
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
                                    type: 'GoCardless',
                                    provider: gocardlessPaymentProvider,
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
                                    type: 'GoCardless',
                                    provider: gocardlessPaymentProvider,
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
                </>
              )}
            </>
          )}
        </section>
      </IntegrationsPage.Container>
      <AddGocardlessDialog ref={addDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </div>
  )
}

export default GocardlessIntegrationDetails
