import { gql } from '@apollo/client'
import { RefObject } from 'react'

import { CREATE_ADD_ON_ROUTE } from '~/core/router'
import {
  GetAddOnsForNetsuiteItemsListQuery,
  InputMaybe,
  IntegrationTypeEnum,
  MappableTypeEnum,
  useGetAddOnsForNetsuiteItemsListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import FetchableIntegrationItemList from '~/pages/settings/integrations/FetchableIntegrationItemList'
import { NetsuiteIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/NetsuiteIntegrationMapItemDrawer'

gql`
  fragment NetsuiteIntegrationItemsListAddons on AddOn {
    id
    name
    code
    integrationMappings(integrationId: $integrationId) {
      id
      externalId
      externalAccountCode
      externalName
      mappableType
      billingEntityId
    }
  }
`

type NetsuiteIntegrationItemsListAddonsProps = {
  data: GetAddOnsForNetsuiteItemsListQuery | undefined
  fetchMoreAddons: ReturnType<typeof useGetAddOnsForNetsuiteItemsListLazyQuery>[1]['fetchMore']
  hasError: boolean
  integrationId: string
  searchTerm: InputMaybe<string> | undefined
  isLoading: boolean
  netsuiteIntegrationMapItemDrawerRef: RefObject<NetsuiteIntegrationMapItemDrawerRef>
}

const NetsuiteIntegrationItemsListAddons = ({
  data,
  fetchMoreAddons,
  hasError,
  integrationId,
  isLoading,
  netsuiteIntegrationMapItemDrawerRef,
  searchTerm,
}: NetsuiteIntegrationItemsListAddonsProps) => {
  const { translate } = useInternationalization()

  return (
    <FetchableIntegrationItemList
      integrationId={integrationId}
      data={data?.addOns}
      fetchMore={fetchMoreAddons}
      hasError={hasError}
      searchTerm={searchTerm}
      isLoading={isLoading}
      integrationMapItemDrawerRef={netsuiteIntegrationMapItemDrawerRef}
      createRoute={CREATE_ADD_ON_ROUTE}
      mappableType={MappableTypeEnum.AddOn}
      provider={IntegrationTypeEnum.Netsuite}
      firstColumnName={translate('text_6630ea71a6c2ef00bc63006f')}
    />
  )
}

export default NetsuiteIntegrationItemsListAddons
