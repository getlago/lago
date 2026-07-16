import { gql, Reference } from '@apollo/client'
import { useCallback, useRef } from 'react'

import {
  IntegrationItemTypeEnum,
  MappableTypeEnum,
  MappingTypeEnum,
  useCreateXeroIntegrationCollectionMappingMutation,
  useCreateXeroIntegrationMappingMutation,
  useDeleteXeroIntegrationCollectionMappingMutation,
  useDeleteXeroIntegrationMappingMutation,
  useGetXeroIntegrationItemsLazyQuery,
  useTriggerXeroIntegrationAccountsRefetchMutation,
  useTriggerXeroIntegrationItemsRefetchMutation,
  useUpdateXeroIntegrationCollectionMappingMutation,
  useUpdateXeroIntegrationMappingMutation,
} from '~/generated/graphql'

const MAPPING_CACHE_FRAGMENT = gql`
  fragment XeroMappingCacheFields on Mapping {
    id
    externalId
    externalName
    externalAccountCode
    mappableType
    billingEntityId
    mappableId
  }
`

export const useXeroIntegrationMappingCRUD = (
  formType: MappableTypeEnum | MappingTypeEnum | undefined,
  integrationId?: string,
) => {
  const isAccountContext = formType === MappingTypeEnum.Account
  const isPaginated =
    formType === MappableTypeEnum.AddOn || formType === MappableTypeEnum.BillableMetric

  const parentTypename = formType === MappableTypeEnum.AddOn ? 'AddOn' : 'BillableMetric'

  // Item fetch — wrap the lazy query to always inject the current integrationId at call time.
  // The Drawer always mounts children (even when closed), and useDebouncedSearch fires
  // searchQuery() on mount with no args, so default variables alone are not reliable.
  const integrationIdRef = useRef(integrationId)

  integrationIdRef.current = integrationId

  const [
    rawGetXeroIntegrationItems,
    { loading: initialItemFetchLoading, data: initialItemFetchData },
  ] = useGetXeroIntegrationItemsLazyQuery()

  const getXeroIntegrationItems = useCallback(
    (...args: Parameters<typeof rawGetXeroIntegrationItems>) => {
      const currentIntegrationId = integrationIdRef.current

      if (!currentIntegrationId) return

      return rawGetXeroIntegrationItems({
        ...args[0],
        variables: {
          ...args[0]?.variables,
          limit: 1000,
          integrationId: currentIntegrationId,
          itemType: isAccountContext
            ? IntegrationItemTypeEnum.Account
            : IntegrationItemTypeEnum.Standard,
        },
      })
    },
    [isAccountContext, rawGetXeroIntegrationItems],
  )

  const [triggerAccountItemRefetch, { loading: accountItemsLoading }] =
    useTriggerXeroIntegrationAccountsRefetchMutation({
      ...(integrationId && {
        variables: { input: { integrationId } },
      }),
      refetchQueries: ['getXeroIntegrationItems'],
    })

  const [triggerItemRefetch, { loading: itemsLoading }] =
    useTriggerXeroIntegrationItemsRefetchMutation({
      ...(integrationId && {
        variables: { input: { integrationId } },
      }),
      refetchQueries: ['getXeroIntegrationItems'],
    })

  // Mapping Creation
  const [createCollectionMapping] = useCreateXeroIntegrationCollectionMappingMutation({
    refetchQueries: ['getXeroIntegrationCollectionMappings'],
  })
  const [createMapping] = useCreateXeroIntegrationMappingMutation(
    isPaginated
      ? {
          update(cache, { data }, { variables }) {
            if (!data?.createIntegrationMapping || !variables?.input) return

            const newMapping = data.createIntegrationMapping
            const { mappableId, mappableType, billingEntityId } = variables.input

            cache.modify({
              id: cache.identify({ __typename: parentTypename, id: mappableId }),
              fields: {
                integrationMappings(existingMappings = []) {
                  const newRef = cache.writeFragment({
                    data: {
                      __typename: 'Mapping' as const,
                      id: newMapping.id,
                      externalId: newMapping.externalId,
                      externalName: newMapping.externalName ?? null,
                      externalAccountCode: newMapping.externalAccountCode ?? null,
                      mappableType,
                      billingEntityId: billingEntityId ?? null,
                      mappableId,
                    },
                    fragment: MAPPING_CACHE_FRAGMENT,
                  })

                  return [...existingMappings, newRef]
                },
              },
            })
          },
        }
      : { refetchQueries: ['getXeroIntegrationCollectionMappings'] },
  )

  // Mapping edition
  const [updateCollectionMapping] = useUpdateXeroIntegrationCollectionMappingMutation({
    refetchQueries: ['getXeroIntegrationCollectionMappings'],
  })
  const [updateMapping] = useUpdateXeroIntegrationMappingMutation(
    isPaginated
      ? {
          update(cache, _result, { variables }) {
            if (!variables?.input) return

            const { id, externalId, externalName, externalAccountCode } = variables.input

            cache.modify({
              id: cache.identify({ __typename: 'Mapping', id }),
              fields: {
                ...(externalId !== undefined && { externalId: () => externalId }),
                ...(externalName !== undefined && { externalName: () => externalName }),
                ...(externalAccountCode !== undefined && {
                  externalAccountCode: () => externalAccountCode,
                }),
              },
            })
          },
        }
      : { refetchQueries: ['getXeroIntegrationCollectionMappings'] },
  )

  // Mapping deletion
  const [deleteCollectionMapping] = useDeleteXeroIntegrationCollectionMappingMutation({
    refetchQueries: ['getXeroIntegrationCollectionMappings'],
  })
  const [deleteMapping] = useDeleteXeroIntegrationMappingMutation(
    isPaginated
      ? {
          update(cache, { data }) {
            if (!data?.destroyIntegrationMapping?.id) return

            const deletedId = data.destroyIntegrationMapping.id
            const cacheId = cache.identify({ __typename: 'Mapping', id: deletedId })

            if (!cacheId) return

            const cachedMapping = cache.readFragment<{ mappableId: string }>({
              id: cacheId,
              fragment: gql`
                fragment MappingParentId on Mapping {
                  mappableId
                }
              `,
            })

            if (cachedMapping?.mappableId) {
              cache.modify({
                id: cache.identify({
                  __typename: parentTypename,
                  id: cachedMapping.mappableId,
                }),
                fields: {
                  integrationMappings(existingMappings: readonly Reference[] = [], { readField }) {
                    return existingMappings.filter((ref) => readField('id', ref) !== deletedId)
                  },
                },
              })
            }

            cache.evict({ id: cacheId })
            cache.gc()
          },
        }
      : { refetchQueries: ['getXeroIntegrationCollectionMappings'] },
  )

  return {
    getXeroIntegrationItems,
    initialItemFetchLoading,
    initialItemFetchData,
    accountItemsLoading,
    itemsLoading,
    triggerAccountItemRefetch,
    triggerItemRefetch,
    createCollectionMapping,
    createMapping,
    deleteCollectionMapping,
    deleteMapping,
    updateCollectionMapping,
    updateMapping,
  }
}
