import { useVirtualizer } from '@tanstack/react-virtual'
import { useRef } from 'react'

import { BreakdownNameCell } from '~/components/customers/usage/sections/BreakdownNameCell'
import { PresentationBreakdownRow } from '~/components/customers/usage/usageDetailsHelpers'
import { Typography } from '~/components/designSystem/Typography'

const BREAKDOWN_ROW_HEIGHT = 48
const MAX_VIRTUAL_LIST_HEIGHT = 440

// Width of the indicator (in px) used by the parent design-system Table to
// pad the inner cell. We mirror it on the units slot so the right edge of the
// units text matches the parent table's right-aligned units column.
// See `src/components/designSystem/Table/Table.tsx` (`PADDING_SPACING_RIGHT_PX`).
const TABLE_INNER_CELL_RIGHT_PADDING_PX = 32

type VirtualizedBreakdownRowsProps = {
  rows: PresentationBreakdownRow[]
  // Measured widths of the parent Table's columns at runtime — passed down by
  // the parent (`ChargeSummarySection`) which queries the live header cells
  // via ResizeObserver. Passing them in keeps the virtualized rows aligned
  // even when column widths change (e.g. longer header text on the Projected
  // tab). When undefined, sensible fallbacks are used.
  unitsColumnWidth?: number
  amountColumnWidth?: number
}

export const VirtualizedBreakdownRows = ({
  rows,
  unitsColumnWidth,
  amountColumnWidth,
}: VirtualizedBreakdownRowsProps) => {
  const parentRef = useRef<HTMLDivElement>(null)

  const rowVirtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => BREAKDOWN_ROW_HEIGHT,
    measureElement: (element) => element.getBoundingClientRect().height,
    overscan: 8,
  })

  if (rows.length === 0) return null

  return (
    <div ref={parentRef} className="overflow-auto" style={{ maxHeight: MAX_VIRTUAL_LIST_HEIGHT }}>
      <div style={{ height: rowVirtualizer.getTotalSize(), position: 'relative' }}>
        {rowVirtualizer.getVirtualItems().map((virtualRow) => {
          const row = rows[virtualRow.index]

          return (
            <div
              key={row.id}
              ref={rowVirtualizer.measureElement}
              data-index={virtualRow.index}
              className="flex w-full items-center border-b border-grey-200 py-6"
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                transform: `translateY(${virtualRow.start}px)`,
              }}
            >
              <div className="min-w-0 flex-1">
                <BreakdownNameCell presentationBy={row.presentationBy} />
              </div>
              <div
                className="shrink-0 text-right"
                style={{
                  width: unitsColumnWidth,
                  paddingRight: TABLE_INNER_CELL_RIGHT_PADDING_PX,
                  boxSizing: 'border-box',
                }}
              >
                <Typography variant="body" color="grey600">
                  {row.breakdownUnits}
                </Typography>
              </div>
              {/* Empty amount slot — reserves the same width as the parent
                  Table's amount column so the units column lines up. The
                  width is measured from the live parent table at render time. */}
              <div className="shrink-0" style={{ width: amountColumnWidth }} />
            </div>
          )
        })}
      </div>
    </div>
  )
}
