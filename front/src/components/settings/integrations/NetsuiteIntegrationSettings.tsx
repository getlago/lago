import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  INTEGRATIONS_ROUTE,
  NETSUITE_INTEGRATION_DETAILS_ROUTE,
  NETSUITE_INTEGRATION_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  DeleteNetsuiteIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  NetsuiteForCreateDialogDialogFragmentDoc,
  NetsuiteIntegrationSettingsFragment,
  useGetNetsuiteIntegrationsSettingsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { NetsuiteIntegrationDetailsTabs } from '~/pages/settings/NetsuiteIntegrationDetails'

import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from './AddEditDeleteSuccessRedirectUrlDialog'
import { AddNetsuiteDialog, AddNetsuiteDialogRef } from './AddNetsuiteDialog'
import { useDeleteNetsuiteIntegrationDialog } from './DeleteNetsuiteIntegrationDialog'

const PROVIDER_CONNECTION_LIMIT = 2

gql`
  fragment NetsuiteIntegrationSettings on NetsuiteIntegration {
    id
    accountId
    clientId
    clientSecret
    code
    hasMappingsConfigured
    name
    scriptEndpointUrl
    syncCreditNotes
    syncInvoices
    syncPayments
  }

  query getNetsuiteIntegrationsSettings(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on NetsuiteIntegration {
        id
        ...NetsuiteIntegrationSettings
        ...DeleteNetsuiteIntegrationDialog
        ...NetsuiteForCreateDialogDialog
      }
    }

    integrations(limit: $limit, types: $integrationsType) {
      collection {
        ... on NetsuiteIntegration {
          id
        }
      }
    }
  }

  ${DeleteNetsuiteIntegrationDialogFragmentDoc}
  ${NetsuiteForCreateDialogDialogFragmentDoc}
`

const buildEnabledSynchronizedLabelKeys = (integration?: NetsuiteIntegrationSettingsFragment) => {
  const labels = ['text_661ff6e56ef7e1b7c542b2c2']

  if (integration?.syncInvoices) {
    labels.push('text_661ff6e56ef7e1b7c542b2ff')
  }

  if (integration?.syncCreditNotes) {
    labels.push('text_661ff6e56ef7e1b7c542b2e9')
  }

  if (integration?.syncPayments) {
    labels.push('text_661ff6e56ef7e1b7c542b311')
  }

  return labels
}

const NetsuiteIntegrationSettings = () => {
  const navigate = useNavigate()
  const { integrationId = '' } = useParams()
  const addNetsuiteDialogRef = useRef<AddNetsuiteDialogRef>(null)
  const { openDeleteNetsuiteIntegrationDialog } = useDeleteNetsuiteIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetNetsuiteIntegrationsSettingsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Netsuite],
    },
    skip: !integrationId,
  })
  const netsuiteIntegration = data?.integration as NetsuiteIntegrationSettingsFragment | undefined
  const deleteDialogCallback = () => {
    if ((data?.integrations?.collection.length || 0) >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(NETSUITE_INTEGRATION_ROUTE, {
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
      <IntegrationsPage.Container className="my-4 md:my-8">
        {!loading && !!netsuiteIntegration && !netsuiteIntegration?.hasMappingsConfigured && (
          <Alert
            type="warning"
            ButtonProps={{
              label: translate('text_661ff6e56ef7e1b7c542b20a'),
              onClick: () => {
                navigate(
                  generatePath(NETSUITE_INTEGRATION_DETAILS_ROUTE, {
                    integrationId,
                    tab: NetsuiteIntegrationDetailsTabs.Items,
                    integrationGroup: IntegrationsTabsOptionsEnum.Lago,
                  }),
                )
              },
            }}
          >
            {translate('text_661ff6e56ef7e1b7c542b218')}
          </Alert>
        )}

        <section>
          <IntegrationsPage.Headline label={translate('text_661ff6e56ef7e1b7c542b232')}>
            <Button
              variant="inline"
              disabled={loading}
              onClick={() => {
                addNetsuiteDialogRef.current?.openDialog({
                  provider: netsuiteIntegration,
                  onDelete: (provider) =>
                    openDeleteNetsuiteIntegrationDialog({
                      provider,
                      callback: deleteDialogCallback,
                    }),
                })
              }}
            >
              {translate('text_62b1edddbf5f461ab9712787')}
            </Button>
          </IntegrationsPage.Headline>

          <>
            {loading &&
              [0, 1, 2].map((i) => (
                <IntegrationsPage.ItemSkeleton key={`item-skeleton-item-${i}`} />
              ))}
            {!loading && (
              <>
                <IntegrationsPage.DetailsItem
                  icon="text"
                  label={translate('text_626162c62f790600f850b76a')}
                  value={netsuiteIntegration?.name}
                />
                <IntegrationsPage.DetailsItem
                  icon="id"
                  label={translate('text_62876e85e32e0300e1803127')}
                  value={netsuiteIntegration?.code}
                />
                <IntegrationsPage.DetailsItem
                  icon="info-circle"
                  label={translate('text_661ff6e56ef7e1b7c542b216')}
                  value={netsuiteIntegration?.accountId ?? undefined}
                />
                <IntegrationsPage.DetailsItem
                  icon="info-circle"
                  label={translate('text_661ff6e56ef7e1b7c542b230')}
                  value={netsuiteIntegration?.clientId ?? undefined}
                />
                <IntegrationsPage.DetailsItem
                  icon="key"
                  label={translate('text_661ff6e56ef7e1b7c542b247')}
                  value={netsuiteIntegration?.clientSecret ?? undefined}
                />
                {!!netsuiteIntegration?.scriptEndpointUrl && (
                  <IntegrationsPage.DetailsItem
                    icon="link"
                    label={translate('text_661ff6e56ef7e1b7c542b2a0')}
                    value={netsuiteIntegration?.scriptEndpointUrl}
                  />
                )}
                <IntegrationsPage.DetailsItem
                  icon="schema"
                  label={translate('text_661ff6e56ef7e1b7c542b2b4')}
                  value={buildEnabledSynchronizedLabelKeys(netsuiteIntegration)
                    .map((t) => translate(t))
                    .sort((a, b) => a.localeCompare(b))
                    .join(', ')}
                />
              </>
            )}
          </>
        </section>
      </IntegrationsPage.Container>

      <AddNetsuiteDialog ref={addNetsuiteDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </>
  )
}

export default NetsuiteIntegrationSettings
