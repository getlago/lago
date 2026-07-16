import { GraphQLFormattedError } from 'graphql'
import { RefObject } from 'react'

import { PickEnum } from '~/core/types/pickEnum.type'
import {
  AnrokIntegrationItemsListDefaultFragment,
  AvalaraIntegrationItemsListDefaultFragment,
  CurrencyMappingItem,
  GetAddOnsForAnrokItemsListQuery,
  GetAddOnsForAvalaraItemsListQuery,
  GetAddOnsForNetsuiteItemsListQuery,
  GetAddOnsForXeroItemsListQuery,
  GetBillableMetricsForAnrokItemsListQuery,
  GetBillableMetricsForAvalaraItemsListQuery,
  GetBillableMetricsForNetsuiteItemsListQuery,
  GetBillableMetricsForXeroItemsListQuery,
  IntegrationTypeEnum,
  NetsuiteIntegrationAdditionalItemsListFragment,
  NetsuiteIntegrationItemsListDefaultFragment,
  useCreateAnrokIntegrationCollectionMappingMutation,
  useCreateAnrokIntegrationMappingMutation,
  useCreateAvalaraIntegrationCollectionMappingMutation,
  useCreateAvalaraIntegrationMappingMutation,
  useCreateNetsuiteIntegrationCollectionMappingMutation,
  useCreateNetsuiteIntegrationMappingMutation,
  useCreateXeroIntegrationCollectionMappingMutation,
  useCreateXeroIntegrationMappingMutation,
  useDeleteAnrokIntegrationCollectionMappingMutation,
  useDeleteAnrokIntegrationMappingMutation,
  useDeleteAvalaraIntegrationCollectionMappingMutation,
  useDeleteAvalaraIntegrationMappingMutation,
  useDeleteNetsuiteIntegrationCollectionMappingMutation,
  useDeleteNetsuiteIntegrationMappingMutation,
  useDeleteXeroIntegrationCollectionMappingMutation,
  useDeleteXeroIntegrationMappingMutation,
  useUpdateAnrokIntegrationCollectionMappingMutation,
  useUpdateAnrokIntegrationMappingMutation,
  useUpdateAvalaraIntegrationCollectionMappingMutation,
  useUpdateAvalaraIntegrationMappingMutation,
  useUpdateNetsuiteIntegrationCollectionMappingMutation,
  useUpdateNetsuiteIntegrationMappingMutation,
  useUpdateXeroIntegrationCollectionMappingMutation,
  useUpdateXeroIntegrationMappingMutation,
  XeroIntegrationItemsListDefaultFragment,
} from '~/generated/graphql'
import { AnrokIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/AnrokIntegrationMapItemDrawer'
import { AvalaraIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/AvalaraIntegrationMapItemDrawer'
import { NetsuiteAdditionalMappingDrawerRef } from '~/pages/settings/integrations/NetsuiteAdditionalMappings/types'
import { NetsuiteIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/NetsuiteIntegrationMapItemDrawer'
import { XeroIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/XeroIntegrationMapItemDrawer'

export type FetchableIntegrationItemsListData =
  | GetAddOnsForNetsuiteItemsListQuery['addOns']
  | GetBillableMetricsForNetsuiteItemsListQuery['billableMetrics']
  | GetAddOnsForAnrokItemsListQuery['addOns']
  | GetBillableMetricsForAnrokItemsListQuery['billableMetrics']
  | GetAddOnsForAvalaraItemsListQuery['addOns']
  | GetBillableMetricsForAvalaraItemsListQuery['billableMetrics']
  | GetAddOnsForXeroItemsListQuery['addOns']
  | GetBillableMetricsForXeroItemsListQuery['billableMetrics']
  | undefined

export type MappableIntegrationProvider = PickEnum<
  IntegrationTypeEnum,
  | IntegrationTypeEnum.Anrok
  | IntegrationTypeEnum.Avalara
  | IntegrationTypeEnum.Netsuite
  | IntegrationTypeEnum.Xero
>

export type ItemMapping =
  | NonNullable<
      NonNullable<FetchableIntegrationItemsListData>['collection'][0]['integrationMappings']
    >[0]
  | AnrokIntegrationItemsListDefaultFragment
  | NetsuiteIntegrationItemsListDefaultFragment
  | AvalaraIntegrationItemsListDefaultFragment
  | XeroIntegrationItemsListDefaultFragment
  | NetsuiteIntegrationAdditionalItemsListFragment

export type MappableIntegrationMapItemDrawerRef = RefObject<
  | NetsuiteIntegrationMapItemDrawerRef
  | AnrokIntegrationMapItemDrawerRef
  | AvalaraIntegrationMapItemDrawerRef
  | XeroIntegrationMapItemDrawerRef
  | NetsuiteAdditionalMappingDrawerRef
>

export type BillingEntityForIntegrationMapping = {
  id: string | null
  key: string
  name: string
}

export type ItemMappingForTaxMapping = {
  itemId: string | null
  itemExternalId: string | null
  itemExternalName?: string
  itemExternalCode?: string
  taxCode: string | null
  taxNexus: string | null
  taxType: string | null
}

export type ItemMappingForNonTaxMapping = {
  itemId: string | null
  itemExternalId: string | null
  itemExternalName?: string
  itemExternalCode?: string
}

export type ItemMappingForMappable = {
  itemId: string | null
  itemExternalId: string | null
  itemExternalName?: string
  itemExternalCode?: string
  lagoMappableId: string
  lagoMappableName: string
}

export type ItemMappingForCurrenciesMapping = {
  itemId: string | null
  currencies: Array<CurrencyMappingItem>
}

export type ItemMappingPerBillingEntity = Record<
  'default' | string,
  | ItemMappingForTaxMapping
  | ItemMappingForNonTaxMapping
  | ItemMappingForMappable
  | ItemMappingForCurrenciesMapping
>

export type CreateUpdateDeleteSuccessAnswer =
  | { success: true }
  | { success: false; errors: readonly GraphQLFormattedError[] }
  | { success: false; reasons: readonly string[] }

export type CreateUpdateDeleteFunctions = {
  createCollectionMapping:
    | ReturnType<typeof useCreateAnrokIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useCreateAvalaraIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useCreateNetsuiteIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useCreateXeroIntegrationCollectionMappingMutation>[0]
  createMapping:
    | ReturnType<typeof useCreateAnrokIntegrationMappingMutation>[0]
    | ReturnType<typeof useCreateAvalaraIntegrationMappingMutation>[0]
    | ReturnType<typeof useCreateNetsuiteIntegrationMappingMutation>[0]
    | ReturnType<typeof useCreateXeroIntegrationMappingMutation>[0]
  deleteCollectionMapping:
    | ReturnType<typeof useDeleteAnrokIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useDeleteAvalaraIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useDeleteNetsuiteIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useDeleteXeroIntegrationCollectionMappingMutation>[0]
  deleteMapping:
    | ReturnType<typeof useDeleteAnrokIntegrationMappingMutation>[0]
    | ReturnType<typeof useDeleteAvalaraIntegrationMappingMutation>[0]
    | ReturnType<typeof useDeleteNetsuiteIntegrationMappingMutation>[0]
    | ReturnType<typeof useDeleteXeroIntegrationMappingMutation>[0]
  updateCollectionMapping:
    | ReturnType<typeof useUpdateAnrokIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useUpdateAvalaraIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useUpdateNetsuiteIntegrationCollectionMappingMutation>[0]
    | ReturnType<typeof useUpdateXeroIntegrationCollectionMappingMutation>[0]
  updateMapping:
    | ReturnType<typeof useUpdateAnrokIntegrationMappingMutation>[0]
    | ReturnType<typeof useUpdateAvalaraIntegrationMappingMutation>[0]
    | ReturnType<typeof useUpdateNetsuiteIntegrationMappingMutation>[0]
    | ReturnType<typeof useUpdateXeroIntegrationMappingMutation>[0]
}

export type AvalaraAndAnrokParameters = {
  externalId: string | undefined
  externalName: string | undefined
}

export type NetsuiteParameters = {
  externalId: string | undefined
  externalName: string | undefined
  externalAccountCode: string | undefined
  taxCode: string | undefined
  taxNexus: string | undefined
  taxType: string | undefined
}

export type XeroParameters = {
  externalId: string | undefined
  externalName: string | undefined
  externalAccountCode: string | undefined
}
