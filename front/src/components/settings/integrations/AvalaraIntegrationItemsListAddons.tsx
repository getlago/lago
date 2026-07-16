import { gql } from '@apollo/client'
import { RefObject } from 'react'

import { CREATE_ADD_ON_ROUTE } from '~/core/router'
import {
  GetAddOnsForAvalaraItemsListQuery,
  InputMaybe,
  IntegrationTypeEnum,
  MappableTypeEnum,
  useGetAddOnsForAvalaraItemsListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { AvalaraIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/AvalaraIntegrationMapItemDrawer'
import FetchableIntegrationItemList from '~/pages/settings/integrations/FetchableIntegrationItemList'

gql`
  fragment AvalaraIntegrationItemsListAddons on AddOn {
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

type AvalaraIntegrationItemsListAddonsProps = {
  data: GetAddOnsForAvalaraItemsListQuery | undefined
  fetchMoreAddons: ReturnType<typeof useGetAddOnsForAvalaraItemsListLazyQuery>[1]['fetchMore']
  hasError: boolean
  integrationId: string
  searchTerm: InputMaybe<string> | undefined
  isLoading: boolean
  avalaraIntegrationMapItemDrawerRef: RefObject<AvalaraIntegrationMapItemDrawerRef>
}

const AvalaraIntegrationItemsListAddons = ({
  data,
  fetchMoreAddons,
  hasError,
  integrationId,
  isLoading,
  avalaraIntegrationMapItemDrawerRef,
  searchTerm,
}: AvalaraIntegrationItemsListAddonsProps) => {
  const { translate } = useInternationalization()

  return (
    <FetchableIntegrationItemList
      integrationId={integrationId}
      data={data?.addOns}
      fetchMore={fetchMoreAddons}
      hasError={hasError}
      searchTerm={searchTerm}
      isLoading={isLoading}
      integrationMapItemDrawerRef={avalaraIntegrationMapItemDrawerRef}
      createRoute={CREATE_ADD_ON_ROUTE}
      mappableType={MappableTypeEnum.AddOn}
      provider={IntegrationTypeEnum.Avalara}
      firstColumnName={translate('text_6630ea71a6c2ef00bc63006f')}
    />
  )
}

export default AvalaraIntegrationItemsListAddons
