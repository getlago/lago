import MUITable from '@mui/material/Table'
import MUITableBody from '@mui/material/TableBody'
import MUITableCell from '@mui/material/TableCell'
import MUITableHead from '@mui/material/TableHead'
import MUITableRow from '@mui/material/TableRow'
import { ReactNode } from 'react'

import { tw } from '~/styles/utils'

import TableCell from './TableCell'
import TableInnerCell from './TableInnerCell'
import type { Align } from './types'

import { Typography } from '../Typography'

export type PreviewTableColumn<T> = {
  key: string
  title: string | ReactNode
  content: (item: T, index: number) => ReactNode
  textAlign?: Align
  maxSpace?: boolean
  minWidth?: number
}

export interface PreviewTableProps<T> {
  name: string
  data: T[]
  columns: PreviewTableColumn<T>[]
  containerClassName?: string
  footer?: ReactNode
  // Controls the bottom divider per row. Defaults to `true` for every row.
  // Return `false` to visually group a row with the row below it (no separator).
  rowHasDivider?: (item: T, index: number) => boolean
}

const countMaxSpaceColumns = <T,>(columns: PreviewTableColumn<T>[]) =>
  columns.reduce((acc, column) => (column.maxSpace ? acc + 1 : acc), 0)

export const PreviewTable = <T,>({
  name,
  data,
  columns,
  containerClassName,
  footer,
  rowHasDivider,
}: PreviewTableProps<T>) => {
  const TABLE_ID = `preview-table-${name}`
  const maxSpaceColumns = countMaxSpaceColumns(columns)

  return (
    <div className={tw('w-0 min-w-full overflow-auto', containerClassName)}>
      <MUITable
        data-test={TABLE_ID}
        sx={{
          // Remove all default MUI cell borders
          '& td, & th': {
            border: 'none',
          },
          '& .lago-table-cell:first-of-type .lago-table-inner-cell': {
            paddingLeft: 0,
          },
          '& .lago-table-cell:last-of-type .lago-table-inner-cell': {
            paddingRight: 0,
          },
        }}
      >
        <MUITableHead>
          <MUITableRow className="border-b border-grey-300">
            {columns.map((column, i) => (
              <MUITableCell
                className={tw('lago-table-cell', 'w-auto whitespace-nowrap p-0')}
                key={`${TABLE_ID}-head-${i}`}
                align={column.textAlign || 'left'}
                style={{
                  width:
                    column.maxSpace && maxSpaceColumns > 0 ? `${100 / maxSpaceColumns}%` : 'auto',
                  minWidth: column.minWidth ? `${column.minWidth}px` : undefined,
                }}
                sx={{
                  '& > div': { paddingRight: '32px' },
                  '&:first-of-type > div': { paddingLeft: 0 },
                  '&:last-of-type > div': { paddingRight: 0 },
                }}
              >
                <TableInnerCell className="min-h-10" align={column.textAlign}>
                  <Typography variant="captionHl" color="grey600">
                    {column.title}
                  </Typography>
                </TableInnerCell>
              </MUITableCell>
            ))}
          </MUITableRow>
        </MUITableHead>

        <MUITableBody>
          {data.map((item, i) => (
            <MUITableRow key={`${TABLE_ID}-row-${i}`} data-test={`${TABLE_ID}-row-${i}`}>
              {columns.map((column, j) => (
                <TableCell
                  key={`${TABLE_ID}-cell-${i}-${j}`}
                  align={column.textAlign || 'left'}
                  maxSpace={column.maxSpace ? 100 / maxSpaceColumns : undefined}
                  hideBottomBorder={!(rowHasDivider?.(item, i) ?? true)}
                  className="align-top"
                >
                  <TableInnerCell align={column.textAlign}>
                    {column.content(item, i)}
                  </TableInnerCell>
                </TableCell>
              ))}
            </MUITableRow>
          ))}
        </MUITableBody>
      </MUITable>
      {footer}
    </div>
  )
}
