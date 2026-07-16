import { AmountCentsCell } from '~/components/customers/usage/sections/AmountCentsCell'
import { BreakdownNameCell } from '~/components/customers/usage/sections/BreakdownNameCell'
import {
  isBreakdownRow,
  makeBreakdownRows,
  SubscriptionUsageDetailDrawerUsage,
  sumBreakdownUnits,
} from '~/components/customers/usage/usageDetailsHelpers'
import { Chip } from '~/components/designSystem/Chip'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { MixedCharge } from '~/components/subscriptions/SubscriptionCurrentUsageTable'
import { composeGroupedByDisplayName } from '~/core/formats/formatInvoiceItemsMap'
import { LocaleEnum } from '~/core/translations'
import { CurrencyEnum, GroupedChargeUsage, ProjectedGroupedChargeUsage } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

type GroupedUsageTableProps = {
  usage: SubscriptionUsageDetailDrawerUsage | undefined
  currency: CurrencyEnum
  locale?: LocaleEnum
  showProjected: boolean
  translate: TranslateFunc
  unitsHeader: string
  amountHeader: string
}

export const GroupedUsageTable = ({
  usage,
  currency,
  locale,
  showProjected,
  translate,
  unitsHeader,
  amountHeader,
}: GroupedUsageTableProps) => {
  const displayName = usage?.charge.invoiceDisplayName || usage?.billableMetric.name
  const pricingUnitShortName = usage?.charge.appliedPricingUnit?.pricingUnit?.shortName
  const unitsKey = showProjected ? 'projectedUnits' : 'units'

  // Projected tab uses the projected breakdown field (added 2026-05) to align
  // with projected units; current tab uses the live `presentationBreakdowns`.
  const breakdownsForRow = (row: GroupedChargeUsage) =>
    showProjected
      ? (row as ProjectedGroupedChargeUsage).projectedPresentationBreakdowns
      : row.presentationBreakdowns

  return (
    <Table
      name="grouped-usage-table"
      containerSize={0}
      rowSize={!!pricingUnitShortName ? 72 : 48}
      data={((usage?.groupedUsage as GroupedChargeUsage[]) || []).flatMap((row) => [
        row,
        ...makeBreakdownRows(row.id, breakdownsForRow(row)),
      ])}
      columns={[
        {
          key: 'id',
          title: translate('text_1725983967306dtwnapp4mw9'),
          maxSpace: true,
          truncateOverflow: true,
          content: (row) => {
            if (isBreakdownRow(row)) {
              return <BreakdownNameCell presentationBy={row.presentationBy} />
            }

            const currentGroupedByDisplayName = composeGroupedByDisplayName(row?.groupedBy)
            const groupedByKeys =
              row?.groupedBy && typeof row.groupedBy === 'object' ? Object.keys(row.groupedBy) : []

            // When the groupedBy values are all null `composeGroupedByDisplayName`
            // returns "". Falling back to the billable-metric name is misleading
            // (it reads as if there's no grouping at all). Render the groupedBy
            // KEYS as chips so the user can still tell which pricing-group
            // dimension they're looking at.
            if (!currentGroupedByDisplayName && groupedByKeys.length > 0) {
              return (
                <div className="flex flex-wrap items-center gap-1">
                  {groupedByKeys.map((key) => (
                    <Chip key={key} label={key} size="small" />
                  ))}
                </div>
              )
            }

            return (
              <Typography variant="body" color="grey700" noWrap>
                {currentGroupedByDisplayName || displayName}
              </Typography>
            )
          },
        },
        {
          key: 'units',
          title: unitsHeader,
          textAlign: 'right',
          minWidth: 70,
          content: (row) => {
            if (isBreakdownRow(row)) {
              return (
                <Typography variant="body" color="grey600">
                  {row.breakdownUnits}
                </Typography>
              )
            }

            // Projected tab: show the raw `projectedUnits` from GraphQL —
            // it's the source of truth and won't equal
            // sum(projectedPresentationBreakdowns) for non-additive
            // aggregations like max / unique_count.
            // Current tab: when breakdowns exist, sum them so the parent
            // reconciles with the breakdown rows below it.
            const breakdowns = breakdownsForRow(row)
            const hasBreakdowns = (breakdowns?.length ?? 0) > 0
            const displayUnits =
              !showProjected && hasBreakdowns
                ? sumBreakdownUnits(breakdowns)
                : (row as MixedCharge)[unitsKey]

            return (
              <Typography variant="body" color="grey700">
                {displayUnits}
              </Typography>
            )
          },
        },
        {
          key: 'amountCents',
          title: amountHeader,
          textAlign: 'right',
          minWidth: 100,
          content: (row) => {
            if (isBreakdownRow(row)) {
              return null
            }

            return (
              <AmountCentsCell
                row={row}
                currency={currency}
                locale={locale}
                pricingUnitShortName={pricingUnitShortName}
                showProjected={showProjected}
              />
            )
          },
        },
      ]}
    />
  )
}
