import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  DeleteOktaIntegrationDialogFragment,
  useDestroyIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteOktaIntegrationDialog on OktaIntegration {
    id
    name
  }

  mutation DestroyIntegration($input: DestroyIntegrationInput!) {
    destroyIntegration(input: $input) {
      id
    }
  }
`

type DeleteOktaIntegrationDialogData = {
  integration: DeleteOktaIntegrationDialogFragment | undefined
  callback?: () => void
}

export const useDeleteOktaIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [deleteIntegration] = useDestroyIntegrationMutation()

  const openDeleteOktaIntegrationDialog = (data: DeleteOktaIntegrationDialogData) => {
    centralizedDialog.open({
      title: translate('text_664c900d2d312a01546bd84b'),
      description: translate('text_664c900d2d312a01546bd84c'),
      colorVariant: 'danger',
      actionText: translate('text_645d071272418a14c1c76a81'),
      onAction: async () => {
        const result = await deleteIntegration({
          variables: {
            input: {
              id: data.integration?.id ?? '',
            },
          },
          update(cache) {
            cache.evict({ id: `OktaIntegration:${data.integration?.id}` })
          },
        })

        if (result.data?.destroyIntegration) {
          data.callback?.()

          addToast({
            message: translate('text_664c732c264d7eed1c74fdb4', {
              integration: translate('text_664c732c264d7eed1c74fda2'),
            }),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteOktaIntegrationDialog }
}
