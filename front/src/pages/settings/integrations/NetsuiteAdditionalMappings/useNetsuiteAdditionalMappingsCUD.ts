import { addToast } from '~/core/apolloClient'
import {
  useCreateNetsuiteIntegrationCurrenciesMappingMutation,
  useDeleteNetsuiteIntegrationCurrenciesMappingMutation,
  useUpdateNetsuiteIntegrationCurrenciesMappingMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const useNetsuiteAdditionalMappingsCUD = () => {
  const { translate } = useInternationalization()

  const refetchQueries = ['getNetsuiteIntegrationCollectionCurrenciesMappings']

  // Mapping Creation
  const [createCollectionMapping] = useCreateNetsuiteIntegrationCurrenciesMappingMutation({
    onCompleted(data) {
      if (data && data.createIntegrationCollectionMapping?.id) {
        addToast({
          message: translate('text_6630e5923500e7015f190643'),
          severity: 'success',
        })
      }
    },
    refetchQueries,
  })

  // Mapping edition
  const [updateCollectionMapping] = useUpdateNetsuiteIntegrationCurrenciesMappingMutation({
    onCompleted(data) {
      if (data && data.updateIntegrationCollectionMapping?.id) {
        addToast({
          message: translate('text_6630e5923500e7015f190641'),
          severity: 'success',
        })
      }
    },
    refetchQueries,
  })

  // Mapping deletion
  const [deleteCollectionMapping] = useDeleteNetsuiteIntegrationCurrenciesMappingMutation({
    onCompleted(data) {
      if (data && data.destroyIntegrationCollectionMapping?.id) {
        addToast({
          message: translate('text_6630e5923500e7015f19063e'),
          severity: 'success',
        })
      }
    },
    refetchQueries,
  })

  return {
    createCollectionMapping,
    updateCollectionMapping,
    deleteCollectionMapping,
  }
}
