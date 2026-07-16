import { gql } from '@apollo/client'

gql`
  fragment AnrokIntegrationMapItemDrawer on IntegrationItem {
    id
    externalId
    externalName
    externalAccountCode
    itemType
  }

  fragment AnrokIntegrationMapItemDrawerCollectionMappingItem on CollectionMapping {
    id
    externalId
    externalName
    externalAccountCode
  }

  fragment AnrokIntegrationMapItemDrawerCollectionItem on Mapping {
    id
    externalId
    externalName
    externalAccountCode
  }

  # Mapping Creation
  mutation createAnrokIntegrationCollectionMapping(
    $input: CreateIntegrationCollectionMappingInput!
  ) {
    createIntegrationCollectionMapping(input: $input) {
      id
      ...AnrokIntegrationMapItemDrawerCollectionMappingItem
    }
  }

  mutation createAnrokIntegrationMapping($input: CreateIntegrationMappingInput!) {
    createIntegrationMapping(input: $input) {
      id
      ...AnrokIntegrationMapItemDrawerCollectionItem
    }
  }

  # Mapping edition
  mutation updateAnrokIntegrationCollectionMapping(
    $input: UpdateIntegrationCollectionMappingInput!
  ) {
    updateIntegrationCollectionMapping(input: $input) {
      id
    }
  }

  mutation updateAnrokIntegrationMapping($input: UpdateIntegrationMappingInput!) {
    updateIntegrationMapping(input: $input) {
      id
    }
  }

  # Mapping deletion
  mutation deleteAnrokIntegrationCollectionMapping(
    $input: DestroyIntegrationCollectionMappingInput!
  ) {
    destroyIntegrationCollectionMapping(input: $input) {
      id
    }
  }

  mutation deleteAnrokIntegrationMapping($input: DestroyIntegrationMappingInput!) {
    destroyIntegrationMapping(input: $input) {
      id
    }
  }
`
