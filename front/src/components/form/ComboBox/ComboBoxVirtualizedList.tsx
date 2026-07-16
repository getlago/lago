import { ReactElement } from 'react'

import { BaseComboBoxVirtualizedList } from './BaseComboBoxVirtualizedList'
import { ComboBoxProps } from './types'

export const GROUP_ITEM_KEY = 'combobox-group-by'

type ComboBoxVirtualizedListProps = {
  elements: ReactElement[]
} & Pick<ComboBoxProps, 'value'>

export const ComboBoxVirtualizedList = ({ elements, value }: ComboBoxVirtualizedListProps) => {
  return (
    <BaseComboBoxVirtualizedList elements={elements} value={value} groupItemKey={GROUP_ITEM_KEY} />
  )
}
