import type { ItemMappingForTaxMapping } from '~/pages/settings/integrations/common'

import type { NetsuiteIntegrationMapItemDrawerProps } from './types'

export const isMappingInTaxContext = (
  dataToTest: NetsuiteIntegrationMapItemDrawerProps | undefined,
  keyToTest: string,
): dataToTest is NetsuiteIntegrationMapItemDrawerProps & {
  itemMappings: { [keyToTest]: ItemMappingForTaxMapping }
} => {
  if (!dataToTest) return false
  if (!dataToTest.itemMappings) return false
  if (!dataToTest.itemMappings[keyToTest]) return false
  if (!('taxCode' in dataToTest.itemMappings[keyToTest])) return false
  if (!('taxNexus' in dataToTest.itemMappings[keyToTest])) return false
  if (!('taxType' in dataToTest.itemMappings[keyToTest])) return false

  return true
}
