import { gql } from '@apollo/client'
import { useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { StatusType } from '~/components/designSystem/Status'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { AUTHENTICATION_ROUTE, useNavigate } from '~/core/router'
import {
  AddOktaIntegrationDialogFragmentDoc,
  AuthenticationMethodsEnum,
  DeleteOktaIntegrationDialogFragmentDoc,
  LagoApiError,
  OktaIntegration,
  useGetOktaIntegrationQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import Okta from '~/public/images/okta.svg'

import { useAddOktaDialog } from './dialogs/AddOktaDialog'
import { useDeleteOktaIntegrationDialog } from './dialogs/DeleteOktaIntegrationDialog'

gql`
  fragment OktaIntegrationDetails on OktaIntegration {
    id
    clientId
    clientSecret
    code
    organizationName
    domain
    name
    host
  }

  query GetOktaIntegration($id: ID) {
    integration(id: $id) {
      ... on OktaIntegration {
        ...OktaIntegrationDetails
        ...AddOktaIntegrationDialog
        ...DeleteOktaIntegrationDialog
      }
    }
  }

  ${AddOktaIntegrationDialogFragmentDoc}
  ${DeleteOktaIntegrationDialogFragmentDoc}
`

const OktaAuthenticationDetails = () => {
  const { translate } = useInternationalization()
  const { integrationId } = useParams()
  const { organization } = useOrganizationInfos()
  const navigate = useNavigate()

  const { openAddOktaDialog } = useAddOktaDialog()
  const { openDeleteOktaIntegrationDialog } = useDeleteOktaIntegrationDialog()

  const { data, loading, refetch } = useGetOktaIntegrationQuery({
    variables: { id: integrationId },
    skip: !integrationId,
    context: {
      silentErrorCodes: [LagoApiError.NotFound],
    },
  })

  const integration = data?.integration as OktaIntegration | null

  const hasOtherAuthenticationMethodsThanOkta = organization?.authenticationMethods.some(
    (method) => method !== AuthenticationMethodsEnum.Okta,
  )

  const onDeleteCallback = () => {
    navigate(AUTHENTICATION_ROUTE)
  }

  const onEditCallback = () => {
    refetch()
  }

  if (!integration) {
    navigate(AUTHENTICATION_ROUTE)
    return null
  }

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: translate('text_664c732c264d7eed1c74fd96'),
            path: AUTHENTICATION_ROUTE,
          },
        ]}
        entity={{
          viewName: translate('text_664c732c264d7eed1c74fda2'),
          viewNameLoading: loading,
          metadata: translate('text_664c732c264d7eed1c74fdbd'),
          metadataLoading: loading,
          icon: <Okta />,
          badges: [
            {
              label: translate('text_62b1edddbf5f461ab971270d'),
              type: StatusType.default,
            },
          ],
        }}
        actions={{
          items: [
            {
              type: 'dropdown',
              label: translate('text_626162c62f790600f850b6fe'),
              items: [
                {
                  label: translate('text_664c732c264d7eed1c74fdaa'),
                  onClick: (closePopper) => {
                    closePopper()
                    openAddOktaDialog({
                      integration,
                      callback: onEditCallback,
                      deleteCallback: onDeleteCallback,
                    })
                  },
                },
                {
                  label: translate('text_664c732c264d7eed1c74fdb0'),
                  onClick: (closePopper) => {
                    closePopper()
                    openDeleteOktaIntegrationDialog({
                      integration,
                      callback: onDeleteCallback,
                    })
                  },
                  disabled: !hasOtherAuthenticationMethodsThanOkta,
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
              onClick={() =>
                openAddOktaDialog({
                  integration,
                  callback: onEditCallback,
                  deleteCallback: onDeleteCallback,
                })
              }
            >
              {translate('text_62b1edddbf5f461ab9712787')}
            </Button>
          </IntegrationsPage.Headline>

          {loading ? (
            [0, 1, 2, 3].map((i) => (
              <IntegrationsPage.ItemSkeleton key={`item-skeleton-item-${i}`} />
            ))
          ) : (
            <>
              <IntegrationsPage.DetailsItem
                icon="globe"
                label={translate('text_664c732c264d7eed1c74fd94')}
                value={integration.domain}
              />
              <IntegrationsPage.DetailsItem
                icon="globe"
                label={translate('text_1763560144639jp40amfwhn5')}
                value={integration.host || 'N/A'}
              />
              <IntegrationsPage.DetailsItem
                icon="key"
                label={translate('text_664c732c264d7eed1c74fda6')}
                value={integration.clientId || 'N/A'}
              />
              <IntegrationsPage.DetailsItem
                icon="key"
                label={translate('text_664c732c264d7eed1c74fdb2')}
                value={integration.clientSecret || 'N/A'}
              />
              <IntegrationsPage.DetailsItem
                icon="text"
                label={translate('text_664c732c264d7eed1c74fdbb')}
                value={integration.organizationName}
              />
            </>
          )}
        </section>
      </IntegrationsPage.Container>
    </>
  )
}

export default OktaAuthenticationDetails
