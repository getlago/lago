import { IntegrationTypeEnum } from '~/generated/graphql'

import { isItemMapping } from './isItemMapping'
import { MappableIntegrationProvider } from './types'

/**
 * Get mapping information for a specific item mapping and integration provider.
 * @param itemMapping unknown The item mapping to test
 * @param provider MappableIntegrationProvider The integration provider
 * @returns A formatted object containing the mapping info or undefined if the itemMapping is invalid
 */
export const getMappingInfos = (
  itemMapping: unknown,
  provider: MappableIntegrationProvider,
): { id: string | undefined; name: string } | undefined => {
  if (!isItemMapping(itemMapping) || !itemMapping.id) {
    return undefined
  }

  const authorizedProviders = [
    IntegrationTypeEnum.Anrok,
    IntegrationTypeEnum.Avalara,
    IntegrationTypeEnum.Netsuite,
    IntegrationTypeEnum.Xero,
  ]

  if (!authorizedProviders.includes(provider)) {
    return undefined
  }

  if (provider === IntegrationTypeEnum.Xero) {
    return {
      id: itemMapping.externalAccountCode ?? undefined,
      name: itemMapping.externalName ?? '',
    }
  }

  return {
    id: itemMapping.externalId ?? undefined,
    name: itemMapping.externalName ?? '',
  }
}
