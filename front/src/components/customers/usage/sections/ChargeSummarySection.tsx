import { useEffect, useRef, useState } from 'react'

import { AmountCentsCell } from '~/components/customers/usage/sections/AmountCentsCell'
import { BreakdownNameCell } from '~/components/customers/usage/sections/BreakdownNameCell'
import { VirtualizedBreakdownRows } from '~/components/customers/usage/sections/VirtualizedBreakdownRows'
import {
  isBreakdownRow,
  makeBreakdownRows,
  PresentationBreakdownRow,
  SubscriptionUsageDetailDrawerUsage,
  sumBreakdownUnits,
} from '~/components/customers/usage/usageDetailsHelpers'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { VIRTUALIZATION_THRESHOLD } from '~/components/designSystem/VirtualList/VirtualFilterList'
import { LocaleEnum } from '~/core/translations'
import { CurrencyEnum, ProjectedChargeUsage } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

// Narrow the row shape so the generic Table type doesn't try to resolve the
// entire ChargeUsage object graph.
type ChargeSummaryRow = {
  id: string
  units: number | string
  projectedUnits?: number | string
  amountCents?: number | string
  projectedAmountCents?: number | string
  pricingUnitAmountCents?: number | string
  pricingUnitProjectedAmountCents?: number | string
}

type ChargeSummarySectionProps = {
  usage: SubscriptionUsageDetailDrawerUsage | undefined
  currency: CurrencyEnum
  locale?: LocaleEnum
  showProjected: boolean
  translate: TranslateFunc
  unitsHeader: string
  amountHeader: string
}

const buildChargeSummaryRow = (
  usage: SubscriptionUsageDetailDrawerUsage | undefined,
): ChargeSummaryRow => ({
  id: 'charge-summary',
  units: usage?.units ?? 0,
  projectedUnits: (usage as ProjectedChargeUsage | undefined)?.projectedUnits,
  amountCents: usage?.amountCents ?? 0,
  projectedAmountCents: (usage as ProjectedChargeUsage | undefined)?.projectedAmountCents,
  pricingUnitAmountCents: usage?.pricingUnitAmountCents ?? undefined,
  pricingUnitProjectedAmountCents:
    (usage as ProjectedChargeUsage | undefined)?.pricingUnitProjectedAmountCents ?? undefined,
})

export const ChargeSummarySection = ({
  usage,
  currency,
  locale,
  showProjected,
  translate,
  unitsHeader,
  amountHeader,
}: ChargeSummarySectionProps) => {
  const displayName = usage?.charge.invoiceDisplayName || usage?.billableMetric.name
  const pricingUnitShortName = usage?.charge.appliedPricingUnit?.pricingUnit?.shortName
  const chargeSummaryRow = buildChargeSummaryRow(usage)

  // The projected tab has its own breakdown set (`projectedPresentationBreakdowns`)
  // which lines up with the projected units/amount. Falling back to the current
  // breakdowns here would show stale data on the projected tab.
  const breakdownsForActiveTab = showProjected
    ? (usage as ProjectedChargeUsage | undefined)?.projectedPresentationBreakdowns
    : usage?.presentationBreakdowns

  const breakdownRows = makeBreakdownRows('charge', breakdownsForActiveTab)
  // For charges with 3000+ breakdowns the inline Table rendering bogs the
  // drawer down (QA report). Above the virtualization threshold we drop the
  // breakdowns from the Table and render them in a virtualized scrolling list
  // below; the parent row stays in the Table so the headers/columns survive.
  const shouldVirtualizeBreakdowns = breakdownRows.length > VIRTUALIZATION_THRESHOLD

  const summaryData: Array<ChargeSummaryRow | PresentationBreakdownRow> = shouldVirtualizeBreakdowns
    ? [chargeSummaryRow]
    : [chargeSummaryRow, ...breakdownRows]

  // Measure the parent Table's actual rendered column widths and propagate
  // them to the virtualized breakdown rows so the units / amount slots line
  // up regardless of column auto-sizing (e.g. wider header text on the
  // Projected tab: "Projected units" pushes the column past its 70px
  // minWidth). Hardcoded pixel widths are too fragile here.
  const tableContainerRef = useRef<HTMLDivElement>(null)
  const [virtualRowColumnWidths, setVirtualRowColumnWidths] = useState<{
    units?: number
    amount?: number
  }>({})

  useEffect(() => {
    if (!shouldVirtualizeBreakdowns) return

    const container = tableContainerRef.current

    if (!container) return

    const measure = () => {
      // The design-system Table renders header cells with `.lago-table-cell`
      // inside `<thead>`. The column ORDER in `columns={[...]}` above is
      // [name, units, amount], so we grab indices 1 and 2.
      const headerCells = container.querySelectorAll<HTMLElement>('thead .lago-table-cell')

      if (headerCells.length < 3) return

      setVirtualRowColumnWidths({
        units: headerCells[1].getBoundingClientRect().width,
        amount: headerCells[2].getBoundingClientRect().width,
      })
    }

    measure()

    const observer = new ResizeObserver(measure)

    observer.observe(container)

    return () => observer.disconnect()
  }, [shouldVirtualizeBreakdowns, showProjected, unitsHeader, amountHeader])

  return (
    <section className="mt-12 flex flex-col gap-4">
      <Typography variant="subhead1" color="grey700">
        {translate('text_1778680248317x4cg78xappu')}
      </Typography>

      <div ref={tableContainerRef}>
        <Table
          name="charge-summary-table"
          containerSize={0}
          rowSize={!!pricingUnitShortName ? 72 : 48}
          data={summaryData}
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

                return (
                  <div className="flex flex-col gap-1 py-3">
                    <Typography variant="body" color="grey700" noWrap>
                      {displayName}
                    </Typography>
                    {!!usage?.billableMetric.code && (
                      <Typography variant="caption" color="grey600" noWrap>
                        {usage.billableMetric.code}
                      </Typography>
                    )}
                  </div>
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

                // Projected tab: show the raw `projectedUnits` from GraphQL.
                // The projected aggregation is the source of truth and for
                // non-additive aggregations (e.g. max / unique_count) the sum
                // of projected breakdowns wouldn't equal it.
                // Current tab: when breakdowns exist, sum them so the parent
                // row reconciles with the breakdown rows displayed below it.
                const rawUnits = showProjected ? row.projectedUnits : row.units
                const hasBreakdowns = (breakdownsForActiveTab?.length ?? 0) > 0
                const displayUnits =
                  !showProjected && hasBreakdowns
                    ? sumBreakdownUnits(breakdownsForActiveTab)
                    : rawUnits

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

        {shouldVirtualizeBreakdowns && (
          <VirtualizedBreakdownRows
            rows={breakdownRows}
            unitsColumnWidth={virtualRowColumnWidths.units}
            amountColumnWidth={virtualRowColumnWidths.amount}
          />
        )}
      </div>
    </section>
  )
}
