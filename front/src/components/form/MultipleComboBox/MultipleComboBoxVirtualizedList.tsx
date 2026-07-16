import { ReactElement } from 'react'

import { MultipleComboBoxProps } from './types'

import { BaseComboBoxVirtualizedList } from '../ComboBox/BaseComboBoxVirtualizedList'

export const MULTIPLE_GROUP_ITEM_KEY = 'multiple-comboBox-group-by'

type MultipleComboBoxVirtualizedListProps = {
  elements: ReactElement[]
} & Pick<MultipleComboBoxProps, 'value'>

export const MultipleComboBoxVirtualizedList = ({
  elements,
  value,
}: MultipleComboBoxVirtualizedListProps) => {
  return (
    <BaseComboBoxVirtualizedList
      elements={elements}
      value={value}
      groupItemKey={MULTIPLE_GROUP_ITEM_KEY}
    />
  )
}
