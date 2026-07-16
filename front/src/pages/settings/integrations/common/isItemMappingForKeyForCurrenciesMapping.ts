import { MappingTypeEnum } from '~/generated/graphql'
import {
  ItemMappingForCurrenciesMapping,
  ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common/types'

export const isItemMappingForKeyForCurrenciesMapping = (
  item: unknown,
  itemMapping: ItemMappingPerBillingEntity,
  key: string,
): itemMapping is ItemMappingPerBillingEntity & { [key]: ItemMappingForCurrenciesMapping } => {
  return (
    !!item &&
    typeof item === 'object' &&
    'mappingType' in item &&
    item.mappingType === MappingTypeEnum.Currencies &&
    !!itemMapping &&
    key in itemMapping &&
    typeof itemMapping[key] === 'object' &&
    'currencies' in itemMapping[key]
  )
}
