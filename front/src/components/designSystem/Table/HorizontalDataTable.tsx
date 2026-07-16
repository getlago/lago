import { useVirtualizer } from '@tanstack/react-virtual'
import { Icon } from 'lago-design-system'
import { ReactNode, useCallback, useEffect, useMemo, useRef, useState } from 'react'

import { useAnalyticsState } from '~/components/analytics/AnalyticsStateContext'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { tw } from '~/styles/utils'

import { Typography } from '../Typography'

const DEFAULT_COLUMN_WIDTH = 160
const DEFAULT_LEFT_COLUMN_WIDTH = 120

type DataItem = {
  [key: string]: unknown
}

export enum InitScrollTo {
  START,
  END,
}

export type RowType = 'header' | 'data' | 'group'
type DotPrefix<T extends string> = T extends '' ? '' : `.${T}`
type DotNestedKeys<T> = (
  T extends object
    ? { [K in Exclude<keyof T, symbol>]: `${K}${DotPrefix<DotNestedKeys<T[K]>>}` }[Exclude<
        keyof T,
        symbol
      >]
    : ''
) extends infer D
  ? Extract<D, string>
  : never

type TRows<T> = {
  content: (item: T) => ReactNode
  key: DotNestedKeys<T> | string
  label: string | ReactNode
  type: RowType
  groupKey?: string
}[]

type HorizontalDataTableProps<T> = {
  rows: TRows<T>
  columnIdPrefix?: string
  columnWidth?: number
  data?: T[]
  leftColumnWidth?: number
  loading?: boolean
  initScrollTo?: InitScrollTo
}

const getRowHeight = (rowType: RowType, isCollapsed?: boolean) => {
  if (isCollapsed) {
    return 0
  }

  if (rowType === 'header') return 40

  return 48
}

export const HorizontalDataTable = <T extends DataItem>({
  columnIdPrefix = 'column-',
  columnWidth = DEFAULT_COLUMN_WIDTH,
  data,
  leftColumnWidth = DEFAULT_LEFT_COLUMN_WIDTH,
  loading,
  rows,
  initScrollTo = InitScrollTo.END,
}: HorizontalDataTableProps<T>) => {
  // Get the hover and click state from context
  const { clickedDataIndex, setHoverDataIndex, setClickedDataIndex } = useAnalyticsState()
  const parentRef = useRef(null)
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>({})

  const columnVirtualizer = useVirtualizer({
    count: loading ? 12 : data?.length || 0,
    horizontal: true,
    paddingStart: leftColumnWidth,
    estimateSize: () => columnWidth,
    getScrollElement: () => parentRef.current,
  })

  const buildColumnId = useCallback(
    (index: number): string => `${columnIdPrefix}${index}`,
    [columnIdPrefix],
  )

  useEffect(() => {
    if (!loading && !!data?.length) {
      // On init, scroll to the last element
      if (initScrollTo === InitScrollTo.END) {
        return columnVirtualizer.scrollToIndex((data?.length || 1) - 1)
      }

      return columnVirtualizer.scrollToIndex(0)
    }
  }, [columnVirtualizer, data?.length, loading, initScrollTo])

  useEffect(() => {
    if (typeof clickedDataIndex === 'number') {
      columnVirtualizer.scrollToIndex(clickedDataIndex, { behavior: 'smooth', align: 'center' })
    }
  }, [clickedDataIndex, columnVirtualizer])

  const tableHeight = useMemo(
    () =>
      rows.reduce(
        (acc, item) =>
          acc + getRowHeight(item.type as RowType, !!(item.groupKey && !openGroups[item.groupKey])),
        0,
      ),
    [rows, openGroups],
  )

  const onRowClick = (item: { type: RowType; key: string }) => {
    if (item.type !== 'group') {
      return
    }

    setOpenGroups({
      ...openGroups,
      [item.key]: !openGroups[item.key],
    })
  }

  return (
    <div className="relative w-full">
      {!!rows.length && (
        <div
          className={tw('absolute left-0 top-0 z-10 bg-white', {
            'shadow-r': !!columnVirtualizer?.scrollOffset,
          })}
          style={{ width: leftColumnWidth }}
        >
          {rows
            .filter((row) => (row?.groupKey ? openGroups[row.groupKey] : true))
            .map((item, index) => (
              // eslint-disable-next-line jsx-a11y/click-events-have-key-events
              <div
                role="button"
                tabIndex={item.type === 'group' ? 0 : -1}
                key={`left-column-item-${index}`}
                className={tw('flex items-center shadow-b', {
                  'shadow-y': index === 0,
                  'pl-6': !!item.groupKey && item.type !== 'group',
                  'pointer-events-none': item.type !== 'group',
                  'cursor-pointer': item.type === 'group',
                })}
                style={{ height: getRowHeight(item.type) }}
                onClick={() => onRowClick(item)}
              >
                {!!loading && <Skeleton className="w-5/6" variant="text" />}
                {!loading && (
                  <>
                    {item.type === 'group' && (
                      <Icon
                        className={tw('mr-2', {
                          'rotate-180': item.type === 'group' && openGroups[item.key],
                        })}
                        name={'chevron-down-filled'}
                        size="small"
                      />
                    )}

                    {typeof item.label === 'string' ? (
                      <Typography
                        variant={item.type === 'header' ? 'captionHl' : 'bodyHl'}
                        color={item.type === 'header' ? 'grey600' : 'grey700'}
                      >
                        {item.label}
                      </Typography>
                    ) : (
                      <>{item.label}</>
                    )}
                  </>
                )}
              </div>
            ))}
        </div>
      )}

      <div
        ref={parentRef}
        className="w-full overflow-x-auto no-scrollbar"
        style={{
          height: tableHeight,
        }}
        onMouseEnter={
          !loading
            ? () => {
                if (typeof clickedDataIndex === 'number') {
                  setClickedDataIndex(undefined)
                }
              }
            : undefined
        }
      >
        <div
          className="relative h-full"
          style={{
            width: `${columnVirtualizer.getTotalSize()}px`,
          }}
          onMouseLeave={
            !loading
              ? () => {
                  setHoverDataIndex(undefined)
                }
              : undefined
          }
        >
          {columnVirtualizer.getVirtualItems().map((virtualColumn) => (
            <div
              id={buildColumnId(virtualColumn.index)}
              key={`key-column-${virtualColumn.index}`}
              className={tw('absolute', {
                'bg-grey-100': virtualColumn.index === clickedDataIndex,
                'hover:bg-grey-100 focus:bg-grey-100': !loading,
              })}
              style={{
                width: `${virtualColumn.size}px`,
                left: `${virtualColumn.start}px`,
              }}
              onMouseEnter={
                !loading
                  ? () => {
                      setHoverDataIndex(virtualColumn.index)
                    }
                  : undefined
              }
            >
              {rows
                .filter((row) => (row?.groupKey ? openGroups[row.groupKey] : true))
                .map((row, index) => {
                  return (
                    <div
                      key={`key-column-${virtualColumn.index}-item-${index}-row-${row.key}`}
                      className={tw('flex items-center justify-end px-1 shadow-b', {
                        'shadow-y': index === 0,
                      })}
                      style={{ height: getRowHeight(row.type) }}
                    >
                      {!!loading && <Skeleton className="w-5/6 justify-end" variant="text" />}
                      {!!data?.length && !loading && row.content(data[virtualColumn.index])}
                    </div>
                  )
                })}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
