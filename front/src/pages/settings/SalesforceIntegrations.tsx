import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddSalesforceDialog,
  AddSalesforceDialogRef,
} from '~/components/settings/integrations/AddSalesforceDialog'
import { useDeleteSalesforceIntegrationDialog } from '~/components/settings/integrations/DeleteSalesforceIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  INTEGRATIONS_ROUTE,
  SALESFORCE_INTEGRATION_DETAILS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  DeleteSalesforceIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  SalesforceForCreateDialogFragmentDoc,
  SalesforceIntegrationsFragment,
  useGetSalesforceIntegrationsListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Salesforce from '~/public/images/salesforce.svg'
import { MenuPopper, PopperOpener } from '~/styles'

gql`
  fragment SalesforceIntegrations on SalesforceIntegration {
    id
    name
    code
    ...SalesforceForCreateDialog
    ...DeleteSalesforceIntegrationDialog
  }

  query getSalesforceIntegrationsList($limit: Int, $types: [IntegrationTypeEnum!]) {
    integrations(limit: $limit, types: $types) {
      collection {
        ... on SalesforceIntegration {
          id
          ...SalesforceIntegrations
          ...SalesforceForCreateDialog
        }
      }
    }
  }

  ${SalesforceForCreateDialogFragmentDoc}
  ${DeleteSalesforceIntegrationDialogFragmentDoc}
`

const SalesforceIntegrations = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()

  const addSalesforceDialogRef = useRef<AddSalesforceDialogRef>(null)
  const { openDeleteSalesforceIntegrationDialog } = useDeleteSalesforceIntegrationDialog()

  const { data, loading } = useGetSalesforceIntegrationsListQuery({
    variables: { limit: 1000, types: [IntegrationTypeEnum.Salesforce] },
  })

  const connections = (
    data?.integrations?.collection as SalesforceIntegrationsFragment[] | undefined
  )?.filter((c): c is SalesforceIntegrationsFragment => c !== null)
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
          viewName: translate('text_1731507195246vu9kt6xnhv6'),
          viewNameLoading: loading,
          metadata: translate('text_1731510123491gx2nw155ce0'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Salesforce />,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_65846763e6140b469140e235'),
              variant: 'primary',
              onClick: () => {
                addSalesforceDialogRef.current?.openDialog()
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
                  key={`salesforce-connection-${index}`}
                  to={generatePath(SALESFORCE_INTEGRATION_DETAILS_ROUTE, {
                    integrationId: connection.id,
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
                          <Button icon="dots-horizontal" variant="quaternary" />
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
                            addSalesforceDialogRef.current?.openDialog({
                              provider: connection,
                              onDelete: (provider) =>
                                openDeleteSalesforceIntegrationDialog({
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
                            openDeleteSalesforceIntegrationDialog({
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

      <AddSalesforceDialog ref={addSalesforceDialogRef} />
    </>
  )
}

export default SalesforceIntegrations
