import {
  ItemMappingForCurrenciesMapping,
  ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common/types'

import { isItemMappingForKeyForCurrenciesMapping } from './isItemMappingForKeyForCurrenciesMapping'

export const isItemMappingForKeyNotForCurrenciesMapping = (
  item: unknown,
  itemMapping: ItemMappingPerBillingEntity,
  key: string,
): itemMapping is ItemMappingPerBillingEntity & {
  [key]: Exclude<ItemMappingPerBillingEntity[string], ItemMappingForCurrenciesMapping>
} => {
  return !isItemMappingForKeyForCurrenciesMapping(item, itemMapping, key)
}
