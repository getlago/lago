import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { AddXeroDialog, AddXeroDialogRef } from '~/components/settings/integrations/AddXeroDialog'
import { useDeleteXeroIntegrationDialog } from '~/components/settings/integrations/DeleteXeroIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { INTEGRATIONS_ROUTE, useNavigate, XERO_INTEGRATION_DETAILS_ROUTE } from '~/core/router'
import {
  DeleteXeroIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  useGetXeroIntegrationsListQuery,
  XeroForCreateDialogDialogFragmentDoc,
  XeroIntegrationsFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Xero from '~/public/images/xero.svg'
import { MenuPopper, PopperOpener } from '~/styles'

import { XeroIntegrationDetailsTabs } from './XeroIntegrationDetails'

gql`
  fragment XeroIntegrations on XeroIntegration {
    id
    name
    code
    ...XeroForCreateDialogDialog
  }

  query getXeroIntegrationsList($limit: Int, $types: [IntegrationTypeEnum!]) {
    integrations(limit: $limit, types: $types) {
      collection {
        ... on XeroIntegration {
          id
          ...XeroIntegrations
          ...XeroForCreateDialogDialog
          ...DeleteXeroIntegrationDialog
        }
      }
    }
  }

  ${XeroForCreateDialogDialogFragmentDoc}
  ${DeleteXeroIntegrationDialogFragmentDoc}
`

const XeroIntegrations = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const addXeroDialogRef = useRef<AddXeroDialogRef>(null)
  const { openDeleteXeroIntegrationDialog } = useDeleteXeroIntegrationDialog()
  const { data, loading } = useGetXeroIntegrationsListQuery({
    variables: { limit: 1000, types: [IntegrationTypeEnum.Xero] },
  })
  const connections = (
    data?.integrations?.collection as XeroIntegrationsFragment[] | undefined
  )?.filter((c): c is XeroIntegrationsFragment => c !== null)
  const deleteDialogCallback =
    connections && connections?.length === 1
      ? () =>
          navigate(
            generatePath(INTEGRATIONS_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          )
      : undefined

  const openDeleteDialog = (provider: XeroIntegrationsFragment) => {
    openDeleteXeroIntegrationDialog({
      provider,
      callback: deleteDialogCallback,
    })
  }

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
          viewName: translate('text_6672ebb8b1b50be550eccaf8'),
          viewNameLoading: loading,
          metadata: translate('text_6672ebb8b1b50be550ecca7e'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Xero />,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_65846763e6140b469140e235'),
              variant: 'primary',
              onClick: () => {
                addXeroDialogRef.current?.openDialog()
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
                  key={`xero-connection-${index}`}
                  to={generatePath(XERO_INTEGRATION_DETAILS_ROUTE, {
                    integrationId: connection.id,
                    tab: XeroIntegrationDetailsTabs.Settings,
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
                            addXeroDialogRef.current?.openDialog({
                              provider: connection,
                              onDelete: openDeleteDialog,
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
                            openDeleteDialog(connection)
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

      <AddXeroDialog ref={addXeroDialogRef} />
    </>
  )
}

export default XeroIntegrations
