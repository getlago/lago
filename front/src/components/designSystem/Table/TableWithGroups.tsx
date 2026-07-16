import { useVirtualizer } from '@tanstack/react-virtual'
import { Icon } from 'lago-design-system'
import {
  forwardRef,
  ReactNode,
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from 'react'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { theme } from '~/styles'
import { tw } from '~/styles/utils'

import TableInnerCell from './TableInnerCell'
import { Align } from './types'

// Constants
const DEFAULT_COLUMN_WIDTH = 160
const DEFAULT_COLUMN_MIN_WIDTH = 120
const ROW_HEIGHT = 48
const HEADER_ROW_HEIGHT = 40

// --------------------------------
// Type Definitions
// --------------------------------

// Helpers provided to column content render functions
export type ColumnHelpers = {
  isExpanded: boolean // Whether the current row (if group) is expanded
  ChevronIcon: ReactNode // Pre-built chevron component ready to render (null for non-group rows)
}

export type RowConfig = {
  key: string
  label: string | ReactNode
} & ({ type: 'group' } | { type: 'line'; groupKey?: string })

// Unified column configuration
export type ColumnConfig = {
  key: string
  label: string | ReactNode
  minWidth?: number // Minimum width for this column
  isFullWidth?: boolean // If true, this column will expand to fill remaining space
  align?: Align // Text alignment for the column (default: 'left')
  sticky?: boolean // If true, this column will be sticky on the left
  content: (row: RowConfig, helpers: ColumnHelpers) => ReactNode
}

export type TableWithGroupsRef = {
  expandAll: () => void
  collapseAll: () => void
  toggleGroup: (groupKey: string) => void
  isGroupExpanded: (groupKey: string) => boolean
  hasExpandedGroups: () => boolean
  hasCollapsedGroups: () => boolean
  getExpandedState: () => Record<string, boolean>
  setExpandedState: (state: Record<string, boolean>) => void
}

export type TableWithGroupsProps = {
  rows: RowConfig[]
  columns: ColumnConfig[]
  isLoading?: boolean
}

// --------------------------------
// Helper Functions
// --------------------------------

// Get all group keys from rows configuration
const getGroupKeys = (rows: RowConfig[]): string[] => {
  return rows.filter((row) => row.type === 'group').map((row) => row.key)
}

/**
 * Default render function for the row label column.
 * Renders the chevron (for groups) and the row label with appropriate styling.
 */
export const defaultRowLabelContent = (
  row: RowConfig,
  { ChevronIcon }: ColumnHelpers,
): ReactNode => {
  const isGroup = row.type === 'group'

  return (
    <div className="flex flex-row items-center gap-2">
      {ChevronIcon}
      {typeof row.label !== 'string' && row.label}
      {typeof row.label === 'string' && isGroup && (
        <Typography variant="bodyHl" color="grey700" noWrap>
          {row.label}
        </Typography>
      )}
      {typeof row.label === 'string' && !isGroup && (
        <Typography variant="body" color="grey600" noWrap className="pl-8">
          {row.label}
        </Typography>
      )}
    </div>
  )
}

// --------------------------------
// Component
// --------------------------------

const TableWithGroupsInner = (
  { rows, columns, isLoading = false }: TableWithGroupsProps,
  ref: React.ForwardedRef<TableWithGroupsRef>,
) => {
  const containerRef = useRef<HTMLDivElement>(null)
  const parentRef = useRef<HTMLDivElement>(null)

  // Track container width for flex column calculation
  const [containerWidth, setContainerWidth] = useState(0)

  // All groups start collapsed (empty object means all collapsed)
  const [expandedGroups, setExpandedGroups] = useState<Record<string, boolean>>({})

  // Split columns into sticky and scrollable
  const stickyColumns = useMemo(() => columns.filter((col) => col.sticky), [columns])
  const scrollableColumns = useMemo(() => columns.filter((col) => !col.sticky), [columns])

  // Expose methods via ref
  useImperativeHandle(ref, () => ({
    expandAll: () => {
      const allGroups = getGroupKeys(rows)
      const expanded = allGroups.reduce(
        (acc, key) => {
          acc[key] = true
          return acc
        },
        {} as Record<string, boolean>,
      )

      setExpandedGroups(expanded)
    },
    collapseAll: () => {
      setExpandedGroups({})
    },
    toggleGroup: (groupKey: string) => {
      setExpandedGroups((prev) => ({
        ...prev,
        [groupKey]: !prev[groupKey],
      }))
    },
    isGroupExpanded: (groupKey: string) => {
      return !!expandedGroups[groupKey]
    },
    hasExpandedGroups: () => {
      return Object.values(expandedGroups).some(Boolean)
    },
    hasCollapsedGroups: () => {
      const allGroups = getGroupKeys(rows)

      return allGroups.some((groupKey) => !expandedGroups[groupKey])
    },
    getExpandedState: () => {
      return { ...expandedGroups }
    },
    setExpandedState: (state: Record<string, boolean>) => {
      setExpandedGroups(state)
    },
  }))

  // Filter visible rows (hide lines whose group is collapsed)
  const visibleRows = useMemo(() => {
    return rows.filter((row) => {
      if (row.type === 'group') return true
      if (row.type === 'line' && row.groupKey) {
        return !!expandedGroups[row.groupKey]
      }
      return true // Standalone lines are always visible
    })
  }, [rows, expandedGroups])

  // Calculate fixed sticky columns width (columns without isFullWidth)
  const fixedStickyColumnsWidth = useMemo(() => {
    return stickyColumns.reduce((sum, col) => {
      if (col.isFullWidth) return sum

      return sum + (col.minWidth ?? DEFAULT_COLUMN_WIDTH)
    }, 0)
  }, [stickyColumns])

  // Helper to get individual sticky column width
  const getStickyColumnWidth = useCallback(
    (stickyColumnIndex: number): number => {
      const stickyCol = stickyColumns[stickyColumnIndex]

      if (!stickyCol) return DEFAULT_COLUMN_WIDTH

      // If this sticky column has isFullWidth, calculate remaining space
      if (stickyCol.isFullWidth) {
        // Calculate width needed for scrollable columns
        const scrollableColumnsWidth = scrollableColumns.reduce((sum, col) => {
          return sum + (col.minWidth ?? DEFAULT_COLUMN_MIN_WIDTH)
        }, 0)

        // Available width for the full-width sticky column
        const flexWidth = containerWidth - fixedStickyColumnsWidth - scrollableColumnsWidth

        return Math.max(flexWidth, stickyCol.minWidth ?? DEFAULT_COLUMN_WIDTH)
      }

      return stickyCol.minWidth ?? DEFAULT_COLUMN_WIDTH
    },
    [stickyColumns, scrollableColumns, containerWidth, fixedStickyColumnsWidth],
  )

  // Calculate total width of all sticky columns
  const totalStickyWidth = useMemo(() => {
    return stickyColumns.reduce((sum, _, index) => {
      return sum + getStickyColumnWidth(index)
    }, 0)
  }, [stickyColumns, getStickyColumnWidth])

  // Calculate scrollable column widths, accounting for flex column
  const getScrollableColumnWidth = useCallback(
    (index: number): number => {
      const column = scrollableColumns[index]

      if (!column) return DEFAULT_COLUMN_MIN_WIDTH

      // If this column has flex, calculate remaining space
      if (column.isFullWidth) {
        const availableWidth = containerWidth - totalStickyWidth
        const fixedColumnsWidth = scrollableColumns.reduce((sum, col) => {
          if (col.isFullWidth) return sum

          return sum + (col.minWidth ?? DEFAULT_COLUMN_MIN_WIDTH)
        }, 0)

        const flexWidth = Math.max(
          availableWidth - fixedColumnsWidth,
          column.minWidth ?? DEFAULT_COLUMN_MIN_WIDTH,
        )

        return flexWidth
      }

      return column.minWidth ?? DEFAULT_COLUMN_MIN_WIDTH
    },
    [scrollableColumns, containerWidth, totalStickyWidth],
  )

  // Horizontal virtualizer for scrollable columns
  const columnVirtualizer = useVirtualizer({
    count: isLoading ? 12 : scrollableColumns.length,
    horizontal: true,
    estimateSize: getScrollableColumnWidth,
    getScrollElement: () => parentRef.current,
  })

  // Re-measure columns when container width changes (for flex column)
  useEffect(() => {
    columnVirtualizer.measure()
  }, [containerWidth, columnVirtualizer])

  // Vertical virtualizer for rows — uses measureElement for dynamic CSS-driven heights
  const rowVirtualizer = useVirtualizer({
    count: visibleRows.length,
    estimateSize: () => ROW_HEIGHT,
    getScrollElement: () => parentRef.current,
    measureElement: (element) => element.getBoundingClientRect().height,
    overscan: 5,
  })

  // Handle group row click
  const handleRowClick = useCallback((row: RowConfig) => {
    if (row.type !== 'group') return

    setExpandedGroups((prev) => ({
      ...prev,
      [row.key]: !prev[row.key],
    }))
  }, [])

  // Factory function to create chevron icon for a row
  const createChevronIcon = useCallback((row: RowConfig, isExpanded: boolean): ReactNode => {
    if (row.type !== 'group') {
      return null
    }

    return (
      <Icon
        className={tw('mr-2 transition-transform', isExpanded && 'rotate-90')}
        name="chevron-right-filled"
        size="medium"
      />
    )
  }, [])

  // Check if horizontal scroll is active (for sticky column shadow)
  const [hasHorizontalScroll, setHasHorizontalScroll] = useState(false)

  // Track vertical scroll position to sync sticky columns
  const [scrollTop, setScrollTop] = useState(0)

  // Track hovered row index for group row hover effect
  const [hoveredRowIndex, setHoveredRowIndex] = useState<number | null>(null)

  useEffect(() => {
    const handleScroll = () => {
      if (parentRef.current) {
        setHasHorizontalScroll(parentRef.current.scrollLeft > 0)
        setScrollTop(parentRef.current.scrollTop)
      }
    }

    const element = parentRef.current

    element?.addEventListener('scroll', handleScroll)
    return () => element?.removeEventListener('scroll', handleScroll)
  }, [])

  // Track container width for flex column calculation
  useEffect(() => {
    const container = containerRef.current

    if (!container) return

    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerWidth(entry.contentRect.width)
      }
    })

    resizeObserver.observe(container)
    setContainerWidth(container.offsetWidth)

    return () => resizeObserver.disconnect()
  }, [])

  // Render header label (handles both string and ReactNode)
  const renderHeaderLabel = (label: string | ReactNode) => {
    if (typeof label === 'string') {
      return (
        <Typography variant="captionHl" color="grey600">
          {label}
        </Typography>
      )
    }

    return label
  }

  return (
    <div ref={containerRef} className="relative size-full overflow-hidden">
      {/* Sticky Columns Container */}
      {stickyColumns.length > 0 && (
        <div
          className={tw(
            'absolute left-0 top-0 z-20 overflow-hidden bg-white',
            hasHorizontalScroll && 'shadow-r',
          )}
          style={{ width: totalStickyWidth, height: '100%' }}
        >
          {/* Sticky Header Cells */}
          <div
            className="flex bg-white"
            style={{
              height: HEADER_ROW_HEIGHT,
              borderBottom: `1px solid ${theme.palette.grey[300]}`,
            }}
          >
            {stickyColumns.map((stickyCol, colIndex) => (
              <div
                key={`sticky-header-${stickyCol.key}`}
                style={{ width: getStickyColumnWidth(colIndex) }}
              >
                <TableInnerCell
                  align={stickyCol.align ?? 'left'}
                  className="min-h-10 px-4 text-grey-600"
                >
                  {isLoading ? (
                    <Skeleton className="w-3/4" variant="text" />
                  ) : (
                    renderHeaderLabel(stickyCol.label)
                  )}
                </TableInnerCell>
              </div>
            ))}
          </div>

          {/* Sticky Row Cells */}
          {rowVirtualizer.getVirtualItems().map((virtualRow) => {
            const row = visibleRows[virtualRow.index]
            const isGroup = row.type === 'group'
            const isExpanded = isGroup && expandedGroups[row.key]
            const isHovered = isGroup && hoveredRowIndex === virtualRow.index

            return (
              <div
                key={`sticky-row-${virtualRow.index}`}
                role={isGroup ? 'button' : undefined}
                tabIndex={isGroup ? 0 : -1}
                className={tw(
                  'absolute left-0 flex',
                  isGroup && 'cursor-pointer',
                  isHovered ? 'bg-grey-100' : 'bg-white',
                )}
                style={{
                  height: virtualRow.size,
                  width: totalStickyWidth,
                  top: HEADER_ROW_HEIGHT + virtualRow.start - scrollTop,
                  borderBottom: `1px solid ${theme.palette.grey[300]}`,
                }}
                onClick={() => handleRowClick(row)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault()
                    handleRowClick(row)
                  }
                }}
                onMouseEnter={() => isGroup && setHoveredRowIndex(virtualRow.index)}
                onMouseLeave={() => isGroup && setHoveredRowIndex(null)}
              >
                {stickyColumns.map((stickyCol, colIndex) => {
                  const helpers: ColumnHelpers = {
                    isExpanded: !!isExpanded,
                    ChevronIcon: createChevronIcon(row, !!isExpanded),
                  }

                  return (
                    <div
                      key={`sticky-cell-${virtualRow.index}-${stickyCol.key}`}
                      style={{ width: getStickyColumnWidth(colIndex) }}
                    >
                      <TableInnerCell align={stickyCol.align ?? 'left'} className="h-full px-4">
                        {isLoading ? (
                          <Skeleton className="w-3/4" variant="text" />
                        ) : (
                          stickyCol.content(row, helpers)
                        )}
                      </TableInnerCell>
                    </div>
                  )
                })}
              </div>
            )
          })}
        </div>
      )}

      {/* Scrollable Content Area */}
      <div
        ref={parentRef}
        className="size-full overflow-auto"
        style={{
          paddingLeft: totalStickyWidth,
        }}
      >
        <div
          className="relative"
          style={{
            width: columnVirtualizer.getTotalSize(),
            height: HEADER_ROW_HEIGHT + rowVirtualizer.getTotalSize(),
          }}
        >
          {/* Header Row */}
          <div className="sticky top-0 z-10 flex bg-white" style={{ height: HEADER_ROW_HEIGHT }}>
            {columnVirtualizer.getVirtualItems().map((virtualColumn) => {
              const column = scrollableColumns[virtualColumn.index]

              return (
                <div
                  key={`header-${virtualColumn.index}`}
                  className="absolute flex"
                  style={{
                    width: virtualColumn.size,
                    height: HEADER_ROW_HEIGHT,
                    left: virtualColumn.start,
                    borderBottom: `1px solid ${theme.palette.grey[300]}`,
                  }}
                >
                  <TableInnerCell align={column?.align ?? 'left'} className="min-h-10 w-full px-4">
                    {isLoading ? (
                      <Skeleton className="w-3/4" variant="text" />
                    ) : (
                      column && renderHeaderLabel(column.label)
                    )}
                  </TableInnerCell>
                </div>
              )
            })}
          </div>

          {/* Data Cells */}
          {rowVirtualizer.getVirtualItems().map((virtualRow) => {
            const row = visibleRows[virtualRow.index]
            const isGroup = row.type === 'group'
            const isExpanded = isGroup && expandedGroups[row.key]
            const isHovered = isGroup && hoveredRowIndex === virtualRow.index

            return (
              // eslint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/no-static-element-interactions
              <div
                key={`row-${virtualRow.index}`}
                ref={rowVirtualizer.measureElement}
                data-index={virtualRow.index}
                className={tw('absolute flex', isGroup && 'cursor-pointer')}
                style={{
                  minHeight: ROW_HEIGHT,
                  top: HEADER_ROW_HEIGHT + virtualRow.start,
                  width: columnVirtualizer.getTotalSize(),
                }}
                onClick={() => handleRowClick(row)}
                onMouseEnter={() => isGroup && setHoveredRowIndex(virtualRow.index)}
                onMouseLeave={() => isGroup && setHoveredRowIndex(null)}
              >
                {columnVirtualizer.getVirtualItems().map((virtualColumn) => {
                  const column = scrollableColumns[virtualColumn.index]
                  const helpers: ColumnHelpers = {
                    isExpanded: !!isExpanded,
                    ChevronIcon: createChevronIcon(row, !!isExpanded),
                  }

                  return (
                    <div
                      key={`cell-${virtualRow.index}-${virtualColumn.index}`}
                      className={tw('flex shrink-0', isHovered ? 'bg-grey-100' : 'bg-white')}
                      style={{
                        width: virtualColumn.size,
                        borderBottom: `1px solid ${theme.palette.grey[300]}`,
                      }}
                    >
                      <TableInnerCell align={column?.align ?? 'left'} className="w-full px-4">
                        {isLoading ? (
                          <Skeleton className="w-3/4" variant="text" />
                        ) : (
                          column && column.content(row, helpers)
                        )}
                      </TableInnerCell>
                    </div>
                  )
                })}
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

// Use forwardRef with generics
export const TableWithGroups = forwardRef(TableWithGroupsInner) as (
  props: TableWithGroupsProps & { ref?: React.ForwardedRef<TableWithGroupsRef> },
) => React.ReactElement
