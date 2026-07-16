import MUITableCell, { type TableCellProps } from '@mui/material/TableCell'
import { PropsWithChildren } from 'react'

import { theme } from '~/styles'
import { tw } from '~/styles/utils'

import { PADDING_SPACING_RIGHT_PX } from './const'

const TableCell = ({
  children,
  className,
  hasPlaceholderDisplayed,
  hideBottomBorder,
  isBlurred,
  maxSpace,
  tdCellClassName,
  ...props
}: PropsWithChildren &
  TableCellProps & {
    className?: string
    isBlurred?: boolean
    hasPlaceholderDisplayed?: boolean
    hideBottomBorder?: boolean
    maxSpace?: number
    tdCellClassName?: string
  }) => {
  return (
    <MUITableCell
      className={tw('lago-table-cell', 'w-auto whitespace-nowrap p-0', className, tdCellClassName)}
      style={{
        width: maxSpace ? `${maxSpace}%` : 'auto',
        borderBottom:
          hasPlaceholderDisplayed || hideBottomBorder
            ? 'none'
            : `1px solid ${theme.palette.grey[300]}`,
        boxShadow: isBlurred ? theme.shadows[7] : 'none',
      }}
      sx={{
        '& > div': {
          // Every column keeps a 4px left gutter so edge-aligned header titles and
          // cell content (and the copy button's -4px overhang, see Table.tsx) clear
          // the cell boundary. The first column's left padding is owned by the
          // table's containerSize rule (clamped to a 4px min); last column drops
          // its right padding.
          paddingLeft: '4px',
          paddingRight: `${PADDING_SPACING_RIGHT_PX}px`,
        },
        '&:last-of-type > div': {
          paddingRight: 0,
        },
      }}
      {...props}
    >
      {children}
    </MUITableCell>
  )
}

export default TableCell
