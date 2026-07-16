import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddNetsuiteDialog,
  AddNetsuiteDialogRef,
} from '~/components/settings/integrations/AddNetsuiteDialog'
import { useDeleteNetsuiteIntegrationDialog } from '~/components/settings/integrations/DeleteNetsuiteIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { INTEGRATIONS_ROUTE, NETSUITE_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  DeleteNetsuiteIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  NetsuiteForCreateDialogDialogFragmentDoc,
  NetsuiteIntegrationsFragment,
  useGetNetsuiteIntegrationsListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Netsuite from '~/public/images/netsuite.svg'
import { MenuPopper, PopperOpener } from '~/styles'

import { NetsuiteIntegrationDetailsTabs } from './NetsuiteIntegrationDetails'

gql`
  fragment NetsuiteIntegrations on NetsuiteIntegration {
    id
    name
    code
    ...NetsuiteForCreateDialogDialog
  }

  query getNetsuiteIntegrationsList($limit: Int, $types: [IntegrationTypeEnum!]) {
    integrations(limit: $limit, types: $types) {
      collection {
        ... on NetsuiteIntegration {
          id
          ...NetsuiteIntegrations
          ...NetsuiteForCreateDialogDialog
          ...DeleteNetsuiteIntegrationDialog
        }
      }
    }
  }

  ${NetsuiteForCreateDialogDialogFragmentDoc}
  ${DeleteNetsuiteIntegrationDialogFragmentDoc}
`

const NetsuiteIntegrations = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const addNetsuiteDialogRef = useRef<AddNetsuiteDialogRef>(null)
  const { openDeleteNetsuiteIntegrationDialog } = useDeleteNetsuiteIntegrationDialog()
  const { data, loading } = useGetNetsuiteIntegrationsListQuery({
    variables: { limit: 1000, types: [IntegrationTypeEnum.Netsuite] },
  })
  const connections = (
    data?.integrations?.collection as NetsuiteIntegrationsFragment[] | undefined
  )?.filter((c): c is NetsuiteIntegrationsFragment => c !== null)
  const deleteDialogCallback =
    connections && connections?.length === 1
      ? () =>
          navigate(
            generatePath(INTEGRATIONS_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          )
      : undefined

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
        ]}
        entity={{
          viewName: translate('text_661ff6e56ef7e1b7c542b239'),
          viewNameLoading: loading,
          metadata: translate('text_661ff6e56ef7e1b7c542b1e6'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Netsuite />,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_65846763e6140b469140e235'),
              variant: 'primary',
              onClick: () => {
                addNetsuiteDialogRef.current?.openDialog()
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
                  key={`netsuite-connection-${index}`}
                  to={generatePath(NETSUITE_INTEGRATION_DETAILS_ROUTE, {
                    integrationId: connection.id,
                    tab: NetsuiteIntegrationDetailsTabs.Settings,
                    integrationGroup: IntegrationsTabsOptionsEnum.Lago,
                  })}
                  label={connection.name}
                  subLabel={connection.code}
                >
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
                        <Button
                          startIcon="pen"
                          variant="quaternary"
                          align="left"
                          onClick={() => {
                            addNetsuiteDialogRef.current?.openDialog({
                              provider: connection,
                              onDelete: (provider) =>
                                openDeleteNetsuiteIntegrationDialog({
                                  provider,
                                  callback: deleteDialogCallback,
                                }),
                            })
                            closePopper()
                          }}
                        >
                          {translate('text_65845f35d7d69c3ab4793dac')}
                        </Button>
                        <Button
                          startIcon="trash"
                          variant="quaternary"
                          align="left"
                          onClick={() => {
                            openDeleteNetsuiteIntegrationDialog({
                              provider: connection,
                              callback: deleteDialogCallback,
                            })
                            closePopper()
                          }}
                        >
                          {translate('text_645d071272418a14c1c76a81')}
                        </Button>
                      </MenuPopper>
                    )}
                  </Popper>
                </IntegrationsPage.ListItem>
              )
            })}
        </section>
      </IntegrationsPage.Container>
      <AddNetsuiteDialog ref={addNetsuiteDialogRef} />
    </>
  )
}

export default NetsuiteIntegrations
