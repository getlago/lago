import { gql } from '@apollo/client'

gql`
  fragment AvalaraIntegrationMapItemDrawer on IntegrationItem {
    id
    externalId
    externalName
    externalAccountCode
    itemType
  }

  fragment AvalaraIntegrationMapItemDrawerCollectionMappingItem on CollectionMapping {
    id
    externalId
    externalName
    externalAccountCode
  }

  fragment AvalaraIntegrationMapItemDrawerCollectionItem on Mapping {
    id
    externalId
    externalName
    externalAccountCode
  }

  # Mapping Creation
  mutation createAvalaraIntegrationCollectionMapping(
    $input: CreateIntegrationCollectionMappingInput!
  ) {
    createIntegrationCollectionMapping(input: $input) {
      id
      ...AvalaraIntegrationMapItemDrawerCollectionMappingItem
    }
  }

  mutation createAvalaraIntegrationMapping($input: CreateIntegrationMappingInput!) {
    createIntegrationMapping(input: $input) {
      id
      ...AvalaraIntegrationMapItemDrawerCollectionItem
    }
  }

  # Mapping edition
  mutation updateAvalaraIntegrationCollectionMapping(
    $input: UpdateIntegrationCollectionMappingInput!
  ) {
    updateIntegrationCollectionMapping(input: $input) {
      id
    }
  }

  mutation updateAvalaraIntegrationMapping($input: UpdateIntegrationMappingInput!) {
    updateIntegrationMapping(input: $input) {
      id
    }
  }

  # Mapping deletion
  mutation deleteAvalaraIntegrationCollectionMapping(
    $input: DestroyIntegrationCollectionMappingInput!
  ) {
    destroyIntegrationCollectionMapping(input: $input) {
      id
    }
  }

  mutation deleteAvalaraIntegrationMapping($input: DestroyIntegrationMappingInput!) {
    destroyIntegrationMapping(input: $input) {
      id
    }
  }
`
