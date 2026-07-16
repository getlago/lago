import {
  MappingTypeEnum,
  NetsuiteIntegrationAdditionalItemsListFragment,
} from '~/generated/graphql'
import { ItemMapping } from '~/pages/settings/integrations/common'

import { IntegrationItemData } from './types'

export const isNetsuiteIntegrationAdditionalItemsListFragment = (
  item: IntegrationItemData,
  itemMapping: ItemMapping | undefined,
): itemMapping is NetsuiteIntegrationAdditionalItemsListFragment => {
  return (
    item.mappingType === MappingTypeEnum.Currencies && !!itemMapping && 'currencies' in itemMapping
  )
}
