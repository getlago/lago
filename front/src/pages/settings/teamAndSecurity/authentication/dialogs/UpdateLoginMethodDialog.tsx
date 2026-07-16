import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { authenticationMethodsMapping } from '~/core/constants/authenticationMethodsMapping'
import {
  AuthenticationMethodsEnum,
  useUpdateOrganizationAuthenticationMethodsMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  mutation updateOrganizationAuthenticationMethods($input: UpdateOrganizationInput!) {
    updateOrganization(input: $input) {
      id
      authenticationMethods
    }
  }
`

type UpdateLoginMethodDialogData = {
  method: AuthenticationMethodsEnum
  type: 'enable' | 'disable'
}

export const useUpdateLoginMethodDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const { organization, refetchOrganizationInfos } = useOrganizationInfos()

  const [updateOrganizationAuthenticationMethods] =
    useUpdateOrganizationAuthenticationMethodsMutation()

  const openUpdateLoginMethodDialog = (data: UpdateLoginMethodDialogData) => {
    const isDanger = data.type === 'disable'
    const methodLabel = translate(authenticationMethodsMapping[data.method])

    const getNewAuthMethods = () => {
      if (data.type === 'disable') {
        return organization?.authenticationMethods?.filter((method) => method !== data.method) || []
      }

      if (data.type === 'enable') {
        return [...(organization?.authenticationMethods || []), data.method]
      }

      return []
    }

    centralizedDialog.open({
      title: translate(
        isDanger ? 'text_1752157864305cyuembvqwls' : 'text_1752157864305roig666alyw',
        { method: methodLabel },
      ),
      description: translate(
        isDanger ? 'text_1752157864305wmeiff8xkih' : 'text_1752157864305uw22hplchmu',
        { method: methodLabel },
      ),
      colorVariant: isDanger ? 'danger' : 'info',
      actionText: translate(
        isDanger ? 'text_1752158016616mbk432yu9oz' : 'text_17521580166150wyrhvd2u56',
      ),
      onAction: async () => {
        const result = await updateOrganizationAuthenticationMethods({
          variables: {
            input: {
              authenticationMethods: getNewAuthMethods(),
            },
          },
        })

        if (result.data?.updateOrganization) {
          const isEnabled = result.data.updateOrganization.authenticationMethods?.includes(
            data.method,
          )

          addToast({
            message: translate(
              isEnabled ? 'text_1752158380555fssagh1zpp1' : 'text_1752158380555al7jwgd0hfk',
              { method: methodLabel },
            ),
            severity: 'success',
          })

          refetchOrganizationInfos()
        }
      },
    })
  }

  return { openUpdateLoginMethodDialog }
}
