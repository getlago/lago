import {
  MappableTypeEnum,
  MappingTypeEnum,
  useCreateNetsuiteIntegrationCollectionMappingMutation,
  useCreateNetsuiteIntegrationMappingMutation,
  useDeleteNetsuiteIntegrationCollectionMappingMutation,
  useDeleteNetsuiteIntegrationMappingMutation,
  useUpdateNetsuiteIntegrationCollectionMappingMutation,
  useUpdateNetsuiteIntegrationMappingMutation,
} from '~/generated/graphql'

export const useNetsuiteIntegrationMappingCUD = (
  formType: MappableTypeEnum | MappingTypeEnum | undefined,
) => {
  const getRefetchQueries = () => {
    if (formType === MappableTypeEnum.AddOn) return ['getAddOnsForNetsuiteItemsList']

    if (formType === MappableTypeEnum.BillableMetric) {
      return ['getBillableMetricsForNetsuiteItemsList']
    }

    return ['getNetsuiteIntegrationCollectionMappings']
  }

  // Mapping Creation
  const [createCollectionMapping] = useCreateNetsuiteIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [createMapping] = useCreateNetsuiteIntegrationMappingMutation({
    refetchQueries: getRefetchQueries(),
  })

  // Mapping edition
  const [updateCollectionMapping] = useUpdateNetsuiteIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [updateMapping] = useUpdateNetsuiteIntegrationMappingMutation({
    refetchQueries: getRefetchQueries(),
  })

  // Mapping deletion
  const [deleteCollectionMapping] = useDeleteNetsuiteIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [deleteMapping] = useDeleteNetsuiteIntegrationMappingMutation({
    refetchQueries: getRefetchQueries(),
  })

  return {
    createCollectionMapping,
    createMapping,
    deleteCollectionMapping,
    deleteMapping,
    updateCollectionMapping,
    updateMapping,
  }
}
