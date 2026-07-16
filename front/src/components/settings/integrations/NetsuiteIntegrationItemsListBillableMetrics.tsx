import { gql } from '@apollo/client'
import { RefObject } from 'react'

import { CREATE_BILLABLE_METRIC_ROUTE } from '~/core/router'
import {
  GetBillableMetricsForNetsuiteItemsListQuery,
  InputMaybe,
  IntegrationTypeEnum,
  MappableTypeEnum,
  useGetBillableMetricsForNetsuiteItemsListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import FetchableIntegrationItemList from '~/pages/settings/integrations/FetchableIntegrationItemList'
import { NetsuiteIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/NetsuiteIntegrationMapItemDrawer'

gql`
  fragment NetsuiteIntegrationItemsListBillableMetrics on BillableMetric {
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

type NetsuiteIntegrationItemsListBillableMetricsProps = {
  data: GetBillableMetricsForNetsuiteItemsListQuery | undefined
  fetchMoreBillableMetrics: ReturnType<
    typeof useGetBillableMetricsForNetsuiteItemsListLazyQuery
  >[1]['fetchMore']
  hasError: boolean
  integrationId: string
  searchTerm: InputMaybe<string> | undefined
  isLoading: boolean
  netsuiteIntegrationMapItemDrawerRef: RefObject<NetsuiteIntegrationMapItemDrawerRef>
}

const NetsuiteIntegrationItemsListBillableMetrics = ({
  data,
  fetchMoreBillableMetrics,
  hasError,
  integrationId,
  isLoading,
  netsuiteIntegrationMapItemDrawerRef,
  searchTerm,
}: NetsuiteIntegrationItemsListBillableMetricsProps) => {
  const { translate } = useInternationalization()

  return (
    <FetchableIntegrationItemList
      integrationId={integrationId}
      data={data?.billableMetrics}
      fetchMore={fetchMoreBillableMetrics}
      hasError={hasError}
      searchTerm={searchTerm}
      isLoading={isLoading}
      integrationMapItemDrawerRef={netsuiteIntegrationMapItemDrawerRef}
      createRoute={CREATE_BILLABLE_METRIC_ROUTE}
      mappableType={MappableTypeEnum.BillableMetric}
      provider={IntegrationTypeEnum.Netsuite}
      firstColumnName={translate('text_6630ea71a6c2ef00bc63006e')}
    />
  )
}

export default NetsuiteIntegrationItemsListBillableMetrics
