import {
  MappableTypeEnum,
  MappingTypeEnum,
  useCreateAvalaraIntegrationCollectionMappingMutation,
  useCreateAvalaraIntegrationMappingMutation,
  useDeleteAvalaraIntegrationCollectionMappingMutation,
  useDeleteAvalaraIntegrationMappingMutation,
  useUpdateAvalaraIntegrationCollectionMappingMutation,
  useUpdateAvalaraIntegrationMappingMutation,
} from '~/generated/graphql'

export const useAvalaraIntegrationMappingCUD = (
  formType: MappableTypeEnum | MappingTypeEnum | undefined,
) => {
  const getRefetchQueries = () => {
    if (formType === MappableTypeEnum.AddOn) {
      return ['getAddOnsForAvalaraItemsList']
    }

    if (formType === MappableTypeEnum.BillableMetric) {
      return ['getBillableMetricsForAvalaraItemsList']
    }

    return ['getAvalaraIntegrationCollectionMappings']
  }

  // Mapping Creation
  const [createCollectionMapping] = useCreateAvalaraIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [createMapping] = useCreateAvalaraIntegrationMappingMutation({
    refetchQueries: getRefetchQueries(),
  })

  // Mapping edition
  const [updateCollectionMapping] = useUpdateAvalaraIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [updateMapping] = useUpdateAvalaraIntegrationMappingMutation({
    refetchQueries: getRefetchQueries(),
  })

  // Mapping deletion
  const [deleteCollectionMapping] = useDeleteAvalaraIntegrationCollectionMappingMutation({
    refetchQueries: getRefetchQueries(),
  })
  const [deleteMapping] = useDeleteAvalaraIntegrationMappingMutation({
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
