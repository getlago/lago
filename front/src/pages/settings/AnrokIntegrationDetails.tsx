import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import {
  AddAnrokDialog,
  AddAnrokDialogRef,
} from '~/components/settings/integrations/AddAnrokDialog'
import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from '~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog'
import AnrokIntegrationItemsList from '~/components/settings/integrations/AnrokIntegrationItemsList'
import AnrokIntegrationSettings from '~/components/settings/integrations/AnrokIntegrationSettings'
import { useDeleteAnrokIntegrationDialog } from '~/components/settings/integrations/DeleteAnrokIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  ANROK_INTEGRATION_DETAILS_ROUTE,
  ANROK_INTEGRATION_ROUTE,
  INTEGRATIONS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  AddAnrokIntegrationDialogFragmentDoc,
  AnrokIntegrationDetailsFragment,
  AnrokIntegrationItemsFragmentDoc,
  DeleteAnrokIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  useGetAnrokIntegrationsDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Anrok from '~/public/images/anrok.svg'

const PROVIDER_CONNECTION_LIMIT = 2

export enum AnrokIntegrationDetailsTabs {
  Settings = 'settings',
  Items = 'items',
}

gql`
  fragment AnrokIntegrationDetails on AnrokIntegration {
    id
    name
    ...DeleteAnrokIntegrationDialog
    ...AddAnrokIntegrationDialog
    ...AnrokIntegrationItems
  }

  query getAnrokIntegrationsDetails(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on AnrokIntegration {
        id
        ...AnrokIntegrationDetails
      }
    }

    integrations(limit: $limit, types: $integrationsType) {
      collection {
        ... on AnrokIntegration {
          id
        }
      }
    }
  }

  ${DeleteAnrokIntegrationDialogFragmentDoc}
  ${AddAnrokIntegrationDialogFragmentDoc}
  ${AnrokIntegrationItemsFragmentDoc}
`

const AnrokIntegrationDetails = () => {
  const navigate = useNavigate()
  const { integrationId = '' } = useParams()
  const addAnrokDialogRef = useRef<AddAnrokDialogRef>(null)
  const { openDeleteAnrokIntegrationDialog } = useDeleteAnrokIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetAnrokIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Anrok],
    },
    skip: !integrationId,
  })
  const anrokIntegration = data?.integration as AnrokIntegrationDetailsFragment
  const activeTabContent = useMainHeaderTabContent()
  const deleteDialogCallback = () => {
    if ((data?.integrations?.collection.length || 0) >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(ANROK_INTEGRATION_ROUTE, {
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
            path: generatePath(ANROK_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: anrokIntegration?.name || '',
          viewNameLoading: loading,
          metadata: `${translate('text_6668821d94e4da4dfd8b3834')} • ${translate('text_6668821d94e4da4dfd8b3840')}`,
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Anrok />,
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
                    addAnrokDialogRef.current?.openDialog({
                      integration: anrokIntegration,
                      onDelete: (provider) =>
                        openDeleteAnrokIntegrationDialog({
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
                    openDeleteAnrokIntegrationDialog({
                      provider: anrokIntegration,
                      callback: deleteDialogCallback,
                    })
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
            link: generatePath(ANROK_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: AnrokIntegrationDetailsTabs.Settings,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <AnrokIntegrationSettings />,
          },
          {
            title: translate('text_1761319649394ft46yvka31r'),
            link: generatePath(ANROK_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: AnrokIntegrationDetailsTabs.Items,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <AnrokIntegrationItemsList integrationId={anrokIntegration?.id} />,
          },
        ]}
      />
      <>{activeTabContent}</>
      <AddAnrokDialog ref={addAnrokDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </>
  )
}

export default AnrokIntegrationDetails
