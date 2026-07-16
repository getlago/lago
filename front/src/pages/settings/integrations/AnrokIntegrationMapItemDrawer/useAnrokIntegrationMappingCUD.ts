import {
  MappableTypeEnum,
  MappingTypeEnum,
  useCreateAnrokIntegrationCollectionMappingMutation,
  useCreateAnrokIntegrationMappingMutation,
  useDeleteAnrokIntegrationCollectionMappingMutation,
  useDeleteAnrokIntegrationMappingMutation,
  useUpdateAnrokIntegrationCollectionMappingMutation,
  useUpdateAnrokIntegrationMappingMutation,
} from '~/generated/graphql'

export const useAnrokIntegrationMappingCUD = (
  formType: MappableTypeEnum | MappingTypeEnum | undefined,
) => {
  const getRefetchQueries = () => {
    if (formType === MappableTypeEnum.AddOn) return ['getAddOnsForAnrokItemsList']

    if (formType === MappableTypeEnum.BillableMetric) {
      return ['getBillableMetricsForAnrokItemsList']
    }

    return ['getAnrokIntegrationCollectionMappings']
  }

  // Mapping Creation
  const [createCollectionMapping] = useCreateAnrokIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [createMapping] = useCreateAnrokIntegrationMappingMutation({
    refetchQueries: getRefetchQueries(),
  })

  // Mapping edition
  const [updateCollectionMapping] = useUpdateAnrokIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [updateMapping] = useUpdateAnrokIntegrationMappingMutation({
    refetchQueries: getRefetchQueries(),
  })

  // Mapping deletion
  const [deleteCollectionMapping] = useDeleteAnrokIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [deleteMapping] = useDeleteAnrokIntegrationMappingMutation({
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
