import { gql } from '@apollo/client'
import { RefObject } from 'react'

import { CREATE_ADD_ON_ROUTE } from '~/core/router'
import {
  GetAddOnsForAnrokItemsListQuery,
  InputMaybe,
  IntegrationTypeEnum,
  MappableTypeEnum,
  useGetAddOnsForAnrokItemsListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { AnrokIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/AnrokIntegrationMapItemDrawer'
import FetchableIntegrationItemList from '~/pages/settings/integrations/FetchableIntegrationItemList'

gql`
  fragment AnrokIntegrationItemsListAddons on AddOn {
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

type AnrokIntegrationItemsListAddonsProps = {
  data: GetAddOnsForAnrokItemsListQuery | undefined
  fetchMoreAddons: ReturnType<typeof useGetAddOnsForAnrokItemsListLazyQuery>[1]['fetchMore']
  hasError: boolean
  integrationId: string
  searchTerm: InputMaybe<string> | undefined
  isLoading: boolean
  anrokIntegrationMapItemDrawerRef: RefObject<AnrokIntegrationMapItemDrawerRef>
}

const AnrokIntegrationItemsListAddons = ({
  data,
  fetchMoreAddons,
  hasError,
  integrationId,
  isLoading,
  anrokIntegrationMapItemDrawerRef,
  searchTerm,
}: AnrokIntegrationItemsListAddonsProps) => {
  const { translate } = useInternationalization()

  return (
    <FetchableIntegrationItemList
      integrationId={integrationId}
      data={data?.addOns}
      fetchMore={fetchMoreAddons}
      hasError={hasError}
      searchTerm={searchTerm}
      isLoading={isLoading}
      integrationMapItemDrawerRef={anrokIntegrationMapItemDrawerRef}
      createRoute={CREATE_ADD_ON_ROUTE}
      mappableType={MappableTypeEnum.AddOn}
      provider={IntegrationTypeEnum.Anrok}
      firstColumnName={translate('text_6630ea71a6c2ef00bc63006f')}
    />
  )
}

export default AnrokIntegrationItemsListAddons
