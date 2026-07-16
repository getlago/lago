import { AmountCentsCell } from '~/components/customers/usage/sections/AmountCentsCell'
import { BreakdownNameCell } from '~/components/customers/usage/sections/BreakdownNameCell'
import {
  dedupeTailBreakdowns,
  isBreakdownRow,
  makeBreakdownRows,
  NO_ID_FILTER_DEFAULT_VALUE,
  SubscriptionUsageDetailDrawerUsage,
  sumBreakdownUnits,
} from '~/components/customers/usage/usageDetailsHelpers'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { MixedCharge } from '~/components/subscriptions/SubscriptionCurrentUsageTable'
import { composeChargeFilterDisplayName } from '~/core/formats/formatInvoiceItemsMap'
import { LocaleEnum } from '~/core/translations'
import { CurrencyEnum, ProjectedChargeFilterUsage, ProjectedChargeUsage } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

type FiltersOnlyTableProps = {
  usage: SubscriptionUsageDetailDrawerUsage | undefined
  currency: CurrencyEnum
  locale?: LocaleEnum
  showProjected: boolean
  translate: TranslateFunc
  unitsHeader: string
  amountHeader: string
}

export const FiltersOnlyTable = ({
  usage,
  currency,
  locale,
  showProjected,
  translate,
  unitsHeader,
  amountHeader,
}: FiltersOnlyTableProps) => {
  const displayName = usage?.charge.invoiceDisplayName || usage?.billableMetric.name
  const pricingUnitShortName = usage?.charge.appliedPricingUnit?.pricingUnit?.shortName
  const unitsKey = showProjected ? 'projectedUnits' : 'units'

  // Projected tab uses `projectedPresentationBreakdowns` (added 2026-05) so
  // breakdowns and parent units align with the projected total.
  const breakdownsForFilter = (filter: {
    presentationBreakdowns?: { presentationBy: unknown; units: string }[] | null
    projectedPresentationBreakdowns?: { presentationBy: unknown; units: string }[] | null
  }) =>
    showProjected
      ? (filter as ProjectedChargeFilterUsage).projectedPresentationBreakdowns
      : filter.presentationBreakdowns

  const chargeLevelBreakdowns = showProjected
    ? (usage as ProjectedChargeUsage | undefined)?.projectedPresentationBreakdowns
    : usage?.presentationBreakdowns

  return (
    <Table
      name="filters-table"
      containerSize={0}
      rowSize={!!pricingUnitShortName ? 72 : 48}
      data={[
        ...(usage?.filters || []).flatMap((rawFilter) => {
          const f = {
            ...rawFilter,
            // Table component expect all elements to have an ID
            id: rawFilter.id || NO_ID_FILTER_DEFAULT_VALUE,
          }

          return [f, ...makeBreakdownRows(`filter-${f.id}`, breakdownsForFilter(f))]
        }),
        // Tail breakdowns for fees on this charge that are not tied to a
        // filter. Deduped against the per-filter breakdowns because the
        // backend sometimes emits the same entries at both levels (notably
        // when a no-id "catch-all" filter accounts for the same fees as the
        // charge-level list).
        ...makeBreakdownRows(
          'charge',
          dedupeTailBreakdowns(
            (usage?.filters || []).map((f) => breakdownsForFilter(f)),
            chargeLevelBreakdowns,
          ),
        ),
      ]}
      columns={[
        {
          key: 'invoiceDisplayName',
          title: translate('text_1725983967306dtwnapp4mw9'),
          maxSpace: true,
          truncateOverflow: true,
          content: (row) => {
            if (isBreakdownRow(row)) {
              return <BreakdownNameCell presentationBy={row.presentationBy} />
            }

            const mappedFilterDisplayName =
              row.id === NO_ID_FILTER_DEFAULT_VALUE
                ? translate('text_64e620bca31226337ffc62ad')
                : composeChargeFilterDisplayName(row)

            return (
              <Typography variant="body" color="grey700" noWrap>
                {row.invoiceDisplayName || mappedFilterDisplayName || displayName}
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
            const breakdowns = breakdownsForFilter(row)
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
