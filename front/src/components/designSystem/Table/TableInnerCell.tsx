import { tw } from 'lago-design-system'
import { PropsWithChildren } from 'react'

import { Align } from './types'

const TableInnerCell = ({
  align,
  children,
  className,
  minWidth,
  maxWidth,
  style,
  truncateOverflow,
}: PropsWithChildren & {
  align?: Align
  className?: string
  minWidth?: number
  maxWidth?: number
  style?: React.CSSProperties
  truncateOverflow?: boolean
}) => {
  return (
    <div
      className={tw(
        'lago-table-inner-cell',
        'flex items-center',
        {
          'justify-start': align === 'left',
          'justify-center': align === 'center',
          'justify-end': align === 'right',
          grid: !!truncateOverflow,
        },
        className,
      )}
      style={{
        minWidth: minWidth ? `${minWidth}px` : 'auto',
        maxWidth: maxWidth ? `${maxWidth}px` : 'auto',
        ...style,
      }}
    >
      {children}
    </div>
  )
}

export default TableInnerCell
