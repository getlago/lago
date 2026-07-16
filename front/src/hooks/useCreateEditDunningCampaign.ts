import { gql } from '@apollo/client'
import { useEffect, useMemo } from 'react'
import { useParams } from 'react-router-dom'

import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { DUNNINGS_SETTINGS_ROUTE, ERROR_404_ROUTE, useNavigate } from '~/core/router'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CreateDunningCampaignInput,
  DunningCampaignFormFragment,
  LagoApiError,
  useCreateDunningCampaignMutation,
  useCreateDunningCampaignPaymentProviderQuery,
  useGetSingleCampaignQuery,
  useUpdateDunningCampaignMutation,
} from '~/generated/graphql'

export type DunningCampaignFormInput = Omit<
  CreateDunningCampaignInput,
  'daysBetweenAttempts' | 'maxAttempts' | 'bccEmails'
> & {
  daysBetweenAttempts: string
  maxAttempts: string
  bccEmails: string
}

gql`
  fragment DunningCampaignForm on DunningCampaign {
    name
    code
    description
    thresholds {
      amountCents
      currency
    }
    daysBetweenAttempts
    maxAttempts
    appliedToOrganization
    bccEmails
  }

  query GetSingleCampaign($id: ID!) {
    dunningCampaign(id: $id) {
      id
      ...DunningCampaignForm
    }
  }

  query CreateDunningCampaignPaymentProvider {
    paymentProviders {
      collection {
        __typename
      }
    }
  }

  mutation CreateDunningCampaign($input: CreateDunningCampaignInput!) {
    createDunningCampaign(input: $input) {
      id
      ...DunningCampaignForm
    }
  }

  mutation UpdateDunningCampaign($input: UpdateDunningCampaignInput!) {
    updateDunningCampaign(input: $input) {
      id
      ...DunningCampaignForm
    }
  }
`

const formatPayload = (values: DunningCampaignFormInput): CreateDunningCampaignInput => {
  return {
    ...values,
    daysBetweenAttempts: Number(values.daysBetweenAttempts),
    maxAttempts: Number(values.maxAttempts),
    thresholds: values.thresholds.map((threshold) => ({
      ...threshold,
      amountCents: serializeAmount(threshold.amountCents, threshold.currency),
    })),
    bccEmails: Array.from(
      new Set(
        values.bccEmails
          .split(',')
          .map((email) => email.trim())
          .filter((email) => !!email),
      ),
    ),
  }
}

interface UseCreateEditDunningCampaignReturn {
  loading: boolean
  errorCode?: string
  isEdition: boolean
  hasPaymentProviderExcludingGoCardless: boolean
  campaign?: DunningCampaignFormFragment
  onSave: (value: DunningCampaignFormInput) => Promise<void>
  onClose: () => void
}

export const useCreateEditDunningCampaign = (): UseCreateEditDunningCampaignReturn => {
  const navigate = useNavigate()
  const { campaignId } = useParams<string>()

  const { data, loading, error } = useGetSingleCampaignQuery({
    variables: {
      id: campaignId as string,
    },
    skip: !campaignId,
  })

  const { data: paymentProviderData, loading: loadingPaymentProvider } =
    useCreateDunningCampaignPaymentProviderQuery()

  const [create, { error: createError }] = useCreateDunningCampaignMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ createDunningCampaign }) {
      if (!!createDunningCampaign) {
        addToast({
          severity: 'success',
          translateKey: 'text_17290016117598ws4m1j6wvy',
        })
      }
      navigate(DUNNINGS_SETTINGS_ROUTE)
    },
  })

  const [update, { error: updateError }] = useUpdateDunningCampaignMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ updateDunningCampaign }) {
      if (!!updateDunningCampaign) {
        addToast({
          severity: 'success',
          translateKey: 'text_1732187313660tetkzao72e1',
        })
      }
      navigate(DUNNINGS_SETTINGS_ROUTE)
    },
  })

  useEffect(() => {
    if (hasDefinedGQLError('NotFound', error, 'dunningCampaign')) {
      navigate(ERROR_404_ROUTE)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  const errorCode = useMemo(() => {
    if (hasDefinedGQLError('ValueAlreadyExist', createError || updateError)) {
      return FORM_ERRORS_ENUM.existingCode
    }

    return undefined
  }, [createError, updateError])

  const hasPaymentProviderExcludingGoCardless =
    !!paymentProviderData?.paymentProviders?.collection.filter(
      (provider) => provider.__typename !== 'GocardlessProvider',
    ).length

  return useMemo(
    () => ({
      loading: loading || loadingPaymentProvider,
      errorCode,
      isEdition: !!campaignId,
      campaign: data?.dunningCampaign || undefined,
      hasPaymentProviderExcludingGoCardless,
      onClose: () => {
        navigate(DUNNINGS_SETTINGS_ROUTE)
      },
      onSave: !!campaignId
        ? async (values) => {
            await update({
              variables: {
                input: {
                  id: campaignId,
                  ...formatPayload(values),
                },
              },
            })
          }
        : async (values) => {
            await create({
              variables: {
                input: { ...formatPayload(values) },
              },
            })
          },
    }),
    [
      loading,
      loadingPaymentProvider,
      errorCode,
      campaignId,
      data?.dunningCampaign,
      hasPaymentProviderExcludingGoCardless,
      navigate,
      update,
      create,
    ],
  )
}
