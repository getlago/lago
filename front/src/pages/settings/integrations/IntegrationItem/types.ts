import { IconName } from 'lago-design-system'

import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import {
  ItemMapping,
  MappableIntegrationMapItemDrawerRef,
  MappableIntegrationProvider,
} from '~/pages/settings/integrations/common'

type IntegrationMappings = Array<ItemMapping> | undefined | null

export type IntegrationItem = {
  id: string
  icon: IconName
  label: string
  description: string
  mappingType: MappingTypeEnum | MappableTypeEnum
  integrationMappings: IntegrationMappings
}

export type IntegrationItemData = IntegrationItem & {
  id: string
}

export type IntegrationItemsTableProps = {
  integrationId: string
  items: Array<IntegrationItem>
  provider: MappableIntegrationProvider
  integrationMapItemDrawerRef: MappableIntegrationMapItemDrawerRef
  isLoading: boolean
  firstColumnName?: string
  displayBillingEntities?: boolean
}
