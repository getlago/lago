import { gql } from '@apollo/client'
import { useEffect } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Spinner } from '~/components/designSystem/Spinner'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { addToast } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  GOCARDLESS_INTEGRATION_DETAILS_ROUTE,
  INTEGRATIONS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  AddGocardlessProviderDialogFragmentDoc,
  useAddGocardlessApiKeyMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Gocardless from '~/public/images/gocardless.svg'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  fragment GocardlessIntegrationOauthCallback on GocardlessProvider {
    id
    name
    code
  }

  mutation addGocardlessApiKey($input: AddGocardlessPaymentProviderInput!) {
    addGocardlessPaymentProvider(input: $input) {
      id
      ...AddGocardlessProviderDialog
      ...GocardlessIntegrationOauthCallback
    }
  }

  ${AddGocardlessProviderDialogFragmentDoc}
`

const GocardlessIntegrationOauthCallback = () => {
  const [searchParams] = useSearchParams()
  const accessCode = searchParams.get('code') || ''
  const code = searchParams.get('lago_code') || ''
  const name = searchParams.get('lago_name') || ''

  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const [addGocardlessApiKey, { loading, error }] = useAddGocardlessApiKeyMutation()

  useEffect(() => {
    const createIntegration = async () => {
      const res = await addGocardlessApiKey({
        variables: {
          input: {
            accessCode,
            code,
            name,
          },
        },
      })

      navigate(
        generatePath(GOCARDLESS_INTEGRATION_DETAILS_ROUTE, {
          integrationId: res.data?.addGocardlessPaymentProvider?.id as string,
          integrationGroup: IntegrationsTabsOptionsEnum.Lago,
        }),
      )
    }

    if (!!code && !!accessCode && !!name) {
      createIntegration()
    } else {
      navigate(
        generatePath(INTEGRATIONS_ROUTE, { integrationGroup: IntegrationsTabsOptionsEnum.Lago }),
      )

      addToast({
        severity: 'danger',
        translateKey: 'text_622f7a3dc32ce100c46a5154',
      })
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

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
        ]}
        entity={{
          viewName: translate('text_634ea0ecc6147de10ddb6625'),
          viewNameLoading: loading,
          metadata: translate('text_62b1edddbf5f461ab971271f'),
          metadataLoading: loading,
          badges: [{ type: 'default', label: translate('text_62b1edddbf5f461ab971270d') }],
          icon: <Gocardless />,
        }}
      />

      {loading || !error ? (
        <Spinner />
      ) : (
        <GenericPlaceholder
          image={<ErrorImage width="136" height="104" />}
          title={translate('text_62bac37900192b773560e82d')}
          subtitle={translate('text_62bac37900192b773560e82f')}
          buttonTitle={translate('text_62bac37900192b773560e831')}
          buttonAction={() =>
            navigate(
              generatePath(INTEGRATIONS_ROUTE, {
                integrationGroup: IntegrationsTabsOptionsEnum.Lago,
              }),
            )
          }
        />
      )}
    </>
  )
}

export default GocardlessIntegrationOauthCallback
