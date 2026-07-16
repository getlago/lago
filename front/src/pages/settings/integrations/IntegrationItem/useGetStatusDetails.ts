import { StatusType } from '~/components/designSystem/Status'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  getMappingInfos,
  ItemMapping,
  MappableIntegrationProvider,
} from '~/pages/settings/integrations/common'

import { isNetsuiteIntegrationAdditionalItemsListFragment } from './isNetsuiteIntegrationAdditionalItemsListFragment'
import { IntegrationItemData } from './types'

export const useGetStatusDetails = () => {
  const { translate } = useInternationalization()

  const getStatusDetails = (
    item: IntegrationItemData,
    columnId: string | null,
    itemMapping: ItemMapping | undefined,
    provider: MappableIntegrationProvider,
  ): { type: StatusType; label: string } => {
    const mappingInfos = getMappingInfos(itemMapping, provider)

    const isNetsuiteCurrenciesMapping = isNetsuiteIntegrationAdditionalItemsListFragment(
      item,
      itemMapping,
    )

    if (isNetsuiteCurrenciesMapping) {
      if (!itemMapping.currencies || itemMapping.currencies.length === 0) {
        return {
          type: StatusType.warning,
          label: translate('text_6630e3210c13c500cd398e9a'),
        }
      }

      return {
        type: StatusType.success,
        label: translate('text_17272714562192y06u5okvo4'),
      }
    }

    // No mapping info for a billing entity
    if (!mappingInfos) {
      if (columnId !== null) {
        return { type: StatusType.disabled, label: translate('text_65281f686a80b400c8e2f6d1') }
      }

      // No default mapping
      return { type: StatusType.warning, label: translate('text_6630e3210c13c500cd398e9a') }
    }

    if (!!mappingInfos && !mappingInfos.name) {
      return { type: StatusType.success, label: translate('text_17272714562192y06u5okvo4') }
    }

    return {
      type: StatusType.success,
      label: `${mappingInfos.name}${!!mappingInfos.id ? ` (${mappingInfos.id})` : ''}`,
    }
  }

  return { getStatusDetails }
}
