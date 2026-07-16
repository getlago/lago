import { LazyQueryExecFunction } from '@apollo/client'
import type { AutocompleteRenderInputParams } from '@mui/material/Autocomplete'
import type { PopperProps as MuiPopperProps } from '@mui/material/Popper'
import { ReactNode } from 'react'

import { Exact, InputMaybe } from '~/generated/graphql'
import { UseDebouncedSearch } from '~/hooks/useDebouncedSearch'

import { TextInputProps } from '../TextInput'

export interface BasicComboBoxData {
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

export interface ComboboxDataGrouped extends Omit<BasicComboBoxData, 'group'> {
  group: string
}

export type ComboBoxData = BasicComboBoxData | ComboboxDataGrouped

interface BasicComboboxProps extends Omit<ComboBoxInputProps, 'params' | 'searchQuery'> {
  loading?: boolean
  disabled?: boolean
  value?: string
  data?: BasicComboBoxData[]
  sortValues?: boolean
  allowAddValue?: boolean
  emptyText?: string
  virtualized?: boolean
  disableClearable?: boolean
  renderGroupInputStartAdornment?: { [key: string]: string }
  PopperProps?: Pick<MuiPopperProps, 'placement'> & {
    displayInDialog?: boolean
    offset?: string
  }
  addValueProps?: {
    label: string
    redirectionUrl?: string
  }
  renderGroupHeader?: never
  onChange: (value: string) => unknown
  onOpen?: () => void
  searchQuery?: LazyQueryExecFunction<
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    any,
    Exact<{
      page?: InputMaybe<number> | undefined
      limit?: InputMaybe<number> | undefined
      searchTerm?: InputMaybe<string> | undefined
    }>
  >
  containerClassName?: string
  'data-test'?: string
}

interface GroupedComboboxProps extends Omit<BasicComboboxProps, 'data' | 'renderGroupHeader'> {
  data?: ComboboxDataGrouped[]
  renderGroupHeader?: Record<string, ReactNode>
}

export type ComboBoxProps = BasicComboboxProps | GroupedComboboxProps

export type ComboBoxInputProps = Pick<
  TextInputProps,
  | 'error'
  | 'label'
  | 'description'
  | 'name'
  | 'placeholder'
  | 'helperText'
  | 'className'
  | 'infoText'
  | 'startAdornmentValue'
  | 'variant'
> & {
  disableClearable?: boolean
  hasValueSelected?: boolean
  loading?: boolean
  searchQuery?: ReturnType<UseDebouncedSearch>['debouncedSearch']
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  params: Omit<AutocompleteRenderInputParams, 'inputProps'> & { inputProps: any }
  'data-test'?: string
}
