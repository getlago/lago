import { gql } from '@apollo/client'
import { RefObject } from 'react'

import { CREATE_ADD_ON_ROUTE } from '~/core/router'
import {
  GetAddOnsForXeroItemsListQuery,
  InputMaybe,
  IntegrationTypeEnum,
  MappableTypeEnum,
  useGetAddOnsForXeroItemsListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import FetchableIntegrationItemList from '~/pages/settings/integrations/FetchableIntegrationItemList'
import { XeroIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/XeroIntegrationMapItemDrawer'

gql`
  fragment XeroIntegrationItemsListAddons on AddOn {
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
      mappableId
    }
  }
`

type XeroIntegrationItemsListAddonsProps = {
  data: GetAddOnsForXeroItemsListQuery | undefined
  fetchMoreAddons: ReturnType<typeof useGetAddOnsForXeroItemsListLazyQuery>[1]['fetchMore']
  hasError: boolean
  integrationId: string
  searchTerm: InputMaybe<string> | undefined
  isLoading: boolean
  xeroIntegrationMapItemDrawerRef: RefObject<XeroIntegrationMapItemDrawerRef>
}

const XeroIntegrationItemsListAddons = ({
  data,
  fetchMoreAddons,
  hasError,
  integrationId,
  isLoading,
  xeroIntegrationMapItemDrawerRef,
  searchTerm,
}: XeroIntegrationItemsListAddonsProps) => {
  const { translate } = useInternationalization()

  return (
    <FetchableIntegrationItemList
      integrationId={integrationId}
      data={data?.addOns}
      fetchMore={fetchMoreAddons}
      hasError={hasError}
      searchTerm={searchTerm}
      isLoading={isLoading}
      integrationMapItemDrawerRef={xeroIntegrationMapItemDrawerRef}
      createRoute={CREATE_ADD_ON_ROUTE}
      mappableType={MappableTypeEnum.AddOn}
      provider={IntegrationTypeEnum.Xero}
      firstColumnName={translate('text_6630ea71a6c2ef00bc63006f')}
    />
  )
}

export default XeroIntegrationItemsListAddons
