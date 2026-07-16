import { gql } from '@apollo/client'
import { RefObject } from 'react'

import { CREATE_BILLABLE_METRIC_ROUTE } from '~/core/router'
import {
  GetBillableMetricsForXeroItemsListQuery,
  InputMaybe,
  IntegrationTypeEnum,
  MappableTypeEnum,
  useGetBillableMetricsForXeroItemsListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import FetchableIntegrationItemList from '~/pages/settings/integrations/FetchableIntegrationItemList'
import { XeroIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/XeroIntegrationMapItemDrawer'

gql`
  fragment XeroIntegrationItemsListBillableMetrics on BillableMetric {
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

type XeroIntegrationItemsListBillableMetricsProps = {
  data: GetBillableMetricsForXeroItemsListQuery | undefined
  fetchMoreBillableMetrics: ReturnType<
    typeof useGetBillableMetricsForXeroItemsListLazyQuery
  >[1]['fetchMore']
  hasError: boolean
  integrationId: string
  searchTerm: InputMaybe<string> | undefined
  isLoading: boolean
  xeroIntegrationMapItemDrawerRef: RefObject<XeroIntegrationMapItemDrawerRef>
}

const XeroIntegrationItemsListBillableMetrics = ({
  data,
  fetchMoreBillableMetrics,
  hasError,
  integrationId,
  isLoading,
  xeroIntegrationMapItemDrawerRef,
  searchTerm,
}: XeroIntegrationItemsListBillableMetricsProps) => {
  const { translate } = useInternationalization()

  return (
    <FetchableIntegrationItemList
      integrationId={integrationId}
      data={data?.billableMetrics}
      fetchMore={fetchMoreBillableMetrics}
      hasError={hasError}
      searchTerm={searchTerm}
      isLoading={isLoading}
      integrationMapItemDrawerRef={xeroIntegrationMapItemDrawerRef}
      createRoute={CREATE_BILLABLE_METRIC_ROUTE}
      mappableType={MappableTypeEnum.BillableMetric}
      provider={IntegrationTypeEnum.Xero}
      firstColumnName={translate('text_6630ea71a6c2ef00bc63006e')}
    />
  )
}

export default XeroIntegrationItemsListBillableMetrics
