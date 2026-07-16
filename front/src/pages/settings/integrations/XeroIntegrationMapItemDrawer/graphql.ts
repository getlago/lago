import { gql } from '@apollo/client'

gql`
  fragment XeroIntegrationMapItemDrawer on IntegrationItem {
    id
    externalId
    externalName
    externalAccountCode
    itemType
  }

  fragment XeroIntegrationMapItemDrawerCollectionMappingItem on CollectionMapping {
    id
    externalId
    externalName
    externalAccountCode
  }

  fragment XeroIntegrationMapItemDrawerCollectionItem on Mapping {
    id
    externalId
    externalName
    externalAccountCode
  }

  # Item fetch
  query getXeroIntegrationItems(
    $integrationId: ID!
    $itemType: IntegrationItemTypeEnum
    $page: Int
    $limit: Int
    $searchTerm: String
  ) {
    integrationItems(
      integrationId: $integrationId
      itemType: $itemType
      page: $page
      limit: $limit
      searchTerm: $searchTerm
    ) {
      collection {
        ...XeroIntegrationMapItemDrawer
      }
      metadata {
        currentPage
        totalPages
        totalCount
      }
    }
  }

  mutation triggerXeroIntegrationAccountsRefetch($input: FetchIntegrationAccountsInput!) {
    fetchIntegrationAccounts(input: $input) {
      collection {
        ...XeroIntegrationMapItemDrawer
      }
    }
  }

  mutation triggerXeroIntegrationItemsRefetch($input: FetchIntegrationItemsInput!) {
    fetchIntegrationItems(input: $input) {
      collection {
        ...XeroIntegrationMapItemDrawer
      }
    }
  }

  # Mapping Creation
  mutation createXeroIntegrationCollectionMapping(
    $input: CreateIntegrationCollectionMappingInput!
  ) {
    createIntegrationCollectionMapping(input: $input) {
      id
      ...XeroIntegrationMapItemDrawerCollectionMappingItem
    }
  }

  mutation createXeroIntegrationMapping($input: CreateIntegrationMappingInput!) {
    createIntegrationMapping(input: $input) {
      id
      ...XeroIntegrationMapItemDrawerCollectionItem
    }
  }

  # Mapping edition
  mutation updateXeroIntegrationCollectionMapping(
    $input: UpdateIntegrationCollectionMappingInput!
  ) {
    updateIntegrationCollectionMapping(input: $input) {
      id
    }
  }

  mutation updateXeroIntegrationMapping($input: UpdateIntegrationMappingInput!) {
    updateIntegrationMapping(input: $input) {
      id
    }
  }

  # Mapping deletion
  mutation deleteXeroIntegrationCollectionMapping(
    $input: DestroyIntegrationCollectionMappingInput!
  ) {
    destroyIntegrationCollectionMapping(input: $input) {
      id
    }
  }

  mutation deleteXeroIntegrationMapping($input: DestroyIntegrationMappingInput!) {
    destroyIntegrationMapping(input: $input) {
      id
    }
  }
`
