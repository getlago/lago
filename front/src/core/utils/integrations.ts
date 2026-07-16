type Integration = { __typename?: string; id?: string }
type IntegrationCollection = Integration[] | undefined

export function getConnectedIntegration<T extends Integration>(
  collection: IntegrationCollection,
  typename: string,
  integrationId: string | undefined | null,
): T | undefined {
  if (!collection || typeof integrationId !== 'string') return undefined
  return collection.find((i) => i.__typename === typename && (i as T).id === integrationId) as
    T | undefined
}
