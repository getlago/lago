import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  FeatureForDeleteFeatureDialogFragment,
  GetFeaturesListDocument,
  useDestroyFeatureMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment FeatureForDeleteFeatureDialog on FeatureObject {
    id
  }

  mutation destroyFeature($input: DestroyFeatureInput!) {
    destroyFeature(input: $input) {
      id
    }
  }
`

type TDeleteFeatureDialogProps = {
  feature: FeatureForDeleteFeatureDialogFragment | undefined
  callback?: () => void
}

export const useDeleteFeatureDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [destroyFeature] = useDestroyFeatureMutation()

  const openDeleteFeatureDialog = ({ feature, callback }: TDeleteFeatureDialogProps) => {
    centralizedDialog.open({
      title: translate('text_1752692673070h6yiax84d7x'),
      description: translate('text_1752693359315c6eoxf5szyk'),
      colorVariant: 'danger',
      actionText: translate('text_1752693359315sd2ms0qxvi3'),
      onAction: async () => {
        const result = await destroyFeature({
          variables: {
            input: {
              id: feature?.id || '',
            },
          },
        })

        const destroyedId = result.data?.destroyFeature?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'FeatureObject',
            listFieldName: 'features',
            listQueryDocument: GetFeaturesListDocument,
          })

          callback?.()

          addToast({
            message: translate('text_1752692673070wmlmc9i3rjz'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteFeatureDialog }
}
