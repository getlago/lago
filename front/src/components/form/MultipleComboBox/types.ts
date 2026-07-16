import type { AutocompleteRenderInputParams } from '@mui/material/Autocomplete'
import type { PopperProps as MuiPopperProps } from '@mui/material/Popper'
import { ReactNode } from 'react'

import { TextInputProps } from '../TextInput'

export interface BasicMultipleComboBoxData {
  value: string
  selected?: boolean
  label?: string
  labelNode?: ReactNode
  description?: string
  disabled?: boolean
  customValue?: boolean
  group?: never
  addValueRedirectionUrl?: string
}

export interface MultipleComboBoxDataGrouped extends Omit<BasicMultipleComboBoxData, 'group'> {
  group: string
}

export type MultipleComboBoxData = BasicMultipleComboBoxData | MultipleComboBoxDataGrouped

interface BasicMultipleComboBoxProps extends Omit<
  MultipleComboBoxInputProps,
  'params' | 'searchQuery'
> {
  loading?: boolean
  disabled?: boolean
  freeSolo?: boolean
  showOptionsOnlyWhenTyping?: boolean
  value?: MultipleComboBoxData[]
  data?: BasicMultipleComboBoxData[]
  sortValues?: boolean
  forcePopupIcon?: boolean
  hideTags?: boolean
  emptyText?: string
  virtualized?: boolean
  limitTags?: number
  disableClearable?: boolean
  PopperProps?: Pick<MuiPopperProps, 'placement'> & {
    displayInDialog?: boolean
    offset?: string
  }
  renderGroupHeader?: never
  onChange: (value: (BasicMultipleComboBoxData | MultipleComboBoxDataGrouped)[]) => void
}

interface GroupedMultipleComboBoxProps extends Omit<
  BasicMultipleComboBoxProps,
  'data' | 'renderGroupHeader'
> {
  data: MultipleComboBoxDataGrouped[]
  renderGroupHeader?: Record<string, ReactNode>
}

export type MultipleComboBoxProps = BasicMultipleComboBoxProps | GroupedMultipleComboBoxProps

type MultipleComboBoxInputProps = Pick<
  TextInputProps,
  | 'error'
  | 'label'
  | 'name'
  | 'placeholder'
  | 'helperText'
  | 'className'
  | 'infoText'
  | 'startAdornmentValue'
  | 'variant'
> & {
  disableClearable?: boolean
  disableCloseOnSelect?: boolean
  hasValueSelected?: boolean
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  params: Omit<AutocompleteRenderInputParams, 'inputProps'> & { inputProps: any }
}
