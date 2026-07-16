import { gql } from '@apollo/client'

import { addToast } from '~/core/apolloClient'
import {
  BillingEntity,
  BillingEntityEmailSettingsEnum,
  useUpdateBillingEntityEmailSettingMutation,
} from '~/generated/graphql'

gql`
  mutation updateBillingEntityEmailSetting($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      emailSettings
    }
  }
`

type UseEmailConfigReturn = {
  loading: boolean
  emailSettings?: BillingEntityEmailSettingsEnum[] | null
  updateEmailSettings: (
    type: BillingEntityEmailSettingsEnum,
    value: boolean,
  ) => Promise<unknown> | void
}

type UseEmailConfigProps = {
  billingEntity: BillingEntity
}

export const useEmailConfig = ({ billingEntity }: UseEmailConfigProps): UseEmailConfigReturn => {
  const emailSettings = billingEntity?.emailSettings

  const [updateSetting] = useUpdateBillingEntityEmailSettingMutation({
    refetchQueries: ['getBillingEntity'],
  })

  const updateEmailSettings = async (type: BillingEntityEmailSettingsEnum, value: boolean) => {
    const existingSettings = emailSettings || []

    let newSetting: BillingEntityEmailSettingsEnum[] = []

    if (value) {
      newSetting = [...existingSettings, type]
    } else {
      newSetting = existingSettings.filter((setting) => setting !== type)
    }

    const res = await updateSetting({
      variables: {
        input: {
          id: billingEntity.id,
          emailSettings: newSetting,
        },
      },
    })

    if (!!res?.errors) return

    if ((res?.data?.updateBillingEntity?.emailSettings || [])?.includes(type)) {
      addToast({
        severity: 'success',
        translateKey: 'text_6407684eaf41130074c4b2b1',
      })
    } else {
      addToast({
        severity: 'success',
        translateKey: 'text_6407684eaf41130074c4b2b0',
      })
    }
  }

  return {
    loading: false,
    emailSettings,
    updateEmailSettings,
  }
}
