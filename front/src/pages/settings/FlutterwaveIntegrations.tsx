import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddFlutterwaveDialog,
  AddFlutterwaveDialogRef,
} from '~/components/settings/integrations/AddFlutterwaveDialog'
import { useDeleteFlutterwaveIntegrationDialog } from '~/components/settings/integrations/DeleteFlutterwaveIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  FLUTTERWAVE_INTEGRATION_DETAILS_ROUTE,
  INTEGRATIONS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  DeleteFlutterwaveIntegrationDialogFragmentDoc,
  FlutterwaveProvider,
  ProviderTypeEnum,
  useGetFlutterwaveIntegrationsListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import Flutterwave from '~/public/images/flutterwave.svg'
import { MenuPopper, PopperOpener } from '~/styles'

gql`
  fragment FlutterwaveIntegrations on FlutterwaveProvider {
    id
    name
    code
  }

  query getFlutterwaveIntegrationsList($limit: Int, $type: ProviderTypeEnum) {
    paymentProviders(limit: $limit, type: $type) {
      collection {
        ... on FlutterwaveProvider {
          id
          ...FlutterwaveIntegrations
          ...DeleteFlutterwaveIntegrationDialog
        }
      }
    }
  }

  ${DeleteFlutterwaveIntegrationDialogFragmentDoc}
`

const FlutterwaveIntegrations = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const addDialogRef = useRef<AddFlutterwaveDialogRef>(null)
  const { openDeleteFlutterwaveIntegrationDialog } = useDeleteFlutterwaveIntegrationDialog()
  const { hasPermissions } = usePermissions()

  const { data, loading } = useGetFlutterwaveIntegrationsListQuery({
    variables: { limit: 1000, type: ProviderTypeEnum.Flutterwave },
  })
  const connections = data?.paymentProviders?.collection?.filter(
    (provider) => provider.__typename === 'FlutterwaveProvider',
  ) as FlutterwaveProvider[] | undefined
  const deleteDialogCallback =
    connections && connections.length === 1
      ? () =>
          navigate(
            generatePath(INTEGRATIONS_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Community,
            }),
          )
      : undefined

  const canCreateIntegration = hasPermissions(['organizationIntegrationsCreate'])
  const canEditIntegration = hasPermissions(['organizationIntegrationsUpdate'])
  const canDeleteIntegration = hasPermissions(['organizationIntegrationsDelete'])

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: translate('text_62b1edddbf5f461ab9712750'),
            path: generatePath(INTEGRATIONS_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Community,
            }),
          },
        ]}
        entity={{
          viewName: translate('text_1749725331374clf07sez01f'),
          viewNameLoading: loading,
          metadata: translate('text_62b1edddbf5f461ab971271f'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_634ea0ecc6147de10ddb662d') }],
          icon: <Flutterwave />,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_65846763e6140b469140e235'),
              variant: 'primary',
              hidden: !canCreateIntegration,
              onClick: () => {
                addDialogRef.current?.openDialog()
              },
            },
          ],
          loading,
        }}
      />

      <IntegrationsPage.Container>
        <section>
          <IntegrationsPage.Headline label={translate('text_65846763e6140b469140e239')} />

          {loading &&
            [1, 2].map((i) => <IntegrationsPage.ItemSkeleton key={`item-skeleton-item-${i}`} />)}

          {!loading &&
            connections?.map((connection, index) => {
              return (
                <IntegrationsPage.ListItem
                  key={`flutterwave-connection-${index}`}
                  to={generatePath(FLUTTERWAVE_INTEGRATION_DETAILS_ROUTE, {
                    integrationId: connection.id,
                    integrationGroup: IntegrationsTabsOptionsEnum.Community,
                  })}
                  label={connection.name}
                  subLabel={connection.code}
                >
                  {(canEditIntegration || canDeleteIntegration) && (
                    <Popper
                      PopperProps={{ placement: 'bottom-end' }}
                      opener={({ isOpen }) => (
                        <PopperOpener className="right-0 md:right-0">
                          <Tooltip
                            placement="top-end"
                            disableHoverListener={isOpen}
                            title={translate('text_626162c62f790600f850b7b6')}
                          >
                            <Button
                              icon="dots-horizontal"
                              variant="quaternary"
                              data-test="plan-item-options"
                            />
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
                              align="left"
                              onClick={() => {
                                addDialogRef.current?.openDialog({
                                  provider: connection,
                                  onDelete: (provider) =>
                                    openDeleteFlutterwaveIntegrationDialog({
                                      provider,
                                      callback: deleteDialogCallback,
                                    }),
                                })
                                closePopper()
                              }}
                            >
                              {translate('text_65845f35d7d69c3ab4793dac')}
                            </Button>
                          )}

                          {canDeleteIntegration && (
                            <Button
                              startIcon="trash"
                              variant="quaternary"
                              align="left"
                              onClick={() => {
                                openDeleteFlutterwaveIntegrationDialog({
                                  provider: connection,
                                  callback: deleteDialogCallback,
                                })
                                closePopper()
                              }}
                            >
                              {translate('text_65845f35d7d69c3ab4793dad')}
                            </Button>
                          )}
                        </MenuPopper>
                      )}
                    </Popper>
                  )}
                </IntegrationsPage.ListItem>
              )
            })}
        </section>
      </IntegrationsPage.Container>

      <AddFlutterwaveDialog ref={addDialogRef} />
    </>
  )
}

export default FlutterwaveIntegrations
