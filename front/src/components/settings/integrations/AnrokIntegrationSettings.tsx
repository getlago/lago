import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { IntegrationsPage } from '~/components/layouts/Integrations'
import { addToast } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  ANROK_INTEGRATION_DETAILS_ROUTE,
  ANROK_INTEGRATION_ROUTE,
  INTEGRATIONS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  AddAnrokIntegrationDialogFragmentDoc,
  AnrokIntegrationSettingsFragment,
  DeleteAnrokIntegrationDialogFragmentDoc,
  useGetAnrokIntegrationsSettingsQuery,
  useRetryAllInvoicesMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { AnrokIntegrationDetailsTabs } from '~/pages/settings/AnrokIntegrationDetails'
import { theme } from '~/styles'

import { AddAnrokDialog, AddAnrokDialogRef } from './AddAnrokDialog'
import { useDeleteAnrokIntegrationDialog } from './DeleteAnrokIntegrationDialog'

const PROVIDER_CONNECTION_LIMIT = 2

gql`
  fragment AnrokIntegrationSettings on AnrokIntegration {
    id
    name
    code
    apiKey
    hasMappingsConfigured
    failedInvoicesCount
  }

  query getAnrokIntegrationsSettings($id: ID!, $limit: Int) {
    integration(id: $id) {
      ... on AnrokIntegration {
        id
        ...AnrokIntegrationSettings
        ...DeleteAnrokIntegrationDialog
        ...AddAnrokIntegrationDialog
      }
    }

    integrations(limit: $limit) {
      collection {
        ... on AnrokIntegration {
          id
        }
      }
    }
  }

  mutation retryAllInvoices($input: RetryAllInvoicesInput!) {
    retryAllInvoices(input: $input) {
      metadata {
        totalCount
      }
    }
  }

  ${DeleteAnrokIntegrationDialogFragmentDoc}
  ${AddAnrokIntegrationDialogFragmentDoc}
`

const AnrokIntegrationSettings = () => {
  const navigate = useNavigate()
  const { integrationId = '' } = useParams()
  const addAnrokDialogRef = useRef<AddAnrokDialogRef>(null)
  const { openDeleteAnrokIntegrationDialog } = useDeleteAnrokIntegrationDialog()
  const { translate } = useInternationalization()
  const [retryAllInvoices] = useRetryAllInvoicesMutation({
    onCompleted(result) {
      if (!!result?.retryAllInvoices?.metadata?.totalCount) {
        addToast({
          severity: 'info',
          message: translate('text_66ba5a76e614f000a738c97f'),
        })
      }
    },
    refetchQueries: ['getAnrokIntegrationsSettings'],
  })
  const { data, loading } = useGetAnrokIntegrationsSettingsQuery({
    variables: {
      id: integrationId as string,
      limit: PROVIDER_CONNECTION_LIMIT,
    },
    skip: !integrationId,
  })
  const anrokIntegration = data?.integration as AnrokIntegrationSettingsFragment | undefined
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
      <IntegrationsPage.Container className="my-4 md:my-8">
        {!!anrokIntegration && !anrokIntegration?.hasMappingsConfigured && (
          <Alert
            type="warning"
            ButtonProps={{
              label: translate('text_661ff6e56ef7e1b7c542b20a'),
              onClick: () => {
                navigate(
                  generatePath(ANROK_INTEGRATION_DETAILS_ROUTE, {
                    integrationId,
                    tab: AnrokIntegrationDetailsTabs.Items,
                    integrationGroup: IntegrationsTabsOptionsEnum.Lago,
                  }),
                )
              },
            }}
          >
            {translate('text_6668821d94e4da4dfd8b3888')}
          </Alert>
        )}

        <section>
          <IntegrationsPage.Headline label={translate('text_661ff6e56ef7e1b7c542b232')}>
            <Button
              variant="inline"
              disabled={loading}
              onClick={() => {
                addAnrokDialogRef.current?.openDialog({
                  integration: anrokIntegration,
                  onDelete: (provider) =>
                    openDeleteAnrokIntegrationDialog({
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
                  value={anrokIntegration?.name}
                />
                <IntegrationsPage.DetailsItem
                  icon="id"
                  label={translate('text_62876e85e32e0300e1803127')}
                  value={anrokIntegration?.code}
                />
                <IntegrationsPage.DetailsItem
                  icon="info-circle"
                  label={translate('text_6668821d94e4da4dfd8b38d5')}
                  value={anrokIntegration?.apiKey}
                />
              </>
            )}
          </>
        </section>

        <Stack
          direction="row"
          gap={4}
          justifyContent="space-between"
          alignItems="baseline"
          paddingBottom={6}
          sx={{ boxShadow: theme.shadows[7] }}
        >
          <Stack flex={1}>
            <Typography variant="bodyHl" color="grey700">
              {translate('text_66ba5a76e614f000a738c97a')}
            </Typography>
            {loading && <Skeleton className="mb-1 mt-2" variant="text" />}
            {!loading && !!anrokIntegration?.failedInvoicesCount && (
              <Typography variant="caption" color="grey600">
                {translate(
                  'text_1746004262383fhhy4jl1g6o',
                  {
                    failedInvoicesCount: anrokIntegration?.failedInvoicesCount,
                  },
                  anrokIntegration?.failedInvoicesCount,
                )}
              </Typography>
            )}
            {!loading && !anrokIntegration?.failedInvoicesCount && (
              <Typography variant="caption" color="grey600">
                {translate('text_66ba5ca33713b600c4e8fcf1')}
              </Typography>
            )}
          </Stack>

          <Button
            variant="inline"
            disabled={!anrokIntegration?.failedInvoicesCount}
            onClick={async () => await retryAllInvoices({ variables: { input: {} } })}
          >
            {translate('text_66ba5a76e614f000a738c97e')}
          </Button>
        </Stack>
      </IntegrationsPage.Container>

      <AddAnrokDialog ref={addAnrokDialogRef} />
    </>
  )
}

export default AnrokIntegrationSettings
