import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddAnrokDialog,
  AddAnrokDialogRef,
} from '~/components/settings/integrations/AddAnrokDialog'
import { useDeleteAnrokIntegrationDialog } from '~/components/settings/integrations/DeleteAnrokIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { ANROK_INTEGRATION_DETAILS_ROUTE, INTEGRATIONS_ROUTE, useNavigate } from '~/core/router'
import {
  AddAnrokIntegrationDialogFragmentDoc,
  AnrokIntegrationsFragment,
  DeleteAnrokIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  useGetAnrokIntegrationsListQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Anrok from '~/public/images/anrok.svg'
import { MenuPopper, PopperOpener } from '~/styles'

import { AnrokIntegrationDetailsTabs } from './AnrokIntegrationDetails'

gql`
  fragment AnrokIntegrations on AnrokIntegration {
    id
    name
    code
    ...AddAnrokIntegrationDialog
  }

  query getAnrokIntegrationsList($limit: Int, $types: [IntegrationTypeEnum!]) {
    integrations(limit: $limit, types: $types) {
      collection {
        ... on AnrokIntegration {
          id
          ...AnrokIntegrations
          ...AddAnrokIntegrationDialog
          ...DeleteAnrokIntegrationDialog
        }
      }
    }
  }

  ${AddAnrokIntegrationDialogFragmentDoc}
  ${DeleteAnrokIntegrationDialogFragmentDoc}
`

const AnrokIntegrations = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const addAnrokDialogRef = useRef<AddAnrokDialogRef>(null)
  const { openDeleteAnrokIntegrationDialog } = useDeleteAnrokIntegrationDialog()
  const { data, loading } = useGetAnrokIntegrationsListQuery({
    variables: { limit: 1000, types: [IntegrationTypeEnum.Anrok] },
  })
  const connections = (
    data?.integrations?.collection as AnrokIntegrationsFragment[] | undefined
  )?.filter((c): c is AnrokIntegrationsFragment => c !== null)
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
          viewName: translate('text_6668821d94e4da4dfd8b3834'),
          viewNameLoading: loading,
          metadata: translate('text_6668821d94e4da4dfd8b3840'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Anrok />,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_65846763e6140b469140e235'),
              variant: 'primary',
              onClick: () => {
                addAnrokDialogRef.current?.openDialog()
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
                  key={`anrok-connection-${connection.id}`}
                  to={generatePath(ANROK_INTEGRATION_DETAILS_ROUTE, {
                    integrationId: connection.id,
                    tab: AnrokIntegrationDetailsTabs.Settings,
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
                            addAnrokDialogRef.current?.openDialog({
                              integration: connection,
                              onDelete: (provider) =>
                                openDeleteAnrokIntegrationDialog({
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
                            openDeleteAnrokIntegrationDialog({
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
      <AddAnrokDialog ref={addAnrokDialogRef} />
    </>
  )
}

export default AnrokIntegrations
