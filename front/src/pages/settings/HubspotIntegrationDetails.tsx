import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddHubspotDialog,
  AddHubspotDialogRef,
} from '~/components/settings/integrations/AddHubspotDialog'
import { useDeleteHubspotIntegrationDialog } from '~/components/settings/integrations/DeleteHubspotIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { HUBSPOT_INTEGRATION_ROUTE, INTEGRATIONS_ROUTE, useNavigate } from '~/core/router'
import {
  DeleteHubspotIntegrationDialogFragmentDoc,
  HubspotForCreateDialogFragmentDoc,
  HubspotIntegrationDetailsFragment,
  IntegrationTypeEnum,
  useGetHubspotIntegrationsDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Hubspot from '~/public/images/hubspot.svg'

const PROVIDER_CONNECTION_LIMIT = 2

gql`
  fragment HubspotIntegrationDetails on HubspotIntegration {
    id
    name
    code
    defaultTargetedObject
    syncInvoices
    syncSubscriptions
    ...HubspotForCreateDialog
    ...DeleteHubspotIntegrationDialog
  }

  query getHubspotIntegrationsDetails(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on HubspotIntegration {
        id
        ...HubspotIntegrationDetails
      }
    }

    integrations(limit: $limit, types: $integrationsType) {
      collection {
        ... on HubspotIntegration {
          id
        }
      }
    }
  }

  ${HubspotForCreateDialogFragmentDoc}
  ${DeleteHubspotIntegrationDialogFragmentDoc}
`

const HubspotIntegrationDetails = () => {
  const { integrationId } = useParams()
  const { translate } = useInternationalization()
  const navigate = useNavigate()

  const addHubspotDialogRef = useRef<AddHubspotDialogRef>(null)
  const { openDeleteHubspotIntegrationDialog } = useDeleteHubspotIntegrationDialog()

  const { data, loading } = useGetHubspotIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Hubspot],
    },
    skip: !integrationId,
  })

  const hubspotIntegration = data?.integration as HubspotIntegrationDetailsFragment | undefined

  const deleteDialogCallback = () => {
    const integrations = data?.integrations?.collection || []

    if (integrations.length >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(HUBSPOT_INTEGRATION_ROUTE, {
          integrationGroup: IntegrationsTabsOptionsEnum.Lago,
        }),
      )
    } else {
      navigate(
        generatePath(INTEGRATIONS_ROUTE, { integrationGroup: IntegrationsTabsOptionsEnum.Lago }),
      )
    }
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
          {
            label: translate('text_67db6a10cb0b8031ca538909'),
            path: generatePath(HUBSPOT_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: hubspotIntegration?.name || '',
          viewNameLoading: loading,
          metadata: translate('text_1727281892403opxm269y6mv'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Hubspot />,
        }}
        actions={{
          items: [
            {
              type: 'dropdown',
              label: translate('text_626162c62f790600f850b6fe'),
              items: [
                {
                  label: translate('text_65845f35d7d69c3ab4793dac'),
                  onClick: (closePopper) => {
                    addHubspotDialogRef.current?.openDialog({
                      provider: hubspotIntegration,
                      deleteDialogCallback,
                    })
                    closePopper()
                  },
                },
                {
                  label: translate('text_65845f35d7d69c3ab4793dad'),
                  hidden: !hubspotIntegration,
                  onClick: (closePopper) => {
                    if (hubspotIntegration) {
                      openDeleteHubspotIntegrationDialog({
                        provider: hubspotIntegration,
                        callback: deleteDialogCallback,
                      })
                    }
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
          <IntegrationsPage.Headline label={translate('text_664c732c264d7eed1c74fdc5')}>
            <Button
              variant="inline"
              disabled={loading}
              onClick={() => {
                addHubspotDialogRef.current?.openDialog({
                  provider: hubspotIntegration,
                  deleteDialogCallback,
                })
              }}
            >
              {translate('text_62b1edddbf5f461ab9712787')}
            </Button>
          </IntegrationsPage.Headline>

          {loading &&
            [0, 1, 2].map((i) => <IntegrationsPage.ItemSkeleton key={`item-skeleton-item-${i}`} />)}

          {!loading && (
            <>
              <IntegrationsPage.DetailsItem
                icon="text"
                label={translate('text_6419c64eace749372fc72b0f')}
                value={hubspotIntegration?.name}
              />
              <IntegrationsPage.DetailsItem
                icon="id"
                label={translate('text_62876e85e32e0300e1803127')}
                value={hubspotIntegration?.code}
              />
              <IntegrationsPage.DetailsItem
                icon="schema"
                label={translate('text_661ff6e56ef7e1b7c542b2b4')}
                value={[
                  translate('text_1727281892403pmg1yza7x1e'),
                  translate('text_1727281892403m7aoqothh7r'),
                  hubspotIntegration?.syncInvoices && translate('text_1727281892403ljelfgyyupg'),
                  hubspotIntegration?.syncSubscriptions &&
                    translate('text_1727281892403w0qjgmdf8n4'),
                ]
                  .filter(Boolean)
                  .join(', ')}
              />
              <IntegrationsPage.DetailsItem
                icon="user-add"
                label={translate('text_1727281892403pbay53j8is3')}
                value={hubspotIntegration?.defaultTargetedObject}
              />
            </>
          )}
        </section>
      </IntegrationsPage.Container>

      <AddHubspotDialog ref={addHubspotDialogRef} />
    </>
  )
}

export default HubspotIntegrationDetails
