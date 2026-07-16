import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from '~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog'
import {
  AddNetsuiteDialog,
  AddNetsuiteDialogRef,
} from '~/components/settings/integrations/AddNetsuiteDialog'
import { useDeleteNetsuiteIntegrationDialog } from '~/components/settings/integrations/DeleteNetsuiteIntegrationDialog'
import NetsuiteIntegrationItemsList from '~/components/settings/integrations/NetsuiteIntegrationItemsList'
import NetsuiteIntegrationSettings from '~/components/settings/integrations/NetsuiteIntegrationSettings'
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
  NetsuiteIntegrationDetailsFragment,
  NetsuiteIntegrationItemsFragmentDoc,
  useGetNetsuiteIntegrationsDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { NetsuiteAdditionalMappings } from '~/pages/settings/integrations/NetsuiteAdditionalMappings'
import Netsuite from '~/public/images/netsuite.svg'

const PROVIDER_CONNECTION_LIMIT = 2

export enum NetsuiteIntegrationDetailsTabs {
  Settings = 'settings',
  Items = 'items',
  AdditionalMappings = 'additional-mappings',
}

gql`
  fragment NetsuiteIntegrationDetails on NetsuiteIntegration {
    id
    name
    ...DeleteNetsuiteIntegrationDialog
    ...NetsuiteForCreateDialogDialog
    ...NetsuiteIntegrationItems
  }

  query getNetsuiteIntegrationsDetails(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on NetsuiteIntegration {
        id
        ...NetsuiteIntegrationDetails
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
  ${NetsuiteIntegrationItemsFragmentDoc}
`

const NetsuiteIntegrationDetails = () => {
  const navigate = useNavigate()
  const { integrationId = '' } = useParams()
  const addNetsuiteDialogRef = useRef<AddNetsuiteDialogRef>(null)
  const { openDeleteNetsuiteIntegrationDialog } = useDeleteNetsuiteIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetNetsuiteIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Netsuite],
    },
    skip: !integrationId,
  })
  const netsuiteIntegration = data?.integration as NetsuiteIntegrationDetailsFragment | undefined
  const activeTabContent = useMainHeaderTabContent()
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
            path: generatePath(NETSUITE_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: netsuiteIntegration?.name || '',
          viewNameLoading: loading,
          metadata: `${translate('text_661ff6e56ef7e1b7c542b239')} • ${translate('text_661ff6e56ef7e1b7c542b245')}`,
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Netsuite />,
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
                    addNetsuiteDialogRef.current?.openDialog({
                      provider: netsuiteIntegration,
                      onDelete: (provider) =>
                        openDeleteNetsuiteIntegrationDialog({
                          provider,
                          callback: deleteDialogCallback,
                        }),
                    })
                    closePopper()
                  },
                },
                {
                  label: translate('text_65845f35d7d69c3ab4793dad'),
                  onClick: (closePopper) => {
                    if (netsuiteIntegration) {
                      openDeleteNetsuiteIntegrationDialog({
                        provider: netsuiteIntegration,
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
        tabs={[
          {
            title: translate('text_62728ff857d47b013204c726'),
            link: generatePath(NETSUITE_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: NetsuiteIntegrationDetailsTabs.Settings,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <NetsuiteIntegrationSettings />,
          },
          {
            title: translate('text_1761319649394ft46yvka31r'),
            link: generatePath(NETSUITE_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: NetsuiteIntegrationDetailsTabs.Items,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <NetsuiteIntegrationItemsList integrationId={netsuiteIntegration?.id ?? ''} />,
          },
          {
            title: translate('text_1762436248915jmmwifqjtqd'),
            link: generatePath(NETSUITE_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: NetsuiteIntegrationDetailsTabs.AdditionalMappings,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <NetsuiteAdditionalMappings integrationId={netsuiteIntegration?.id ?? ''} />,
          },
        ]}
      />

      <>{activeTabContent}</>

      <AddNetsuiteDialog ref={addNetsuiteDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </>
  )
}

export default NetsuiteIntegrationDetails
