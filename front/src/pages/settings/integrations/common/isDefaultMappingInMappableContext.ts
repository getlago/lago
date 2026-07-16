import type { AnrokIntegrationMapItemDrawerProps } from '~/pages/settings/integrations/AnrokIntegrationMapItemDrawer'
import type { ItemMappingForMappable } from '~/pages/settings/integrations/common'
import type { NetsuiteIntegrationMapItemDrawerProps } from '~/pages/settings/integrations/NetsuiteIntegrationMapItemDrawer'

export const isDefaultMappingInMappableContext = (
  dataToTest:
    NetsuiteIntegrationMapItemDrawerProps | AnrokIntegrationMapItemDrawerProps | undefined,
): dataToTest is (NetsuiteIntegrationMapItemDrawerProps | AnrokIntegrationMapItemDrawerProps) & {
  itemMappings: { default: ItemMappingForMappable }
} => {
  if (!dataToTest) return false
  if (!dataToTest.itemMappings) return false
  if (!dataToTest.itemMappings.default) return false
  if (!('lagoMappableId' in dataToTest.itemMappings.default)) return false
  if (!('lagoMappableName' in dataToTest.itemMappings.default)) return false

  return true
}
