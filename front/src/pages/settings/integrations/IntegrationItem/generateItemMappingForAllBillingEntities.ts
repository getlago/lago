import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import {
  type BillingEntityForIntegrationMapping,
  DEFAULT_MAPPING_KEY,
  type ItemMappingForMappable,
  type ItemMappingForNonTaxMapping,
  type ItemMappingForTaxMapping,
  type ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common'
import { ItemMappingForCurrenciesMapping } from '~/pages/settings/integrations/common/types'
import type { IntegrationItemData } from '~/pages/settings/integrations/IntegrationItem'

import { findItemMapping } from './findItemMapping'
import { isNetsuiteIntegrationAdditionalItemsListFragment } from './isNetsuiteIntegrationAdditionalItemsListFragment'

export const generateItemMappingForAllBillingEntities = (
  item: IntegrationItemData,
  billingEntities: Array<BillingEntityForIntegrationMapping>,
): ItemMappingPerBillingEntity => {
  return billingEntities.reduce((acc, billingEntity) => {
    const billingEntityId = billingEntity.id || DEFAULT_MAPPING_KEY

    const itemMapping = findItemMapping(item, billingEntity.id)

    if (!itemMapping && item.mappingType === MappingTypeEnum.Currencies) {
      const itemToAdd: ItemMappingForCurrenciesMapping = {
        itemId: null,
        currencies: [],
      }

      acc[billingEntityId] = itemToAdd
      return acc
    }

    if (!itemMapping && item.mappingType === MappingTypeEnum.Tax) {
      const itemToAdd: ItemMappingForTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
        taxCode: null,
        taxNexus: null,
        taxType: null,
      }

      acc[billingEntityId] = itemToAdd
      return acc
    }

    if (
      !itemMapping &&
      Object.values(MappableTypeEnum).includes(item.mappingType as MappableTypeEnum)
    ) {
      const itemToAdd: ItemMappingForMappable = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
        lagoMappableId: item.id,
        lagoMappableName: item.label,
      }

      acc[billingEntityId] = itemToAdd
      return acc
    }

    if (!itemMapping) {
      const itemToAdd: ItemMappingForNonTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
      }

      acc[billingEntityId] = itemToAdd
      return acc
    }

    if (isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)) {
      const itemToAdd: ItemMappingForCurrenciesMapping = {
        itemId: itemMapping.id,
        currencies: itemMapping.currencies || [],
      }

      acc[billingEntityId] = itemToAdd
      return acc
    }

    if (item.mappingType === MappingTypeEnum.Tax && itemMapping && 'taxCode' in itemMapping) {
      const itemToAdd: ItemMappingForTaxMapping = {
        itemId: itemMapping.id,
        itemExternalId: itemMapping.externalId || null,
        itemExternalName: itemMapping.externalName || undefined,
        itemExternalCode: itemMapping.externalAccountCode || undefined,
        taxCode: itemMapping.taxCode || null,
        taxNexus: itemMapping.taxNexus || null,
        taxType: itemMapping.taxType || null,
      }

      acc[billingEntityId] = itemToAdd
      return acc
    }

    if (Object.values(MappableTypeEnum).includes(item.mappingType as MappableTypeEnum)) {
      const itemToAdd: ItemMappingForMappable = {
        itemId: itemMapping.id,
        itemExternalId: itemMapping.externalId || null,
        itemExternalName: itemMapping.externalName || undefined,
        itemExternalCode: itemMapping.externalAccountCode || undefined,
        lagoMappableId: item.id,
        lagoMappableName: item.label,
      }

      acc[billingEntityId] = itemToAdd
      return acc
    }

    acc[billingEntityId] = {
      itemId: itemMapping.id,
      itemExternalId: itemMapping.externalId || null,
      itemExternalName: itemMapping.externalName || undefined,
      itemExternalCode: itemMapping.externalAccountCode || undefined,
    }

    return acc
  }, {} as ItemMappingPerBillingEntity)
}
