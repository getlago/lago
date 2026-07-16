import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddAvalaraDialog,
  AddAvalaraDialogRef,
} from '~/components/settings/integrations/AddAvalaraDialog'
import { useDeleteAvalaraIntegrationDialog } from '~/components/settings/integrations/DeleteAvalaraIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { AVALARA_INTEGRATION_DETAILS_ROUTE, INTEGRATIONS_ROUTE, useNavigate } from '~/core/router'
import {
  AddAvalaraIntegrationDialogFragmentDoc,
  AvalaraIntegrationsFragment,
  DeleteAvalaraIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  useGetAvalaraIntegrationsListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { AvalaraIntegrationDetailsTabs } from '~/pages/settings/AvalaraIntegrationDetails'
import Avalara from '~/public/images/avalara.svg'
import { MenuPopper, PopperOpener } from '~/styles'

// import { AvalaraIntegrationDetailsTabs } from './AvalaraIntegrationDetails'

gql`
  fragment AvalaraIntegrations on AvalaraIntegration {
    id
    name
    code
    ...AddAvalaraIntegrationDialog
  }

  query getAvalaraIntegrationsList($limit: Int, $types: [IntegrationTypeEnum!]) {
    integrations(limit: $limit, types: $types) {
      collection {
        ... on AvalaraIntegration {
          id
          ...AvalaraIntegrations
          ...AddAvalaraIntegrationDialog
          ...DeleteAvalaraIntegrationDialog
        }
      }
    }
  }

  ${AddAvalaraIntegrationDialogFragmentDoc}
  ${DeleteAvalaraIntegrationDialogFragmentDoc}
`

const AvalaraIntegrations = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const addAvalaraDialogRef = useRef<AddAvalaraDialogRef>(null)
  const { openDeleteAvalaraIntegrationDialog } = useDeleteAvalaraIntegrationDialog()
  const { data, loading } = useGetAvalaraIntegrationsListQuery({
    variables: { limit: 1000, types: [IntegrationTypeEnum.Avalara] },
  })
  const connections = (
    data?.integrations?.collection as AvalaraIntegrationsFragment[] | undefined
  )?.filter((c): c is AvalaraIntegrationsFragment => c !== null)
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
          viewName: translate('text_1744293609277s53zn6jcoq4'),
          viewNameLoading: loading,
          metadata: translate('text_6668821d94e4da4dfd8b3840'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Avalara />,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_65846763e6140b469140e235'),
              variant: 'primary',
              onClick: () => {
                addAvalaraDialogRef.current?.openDialog()
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
            connections?.map((connection) => {
              return (
                <IntegrationsPage.ListItem
                  key={`avalara-connection-${connection.id}`}
                  to={generatePath(AVALARA_INTEGRATION_DETAILS_ROUTE, {
                    integrationId: connection.id,
                    tab: AvalaraIntegrationDetailsTabs.Settings,
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
                            addAvalaraDialogRef.current?.openDialog({
                              integration: connection,
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
                            openDeleteAvalaraIntegrationDialog({
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
      <AddAvalaraDialog ref={addAvalaraDialogRef} />
    </>
  )
}

export default AvalaraIntegrations
