import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  INTEGRATIONS_ROUTE,
  useNavigate,
  XERO_INTEGRATION_DETAILS_ROUTE,
  XERO_INTEGRATION_ROUTE,
} from '~/core/router'
import {
  DeleteXeroIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  useGetXeroIntegrationsSettingsQuery,
  XeroForCreateDialogDialogFragmentDoc,
  XeroIntegrationSettingsFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { XeroIntegrationDetailsTabs } from '~/pages/settings/XeroIntegrationDetails'

import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from './AddEditDeleteSuccessRedirectUrlDialog'
import { AddXeroDialog, AddXeroDialogRef } from './AddXeroDialog'
import { useDeleteXeroIntegrationDialog } from './DeleteXeroIntegrationDialog'

const PROVIDER_CONNECTION_LIMIT = 2

gql`
  fragment XeroIntegrationSettings on XeroIntegration {
    id
    code
    connectionId
    hasMappingsConfigured
    name
    syncCreditNotes
    syncInvoices
    syncPayments
  }

  query getXeroIntegrationsSettings(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on XeroIntegration {
        id
        ...XeroIntegrationSettings
        ...DeleteXeroIntegrationDialog
        ...XeroForCreateDialogDialog
      }
    }

    integrations(limit: $limit, types: $integrationsType) {
      collection {
        ... on XeroIntegration {
          id
        }
      }
    }
  }

  ${DeleteXeroIntegrationDialogFragmentDoc}
  ${XeroForCreateDialogDialogFragmentDoc}
`

const buildEnabledSynchronizedLabelKeys = (integration?: XeroIntegrationSettingsFragment) => {
  const labels = [
    'text_661ff6e56ef7e1b7c542b2a6',
    'text_661ff6e56ef7e1b7c542b2c2',
    'text_661ff6e56ef7e1b7c542b2d7',
  ]

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

const XeroIntegrationSettings = () => {
  const navigate = useNavigate()
  const { integrationId = '' } = useParams()
  const addXeroDialogRef = useRef<AddXeroDialogRef>(null)
  const { openDeleteXeroIntegrationDialog } = useDeleteXeroIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetXeroIntegrationsSettingsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Xero],
    },
    skip: !integrationId,
  })
  const xeroIntegration = data?.integration as XeroIntegrationSettingsFragment | undefined
  const deleteDialogCallback = () => {
    if ((data?.integrations?.collection.length || 0) >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(XERO_INTEGRATION_ROUTE, {
          integrationGroup: IntegrationsTabsOptionsEnum.Lago,
        }),
      )
    } else {
      navigate(
        generatePath(INTEGRATIONS_ROUTE, { integrationGroup: IntegrationsTabsOptionsEnum.Lago }),
      )
    }
  }
  const openDeleteDialog = () => {
    if (!xeroIntegration) return
    openDeleteXeroIntegrationDialog({
      provider: xeroIntegration,
      callback: deleteDialogCallback,
    })
  }

  return (
    <>
      <IntegrationsPage.Container className="my-4 md:my-8">
        {!loading && !!xeroIntegration && !xeroIntegration?.hasMappingsConfigured && (
          <Alert
            type="warning"
            ButtonProps={{
              label: translate('text_661ff6e56ef7e1b7c542b20a'),
              onClick: () => {
                navigate(
                  generatePath(XERO_INTEGRATION_DETAILS_ROUTE, {
                    integrationId,
                    tab: XeroIntegrationDetailsTabs.Items,
                    integrationGroup: IntegrationsTabsOptionsEnum.Lago,
                  }),
                )
              },
            }}
          >
            {translate('text_6672ebb8b1b50be550eccaa0')}
          </Alert>
        )}

        <section>
          <IntegrationsPage.Headline label={translate('text_661ff6e56ef7e1b7c542b232')}>
            <Button
              variant="inline"
              disabled={loading}
              onClick={() => {
                addXeroDialogRef.current?.openDialog({
                  provider: xeroIntegration,
                  onDelete: openDeleteDialog,
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
                  value={xeroIntegration?.name}
                />
                <IntegrationsPage.DetailsItem
                  icon="id"
                  label={translate('text_62876e85e32e0300e1803127')}
                  value={xeroIntegration?.code}
                />
                <IntegrationsPage.DetailsItem
                  icon="schema"
                  label={translate('text_661ff6e56ef7e1b7c542b2b4')}
                  value={buildEnabledSynchronizedLabelKeys(xeroIntegration)
                    .map((t) => translate(t))
                    .sort((a, b) => a.localeCompare(b))
                    .join(', ')}
                />
              </>
            )}
          </>
        </section>
      </IntegrationsPage.Container>
      <AddXeroDialog ref={addXeroDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </>
  )
}

export default XeroIntegrationSettings
