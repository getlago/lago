import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddHubspotDialog,
  AddHubspotDialogRef,
} from '~/components/settings/integrations/AddHubspotDialog'
import { useDeleteHubspotIntegrationDialog } from '~/components/settings/integrations/DeleteHubspotIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { HUBSPOT_INTEGRATION_DETAILS_ROUTE, INTEGRATIONS_ROUTE, useNavigate } from '~/core/router'
import {
  HubspotForCreateDialogFragmentDoc,
  HubspotIntegrationsFragment,
  IntegrationTypeEnum,
  useGetHubspotIntegrationsListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Hubspot from '~/public/images/hubspot.svg'
import { MenuPopper, PopperOpener } from '~/styles'

gql`
  fragment HubspotIntegrations on HubspotIntegration {
    id
    name
    code
    ...HubspotForCreateDialog
  }

  query getHubspotIntegrationsList($limit: Int, $types: [IntegrationTypeEnum!]) {
    integrations(limit: $limit, types: $types) {
      collection {
        ... on HubspotIntegration {
          id
          ...HubspotIntegrations
          ...HubspotForCreateDialog
        }
      }
    }
  }

  ${HubspotForCreateDialogFragmentDoc}
`

const HubspotIntegrations = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()

  const addHubspotDialogRef = useRef<AddHubspotDialogRef>(null)
  const { openDeleteHubspotIntegrationDialog } = useDeleteHubspotIntegrationDialog()

  const { data, loading } = useGetHubspotIntegrationsListQuery({
    variables: { limit: 1000, types: [IntegrationTypeEnum.Hubspot] },
  })

  const connections = (
    data?.integrations?.collection as HubspotIntegrationsFragment[] | undefined
  )?.filter((c): c is HubspotIntegrationsFragment => c !== null)
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
          viewName: translate('text_1727189568053s79ks5q07tr'),
          viewNameLoading: loading,
          metadata: translate('text_1727281892403opxm269y6mv'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Hubspot />,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_65846763e6140b469140e235'),
              variant: 'primary',
              onClick: () => {
                addHubspotDialogRef.current?.openDialog()
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
                  key={`hubspot-connection-${index}`}
                  to={generatePath(HUBSPOT_INTEGRATION_DETAILS_ROUTE, {
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
                            addHubspotDialogRef.current?.openDialog({
                              provider: connection,
                              deleteDialogCallback,
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
                            openDeleteHubspotIntegrationDialog({
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
      <AddHubspotDialog ref={addHubspotDialogRef} />
    </>
  )
}

export default HubspotIntegrations
