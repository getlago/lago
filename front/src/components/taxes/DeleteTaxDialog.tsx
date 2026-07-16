import { gql, useApolloClient } from '@apollo/client'
import { ReactNode } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteTaxFragment,
  GetTaxesSettingsInformationsDocument,
  useDeleteTaxMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteTax on Tax {
    id
    name
    customersCount
  }

  mutation deleteTax($input: DestroyTaxInput!) {
    destroyTax(input: $input) {
      id
    }
  }
`

export const useDeleteTaxDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteTax] = useDeleteTaxMutation()

  const getDescription = (customersCount: number): ReactNode => {
    let copy = translate('text_645cb766cca2dd00e2956271')

    if (customersCount) {
      copy = translate('text_645bb193927b375079d28b0c', { count: customersCount }, customersCount)
    }

    return <Typography>{copy}</Typography>
  }

  const openDeleteTaxDialog = (tax: DeleteTaxFragment) => {
    centralizedDialog.open({
      title: translate('text_645bb193927b375079d28af7', {
        name: tax.name,
      }),
      description: getDescription(tax.customersCount),
      colorVariant: 'danger',
      actionText: translate('text_645bb193927b375079d28b34'),
      onAction: async () => {
        const result = await deleteTax({
          variables: { input: { id: tax.id } },
        })

        const destroyedId = result.data?.destroyTax?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'Tax',
            listFieldName: 'taxes',
            listQueryDocument: GetTaxesSettingsInformationsDocument,
          })

          addToast({
            message: translate('text_645bb193927b375079d28b5a'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteTaxDialog }
}
