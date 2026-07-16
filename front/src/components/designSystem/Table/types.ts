import { IconName } from 'lago-design-system'
import { ReactNode } from 'react'

import { TooltipProps } from '../Tooltip'

export type Align = 'left' | 'center' | 'right'

export type ActionItem<T> = {
  title: string | ReactNode
  onAction: (item: T) => void | Promise<void>
  startIcon?: IconName
  endIcon?: IconName
  disabled?: boolean
  tooltip?: string
  tooltipListener?: boolean
  tooltipPlacement?: TooltipProps['placement']
  dataTest?: string
}

export type ActionColumn<T> = (item: T) => Array<ActionItem<T> | null> | ReactNode
