import _get from 'lodash/get'
import { ReactNode } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

const CELL_HEIGHT = 'h-12'

type DataType<T> = T & { disabledDelete?: boolean }

interface ChargeTableColumnMapKey<T> {
  title?: ReactNode
  size?: number
  content: ReactNode | ((row: DataType<T>, index: number) => ReactNode)
  mapKey?: never // Use this if you only want to render the property itself
  onClick?: () => unknown // On column header click
}

interface ChargeTableColumnContent {
  title: ReactNode
  size?: number
  content?: never
  mapKey: string // Use this if you only want to render the property itself
  onClick?: () => unknown // On column header click
}

type ChargeTableColumnProps<T> = ChargeTableColumnMapKey<T> | ChargeTableColumnContent

interface ChargeTableProps<T> {
  name: string // this is to allow to have several table on a same page (no duplicated keys)
  columns: ChargeTableColumnProps<T>[]
  data: DataType<T>[]
  className?: string
  onDeleteRow?: (row: DataType<T>, index: number) => unknown
  deleteTooltipContent?: string
  headerCellClassName?: string
}

export const ChargeTable = <T extends Record<string, unknown>>({
  name,
  className,
  columns,
  data,
  onDeleteRow,
  deleteTooltipContent,
  headerCellClassName,
}: ChargeTableProps<T>) => {
  const { translate } = useInternationalization()

  const hasHeader = columns?.some(({ title }) => title)

  return (
    <table
      className={tw('border-spacing-0 border-l border-t border-solid border-grey-300', className)}
    >
      {/* Header */}
      {hasHeader && (
        <thead>
          <tr className={tw(CELL_HEIGHT)}>
            {columns?.map(({ title, size = 124, onClick }, i) => {
              const sizeStyle = {
                width: `${size}px`,
                minWidth: `${size}px`,
                maxWidth: `${size}px`,
              }

              return (
                <th
                  className={tw(
                    CELL_HEIGHT,
                    'border-b border-r border-solid border-grey-300 text-left',
                    headerCellClassName,
                  )}
                  style={sizeStyle}
                  key={`table-${name}-head-${i}`}
                  onClick={() => onClick && onClick()}
                >
                  {title && title}
                </th>
              )
            })}
          </tr>
        </thead>
      )}
      <tbody>
        {data?.map((row, i) => {
          return (
            <tr
              className={tw('group/row relative', CELL_HEIGHT)}
              key={`table-${name}-head-${i}`}
              data-test={`row-${i}`}
            >
              <>
                {columns.map(({ content, mapKey, size = 124 }, j) => {
                  const sizeStyle = {
                    width: `${size}px`,
                    minWidth: `${size}px`,
                    maxWidth: `${size}px`,
                  }

                  return (
                    <td
                      className={tw(
                        CELL_HEIGHT,
                        'relative border-b border-r border-solid border-grey-300 p-0',
                      )}
                      style={sizeStyle}
                      key={`table-${name}-cell-${i}-${j}`}
                    >
                      {onDeleteRow && !row.disabledDelete && j === 0 && (
                        <div
                          className={tw(
                            'absolute z-10 hidden w-fit rounded-lg bg-white',
                            'group-hover/row:left-0 group-hover/row:top-0 group-hover/row:flex group-hover/row:-translate-x-3 group-hover/row:translate-y-3',
                          )}
                        >
                          <Tooltip
                            title={
                              deleteTooltipContent ?? translate('text_62793bbb599f1c01522e9239')
                            }
                            placement="top-start"
                          >
                            <Button
                              variant="tertiary"
                              size="small"
                              icon="trash"
                              onClick={() => onDeleteRow(row, i)}
                            />
                          </Tooltip>
                        </div>
                      )}
                      {mapKey && (
                        <Typography variant="body">{_get(row, mapKey) as string}</Typography>
                      )}
                      {!mapKey && typeof content === 'function' && content(row, i)}
                      {!mapKey && typeof content !== 'function' && content}
                    </td>
                  )
                })}
              </>
            </tr>
          )
        })}
      </tbody>
    </table>
  )
}
