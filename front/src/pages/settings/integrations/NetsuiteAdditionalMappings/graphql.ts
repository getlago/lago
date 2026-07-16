import { gql } from '@apollo/client'

gql`
  fragment NetsuiteIntegrationAdditionalItemsList on CollectionMapping {
    id
    mappingType
    currencies {
      currencyCode
      currencyExternalCode
    }
  }

  query getNetsuiteIntegrationCollectionCurrenciesMappings($integrationId: ID!) {
    integrationCollectionMappings(integrationId: $integrationId) {
      collection {
        id
        ...NetsuiteIntegrationAdditionalItemsList
      }
    }
  }

  # Mapping Creation
  mutation createNetsuiteIntegrationCurrenciesMapping(
    $input: CreateIntegrationCollectionMappingInput!
  ) {
    createIntegrationCollectionMapping(input: $input) {
      id
      ...NetsuiteIntegrationAdditionalItemsList
    }
  }

  # Mapping edition
  mutation updateNetsuiteIntegrationCurrenciesMapping(
    $input: UpdateIntegrationCollectionMappingInput!
  ) {
    updateIntegrationCollectionMapping(input: $input) {
      id
    }
  }

  # Mapping deletion
  mutation deleteNetsuiteIntegrationCurrenciesMapping(
    $input: DestroyIntegrationCollectionMappingInput!
  ) {
    destroyIntegrationCollectionMapping(input: $input) {
      id
    }
  }
`
