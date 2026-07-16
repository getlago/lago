import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { MappableTypeEnum } from '~/generated/graphql'
import { FetchIntegrationItemsListProps } from '~/pages/settings/integrations/FetchableIntegrationItemList/types'
import {
  IntegrationItem,
  IntegrationItemsTable,
} from '~/pages/settings/integrations/IntegrationItem'

import FetchableIntegrationItemEmpty from './FetchableIntegrationItemEmpty'
import FetchableIntegrationItemError from './FetchableIntegrationItemError'

const FetchableIntegrationItemList = ({
  integrationId,
  data,
  fetchMore,
  hasError,
  searchTerm,
  isLoading,
  integrationMapItemDrawerRef,
  createRoute,
  mappableType,
  provider,
  firstColumnName,
}: FetchIntegrationItemsListProps) => {
  const itemsToDisplay = data?.collection || []

  // Only show loading state when no data exists yet to preserve scroll position during background refetches
  const showLoadingState = isLoading && !itemsToDisplay.length

  const metadata = data?.metadata

  const displayCorrectState = () => {
    if (!showLoadingState && !!hasError) {
      return <FetchableIntegrationItemError hasSearchTerm={!!searchTerm} />
    }

    if (!showLoadingState && !itemsToDisplay.length) {
      return (
        <FetchableIntegrationItemEmpty
          hasSearchTerm={!!searchTerm}
          createRoute={createRoute}
          type={mappableType}
        />
      )
    }

    const handleOnBottom = () => {
      if (!metadata || !('currentPage' in metadata) || !('totalPages' in metadata)) return
      const { currentPage = 0, totalPages = 0 } = metadata

      if (currentPage < totalPages && !isLoading) {
        fetchMore({
          variables: { page: currentPage + 1 },
        })
      }
    }

    const formattedItems: Array<IntegrationItem> = itemsToDisplay.map((itemToDisplay) => {
      return {
        id: itemToDisplay.id,
        label: itemToDisplay.name,
        description: itemToDisplay.code,
        mappingType: mappableType,
        integrationMappings: itemToDisplay.integrationMappings,
        icon: mappableType === MappableTypeEnum.AddOn ? 'puzzle' : 'pulse',
      }
    })

    return (
      <InfiniteScroll onBottom={handleOnBottom}>
        <IntegrationItemsTable
          integrationId={integrationId}
          integrationMapItemDrawerRef={integrationMapItemDrawerRef}
          provider={provider}
          items={formattedItems}
          firstColumnName={firstColumnName}
          isLoading={showLoadingState}
        />
      </InfiniteScroll>
    )
  }

  return <>{displayCorrectState()}</>
}

export default FetchableIntegrationItemList
