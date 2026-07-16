import { NetsuiteIntegrationAdditionalItemsListFragment } from '~/generated/graphql'

import { ItemMapping } from './types'

/**
 * Checks if the given item is a valid integration mapping object. This also applies the correct type associated with it.
 * This is a type guard function.
 * @param item unknown
 * @returns boolean
 */
export const isItemMapping = (
  item: unknown,
): item is Exclude<ItemMapping, NetsuiteIntegrationAdditionalItemsListFragment> => {
  return (
    typeof item === 'object' &&
    item !== null &&
    'id' in item &&
    typeof item.id === 'string' &&
    'externalName' in item &&
    typeof item.externalName === 'string' &&
    ('externalId' in item || 'externalAccountCode' in item)
  )
}
