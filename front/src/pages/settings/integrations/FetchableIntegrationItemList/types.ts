import {
  InputMaybe,
  MappableTypeEnum,
  useGetAddOnsForAnrokItemsListLazyQuery,
  useGetAddOnsForAvalaraItemsListLazyQuery,
  useGetAddOnsForNetsuiteItemsListLazyQuery,
  useGetAddOnsForXeroItemsListLazyQuery,
  useGetBillableMetricsForAnrokItemsListLazyQuery,
  useGetBillableMetricsForAvalaraItemsListLazyQuery,
  useGetBillableMetricsForNetsuiteItemsListLazyQuery,
  useGetBillableMetricsForXeroItemsListLazyQuery,
} from '~/generated/graphql'
import {
  FetchableIntegrationItemsListData,
  MappableIntegrationMapItemDrawerRef,
  MappableIntegrationProvider,
} from '~/pages/settings/integrations/common'

export type FetchMoreFunction = ReturnType<
  | typeof useGetAddOnsForNetsuiteItemsListLazyQuery
  | typeof useGetBillableMetricsForNetsuiteItemsListLazyQuery
  | typeof useGetAddOnsForAnrokItemsListLazyQuery
  | typeof useGetBillableMetricsForAnrokItemsListLazyQuery
  | typeof useGetAddOnsForAvalaraItemsListLazyQuery
  | typeof useGetBillableMetricsForAvalaraItemsListLazyQuery
  | typeof useGetAddOnsForXeroItemsListLazyQuery
  | typeof useGetBillableMetricsForXeroItemsListLazyQuery
>[1]['fetchMore']

export type FetchIntegrationItemsListProps = {
  integrationId: string
  data: FetchableIntegrationItemsListData
  fetchMore: FetchMoreFunction
  hasError: boolean
  searchTerm: InputMaybe<string> | undefined
  isLoading: boolean
  integrationMapItemDrawerRef: MappableIntegrationMapItemDrawerRef
  createRoute: string
  mappableType: MappableTypeEnum
  provider: MappableIntegrationProvider
  firstColumnName?: string
}

export type FetchableIntegrationItemErrorProps = {
  hasSearchTerm: boolean
}

export type FetchableIntegrationItemEmptyProps = {
  hasSearchTerm: boolean
  type: MappableTypeEnum
  createRoute: string
}
