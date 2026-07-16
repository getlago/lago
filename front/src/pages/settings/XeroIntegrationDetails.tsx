import { gql } from '@apollo/client'
import Nango from '@nangohq/frontend'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from '~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog'
import { AddXeroDialog, AddXeroDialogRef } from '~/components/settings/integrations/AddXeroDialog'
import { useDeleteXeroIntegrationDialog } from '~/components/settings/integrations/DeleteXeroIntegrationDialog'
import XeroIntegrationItemsList from '~/components/settings/integrations/XeroIntegrationItemsList'
import XeroIntegrationSettings from '~/components/settings/integrations/XeroIntegrationSettings'
import { addToast, envGlobalVar } from '~/core/apolloClient'
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
  useGetXeroIntegrationsDetailsQuery,
  XeroForCreateDialogDialogFragmentDoc,
  XeroIntegrationDetailsFragment,
  XeroIntegrationItemsFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Xero from '~/public/images/xero.svg'

const PROVIDER_CONNECTION_LIMIT = 2

export enum XeroIntegrationDetailsTabs {
  Settings = 'settings',
  Items = 'items',
}

gql`
  fragment XeroIntegrationDetails on XeroIntegration {
    id
    name
    connectionId
    ...DeleteXeroIntegrationDialog
    ...XeroForCreateDialogDialog
    ...XeroIntegrationItems
  }

  query getXeroIntegrationsDetails(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on XeroIntegration {
        id
        ...XeroIntegrationDetails
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
  ${XeroIntegrationItemsFragmentDoc}
`

const XeroIntegrationDetails = () => {
  const navigate = useNavigate()
  const { nangoPublicKey } = envGlobalVar()
  const { integrationId = '' } = useParams()
  const addXeroDialogRef = useRef<AddXeroDialogRef>(null)
  const { openDeleteXeroIntegrationDialog } = useDeleteXeroIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetXeroIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Xero],
    },
    skip: !integrationId,
  })
  const xeroIntegration = data?.integration as XeroIntegrationDetailsFragment
  const activeTabContent = useMainHeaderTabContent()
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
    openDeleteXeroIntegrationDialog({
      provider: xeroIntegration,
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
          {
            label: translate('text_67db6a10cb0b8031ca538909'),
            path: generatePath(XERO_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: xeroIntegration?.name || '',
          viewNameLoading: loading,
          metadata: `${translate('text_6672ebb8b1b50be550eccaf8')} • ${translate('text_661ff6e56ef7e1b7c542b245')}`,
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Xero />,
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
                    addXeroDialogRef.current?.openDialog({
                      provider: xeroIntegration,
                      onDelete: openDeleteDialog,
                    })
                    closePopper()
                  },
                },
                {
                  label: translate('text_62b31e1f6a5b8b1b745ece41'),
                  onClick: async (closePopper) => {
                    const nango = new Nango({ publicKey: nangoPublicKey })

                    try {
                      await nango.auth('xero', xeroIntegration?.connectionId)

                      addToast({
                        message: translate('text_174677760992972pm9p2l5on'),
                        severity: 'success',
                      })
                    } catch {
                      addToast({
                        message: translate('text_62b31e1f6a5b8b1b745ece48'),
                        severity: 'danger',
                      })
                    } finally {
                      closePopper()
                    }
                  },
                },
                {
                  label: translate('text_65845f35d7d69c3ab4793dad'),
                  onClick: (closePopper) => {
                    openDeleteDialog()
                    closePopper()
                  },
                },
              ],
            },
          ],
          loading,
        }}
        tabs={[
          {
            title: translate('text_62728ff857d47b013204c726'),
            link: generatePath(XERO_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: XeroIntegrationDetailsTabs.Settings,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <XeroIntegrationSettings />,
          },
          {
            title: translate('text_1761319649394ft46yvka31r'),
            link: generatePath(XERO_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: XeroIntegrationDetailsTabs.Items,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <XeroIntegrationItemsList integrationId={xeroIntegration?.id} />,
          },
        ]}
      />

      <>{activeTabContent}</>

      <AddXeroDialog ref={addXeroDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </>
  )
}

export default XeroIntegrationDetails
