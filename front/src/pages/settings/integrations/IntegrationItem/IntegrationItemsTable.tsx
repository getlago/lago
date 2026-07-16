import Stack from '@mui/material/Stack'
import { Icon } from 'lago-design-system'

import { Avatar } from '~/components/designSystem/Avatar'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status } from '~/components/designSystem/Status'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { VoidReturningFunction } from '~/core/types/voidReturningFunction'
import { useGetBillingEntitiesQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  type BillingEntityForIntegrationMapping,
  DEFAULT_MAPPING_KEY,
  isItemMappingForKeyForCurrenciesMapping,
  type ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common'

import { findItemMapping } from './findItemMapping'
import { generateItemMappingForAllBillingEntities } from './generateItemMappingForAllBillingEntities'
import { IntegrationItemData, IntegrationItemsTableProps } from './types'
import { useGetStatusDetails } from './useGetStatusDetails'

const COLUMN_MIN_WIDTH = 200

const IntegrationItemsTable = ({
  integrationId,
  integrationMapItemDrawerRef,
  items,
  provider,
  isLoading,
  firstColumnName,
  displayBillingEntities = true,
}: IntegrationItemsTableProps) => {
  const { translate } = useInternationalization()

  const { data: billingEntitiesData, loading: isLoadingBillingEntities } =
    useGetBillingEntitiesQuery()

  const { getStatusDetails } = useGetStatusDetails()

  const getBillingEntitiesColumn = () => {
    const baseBillingEntities = [
      {
        id: null,
        key: DEFAULT_MAPPING_KEY,
        name: translate('text_6630e3210c13c500cd398e97'),
      },
    ]

    if (!displayBillingEntities) {
      return baseBillingEntities
    }

    if (
      !billingEntitiesData ||
      !billingEntitiesData.billingEntities ||
      !billingEntitiesData.billingEntities.collection
    ) {
      return baseBillingEntities
    }

    const billingEntities = billingEntitiesData.billingEntities.collection.map((billingEntity) => ({
      id: billingEntity.id,
      key: billingEntity.id,
      name: billingEntity.name || billingEntity.code,
    }))

    return [...baseBillingEntities, ...billingEntities]
  }

  const billingEntitiesColumns = getBillingEntitiesColumn()

  const generateTableColumnDataFromBillingEntity = (
    column: BillingEntityForIntegrationMapping,
  ): TableColumn<IntegrationItemData> => ({
    key: 'id',
    title: column.name,
    content: (item: IntegrationItemData) => {
      if (isLoading || isLoadingBillingEntities) {
        return (
          <div className="flex h-full min-w-42 items-center justify-center">
            <Skeleton className="w-full" variant="text" />
          </div>
        )
      }

      const itemMapping = findItemMapping(item, column.id)
      const { type, label } = getStatusDetails(item, column.id, itemMapping, provider)

      return <Status type={type} label={label} />
    },
    minWidth: COLUMN_MIN_WIDTH,
  })

  const columns: Array<TableColumn<IntegrationItemData>> = [
    {
      key: 'label',
      title: firstColumnName ?? translate('text_661ff6e56ef7e1b7c542b200'),
      content: (item: IntegrationItemData) => {
        return (
          <Stack direction="row" alignItems="center" gap={3} className="py-3">
            <Avatar size="big" variant="connector">
              <Icon name={item.icon} color="dark" />
            </Avatar>

            <Stack>
              <Typography variant="bodyHl" color="grey700">
                {item.label}
              </Typography>
              <Typography variant="caption" color="grey600">
                {item.description}
              </Typography>
            </Stack>
          </Stack>
        )
      },
      minWidth: COLUMN_MIN_WIDTH,
      maxSpace: true,
    },
    ...billingEntitiesColumns.map(generateTableColumnDataFromBillingEntity),
  ]

  const getOnMappingClick = (
    item: IntegrationItemData,
    itemMappingPerBillingEntity: ItemMappingPerBillingEntity,
  ): VoidReturningFunction => {
    const props = {
      integrationId,
      type: item.mappingType,
      billingEntities: billingEntitiesColumns,
      itemMappings: itemMappingPerBillingEntity,
    }

    if (isItemMappingForKeyForCurrenciesMapping(item, itemMappingPerBillingEntity, 'default')) {
      return () =>
        integrationMapItemDrawerRef.current?.openDrawer({
          ...props,
          itemId: itemMappingPerBillingEntity.default.itemId || undefined,
          mappings: itemMappingPerBillingEntity.default.currencies || [],
        })
    }

    return () => integrationMapItemDrawerRef.current?.openDrawer(props)
  }

  const handleRowActionClick = (item: IntegrationItemData): void => {
    const itemMappingPerBillingEntities = generateItemMappingForAllBillingEntities(
      item,
      billingEntitiesColumns,
    )
    const onMappingClick = getOnMappingClick(item, itemMappingPerBillingEntities)

    onMappingClick()
  }

  return (
    <Table
      name="integration-items"
      columns={columns}
      data={items}
      onRowActionClick={handleRowActionClick}
      isLoading={isLoading || isLoadingBillingEntities}
    />
  )
}

export default IntegrationItemsTable
