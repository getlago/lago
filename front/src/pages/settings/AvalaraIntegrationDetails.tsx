import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import {
  AddAvalaraDialog,
  AddAvalaraDialogRef,
} from '~/components/settings/integrations/AddAvalaraDialog'
import {
  AddEditDeleteSuccessRedirectUrlDialog,
  AddEditDeleteSuccessRedirectUrlDialogRef,
} from '~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog'
import AvalaraIntegrationItemsList from '~/components/settings/integrations/AvalaraIntegrationItemsList'
import AvalaraIntegrationSettings from '~/components/settings/integrations/AvalaraIntegrationSettings'
import { useDeleteAvalaraIntegrationDialog } from '~/components/settings/integrations/DeleteAvalaraIntegrationDialog'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  AVALARA_INTEGRATION_DETAILS_ROUTE,
  AVALARA_INTEGRATION_ROUTE,
  INTEGRATIONS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  AddAvalaraIntegrationDialogFragmentDoc,
  AvalaraIntegrationDetailsFragment,
  DeleteAvalaraIntegrationDialogFragmentDoc,
  IntegrationTypeEnum,
  useGetAvalaraIntegrationsDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Avalara from '~/public/images/avalara.svg'

const PROVIDER_CONNECTION_LIMIT = 2

export enum AvalaraIntegrationDetailsTabs {
  Settings = 'settings',
  Items = 'items',
}

gql`
  fragment AvalaraIntegrationDetails on AvalaraIntegration {
    id
    name
    ...DeleteAvalaraIntegrationDialog
    ...AddAvalaraIntegrationDialog
  }

  query getAvalaraIntegrationsDetails(
    $id: ID!
    $limit: Int
    $integrationsType: [IntegrationTypeEnum!]
  ) {
    integration(id: $id) {
      ... on AvalaraIntegration {
        id
        ...AvalaraIntegrationDetails
      }
    }

    integrations(limit: $limit, types: $integrationsType) {
      collection {
        ... on AvalaraIntegration {
          id
        }
      }
    }
  }

  ${DeleteAvalaraIntegrationDialogFragmentDoc}
  ${AddAvalaraIntegrationDialogFragmentDoc}
`

const AvalaraIntegrationDetails = () => {
  const navigate = useNavigate()
  const { integrationId = '' } = useParams()
  const addAvalaraDialogRef = useRef<AddAvalaraDialogRef>(null)
  const { openDeleteAvalaraIntegrationDialog } = useDeleteAvalaraIntegrationDialog()
  const successRedirectUrlDialogRef = useRef<AddEditDeleteSuccessRedirectUrlDialogRef>(null)
  const { translate } = useInternationalization()
  const { data, loading } = useGetAvalaraIntegrationsDetailsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
      integrationsType: [IntegrationTypeEnum.Avalara],
    },
    skip: !integrationId,
  })
  const avalaraIntegration = data?.integration as AvalaraIntegrationDetailsFragment
  const activeTabContent = useMainHeaderTabContent()
  const deleteDialogCallback = () => {
    if ((data?.integrations?.collection.length || 0) >= PROVIDER_CONNECTION_LIMIT) {
      navigate(
        generatePath(AVALARA_INTEGRATION_ROUTE, {
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
            path: generatePath(AVALARA_INTEGRATION_ROUTE, {
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
          },
        ]}
        entity={{
          viewName: avalaraIntegration?.name || '',
          viewNameLoading: loading,
          metadata: `${translate('text_1744293609277s53zn6jcoq4')} • ${translate('text_6668821d94e4da4dfd8b3840')}`,
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Avalara />,
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
                    addAvalaraDialogRef.current?.openDialog({
                      integration: avalaraIntegration,
                      deleteDialogCallback,
                    })
                    closePopper()
                  },
                },
                {
                  label: translate('text_65845f35d7d69c3ab4793dad'),
                  onClick: (closePopper) => {
                    openDeleteAvalaraIntegrationDialog({
                      provider: avalaraIntegration,
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
            link: generatePath(AVALARA_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: AvalaraIntegrationDetailsTabs.Settings,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <AvalaraIntegrationSettings />,
          },
          {
            title: translate('text_1761319649394ft46yvka31r'),
            link: generatePath(AVALARA_INTEGRATION_DETAILS_ROUTE, {
              integrationId,
              tab: AvalaraIntegrationDetailsTabs.Items,
              integrationGroup: IntegrationsTabsOptionsEnum.Lago,
            }),
            content: <AvalaraIntegrationItemsList integrationId={avalaraIntegration?.id} />,
          },
        ]}
      />
      <>{activeTabContent}</>
      <AddAvalaraDialog ref={addAvalaraDialogRef} />
      <AddEditDeleteSuccessRedirectUrlDialog ref={successRedirectUrlDialogRef} />
    </>
  )
}

export default AvalaraIntegrationDetails
