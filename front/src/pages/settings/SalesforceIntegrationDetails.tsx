import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  AddSalesforceDialog,
  AddSalesforceDialogRef,
} from '~/components/settings/integrations/AddSalesforceDialog'
import { useDeleteSalesforceIntegrationDialog } from '~/components/settings/integrations/DeleteSalesforceIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { INTEGRATIONS_ROUTE, SALESFORCE_INTEGRATION_ROUTE, useNavigate } from '~/core/router'
import {
  DeleteSalesforceIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  SalesforceForCreateDialogFragmentDoc,
  SalesforceIntegrationDetailsFragment,
  useGetSalesforceIntegrationsDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Salesforce from '~/public/images/salesforce.svg'

const PROVIDER_CONNECTION_LIMIT = 2

gql`
  fragment SalesforceIntegrationDetails on SalesforceIntegration {
    id
    name
    code
    instanceId
    ...SalesforceForCreateDialog
    ...DeleteSalesforceIntegrationDialog
  }

  query getSalesforceIntegrationsDetails(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on SalesforceIntegration {
        id
        ...SalesforceIntegrationDetails
      }
    }

    integrations(limit: $limit, types: $integrationsType) {
      collection {
        ... on SalesforceIntegration {
          id
        }
      }
    }
  }

  ${SalesforceForCreateDialogFragmentDoc}
  ${DeleteSalesforceIntegrationDialogFragmentDoc}
`

const SalesforceIntegrationDetails = () => {
  const { integrationId } = useParams()
  const { translate } = useInternationalization()
  const navigate = useNavigate()

  const addSalesforceDialogRef = useRef<AddSalesforceDialogRef>(null)
  const { openDeleteSalesforceIntegrationDialog } = useDeleteSalesforceIntegrationDialog()

  const { data, loading } = useGetSalesforceIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Salesforce],
    },
    skip: !integrationId,
  })

  const salesforceIntegration = data?.integration as
    SalesforceIntegrationDetailsFragment | undefined

  const deleteDialogCallback = () => {
    const integrations = data?.integrations?.collection || []

    if (integrations.length >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(SALESFORCE_INTEGRATION_ROUTE, {
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
            path: generatePath(SALESFORCE_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: salesforceIntegration?.name || '',
          viewNameLoading: loading,
          metadata: translate('text_1731510123491gx2nw155ce0'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Salesforce />,
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
                    addSalesforceDialogRef.current?.openDialog({
                      provider: salesforceIntegration,
                      onDelete: (provider) =>
                        openDeleteSalesforceIntegrationDialog({
                          provider,
                          callback: deleteDialogCallback,
                        }),
                    })
                    closePopper()
                  },
                },
                {
                  label: translate('text_65845f35d7d69c3ab4793dad'),
                  hidden: !salesforceIntegration,
                  onClick: (closePopper) => {
                    if (salesforceIntegration) {
                      openDeleteSalesforceIntegrationDialog({
                        provider: salesforceIntegration,
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
          <div className="flex h-18 w-full items-center justify-between">
            <Typography variant="subhead1">{translate('text_664c732c264d7eed1c74fdc5')}</Typography>
            <Button
              variant="inline"
              disabled={loading}
              onClick={() => {
                addSalesforceDialogRef.current?.openDialog({
                  provider: salesforceIntegration,
                  onDelete: (provider) =>
                    openDeleteSalesforceIntegrationDialog({
                      provider,
                      callback: deleteDialogCallback,
                    }),
                })
              }}
            >
              {translate('text_62b1edddbf5f461ab9712787')}
            </Button>
          </div>

          {loading &&
            [0, 1, 2].map((i) => <IntegrationsPage.ItemSkeleton key={`item-skeleton-item-${i}`} />)}
          {!loading && (
            <>
              <IntegrationsPage.DetailsItem
                icon="text"
                label={translate('text_6419c64eace749372fc72b0f')}
                value={salesforceIntegration?.name}
              />
              <IntegrationsPage.DetailsItem
                icon="id"
                label={translate('text_62876e85e32e0300e1803127')}
                value={salesforceIntegration?.code}
              />
              <IntegrationsPage.DetailsItem
                icon="link"
                label={translate('text_1731510123491s8iyc3roglx')}
                value={salesforceIntegration?.instanceId}
              />
            </>
          )}
        </section>
      </IntegrationsPage.Container>

      <AddSalesforceDialog ref={addSalesforceDialogRef} />
    </>
  )
}

export default SalesforceIntegrationDetails
