import Autocomplete, { createFilterOptions } from '@mui/material/Autocomplete'
import _sortBy from 'lodash/sortBy'
import { HTMLAttributes, JSXElementConstructor, useEffect, useMemo, useRef } from 'react'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'

import { COMBOBOX_CONFIG } from './comboBoxConfig'
import { ComboBoxInput } from './ComboBoxInput'
import { ComboBoxItemWrapper } from './ComboBoxItemWrapper'
import { ComboboxList } from './ComboboxList'
import { ComboBoxPopperFactory } from './ComboBoxPopperFactory'
import { ComboBoxData, ComboBoxProps } from './types'

export const ComboBox = ({
  data: rawData,
  loading,
  value,
  disabled,
  allowAddValue = false,
  addValueProps,
  sortValues = true,
  label,
  description,
  infoText,
  placeholder,
  name,
  helperText,
  error,
  PopperProps,
  className,
  containerClassName = '',
  searchQuery,
  emptyText,
  disableClearable = false,
  renderGroupHeader,
  virtualized = true,
  renderGroupInputStartAdornment,
  onOpen,
  onChange,
  variant = 'default',
  'data-test': dataTest,
}: ComboBoxProps) => {
  const { translate } = useInternationalization()

  const { debouncedSearch, isLoading } = useDebouncedSearch(searchQuery, loading)

  // By default, we want to sort `options` alphabetically (by value)
  const data = useMemo(() => {
    return (
      sortValues ? _sortBy(rawData, (item: ComboBoxData) => item.label ?? item.value) : rawData
    ) as ComboBoxData[]
  }, [rawData, sortValues])

  // we need a ref to the previous data (see the following `useEffect()`)
  //  to compute if some options were deleted and update the `value` accordingly
  const prevRawDataRef = useRef<ComboBoxData[] | undefined>()

  useEffect(() => {
    prevRawDataRef.current = rawData
  }, [rawData])
  const prevRawData = prevRawDataRef.current

  // when `data` gets updated, make sure that if the current value is not belonging to
  //   a deleted option
  // N.B: we compute the diff to not delete a "freeForm" value
  useEffect(() => {
    if (prevRawData && data) {
      const deletedOptions = prevRawData.filter(
        ({ value: oldVal }) => !data.find(({ value: newVal }) => oldVal === newVal),
      )

      if (deletedOptions.find(({ value: deletedValue }) => value === deletedValue)) {
        onChange('')
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rawData])

  const filter = createFilterOptions<ComboBoxData>({
    matchFrom: allowAddValue ? 'start' : 'any',
    stringify: (option) => option.label || option.value,
    trim: true,
  })
  const startAdornmentValue = useMemo(() => {
    if (!renderGroupInputStartAdornment || !value) return undefined

    const foundGroup = data.find((item) => item.value === value)?.group

    return foundGroup ? renderGroupInputStartAdornment[foundGroup] : undefined
  }, [data, renderGroupInputStartAdornment, value])

  return (
    <Autocomplete
      className={containerClassName}
      options={data}
      disabled={disabled}
      onOpen={() => {
        if (isLoading) return
        onOpen?.()
      }}
      renderInput={(params) => {
        return (
          <ComboBoxInput
            disableClearable={disableClearable}
            className={className}
            error={error}
            hasValueSelected={!!value}
            loading={!!searchQuery && isLoading}
            searchQuery={debouncedSearch}
            helperText={helperText}
            label={label}
            description={description}
            infoText={infoText}
            name={name}
            placeholder={placeholder}
            startAdornmentValue={startAdornmentValue}
            params={params}
            variant={variant}
            data-test={dataTest}
          />
        )
      }}
      onChange={(_event, newValue) => {
        if (typeof newValue === 'string') {
          onChange(newValue)
        } else if (newValue && !newValue.disabled) {
          onChange(newValue?.value)
        } else {
          onChange('')
        }
      }}
      // pass `null` to force Autocomplete in controlled mode
      //  (`undefined` value at initial render puts Autocomplete in uncontrolled mode)
      value={value || null}
      loading={isLoading}
      loadingText={
        <div className="my-4 flex flex-col gap-8">
          {[1, 2, 3].map((i) => (
            <div
              className="mx-2 flex items-center justify-between px-4"
              key={`combobox-loading-item-${i}`}
            >
              <Skeleton variant="circular" size="small" className="mr-4" />
              <Skeleton variant="text" />
            </div>
          ))}
        </div>
      }
      noOptionsText={emptyText ?? translate('text_623b3acb8ee4e000ba87d082')}
      selectOnFocus={allowAddValue}
      clearOnBlur
      handleHomeEndKeys={allowAddValue}
      freeSolo={allowAddValue}
      isOptionEqualToValue={(option, val) => {
        return option?.value === (val as unknown as string)
      }}
      renderOption={({ key, ...props }, option, state) => {
        return (
          <ComboBoxItemWrapper
            comboboxProps={props}
            id={`option-${option.value}`}
            key={`option-${option.value}-${key}`}
            option={option}
            selected={state.selected}
            virtualized={virtualized}
            addValueRedirectionUrl={option.addValueRedirectionUrl}
            {...props}
          />
        )
      }}
      filterOptions={(options, params) => {
        const filtered = searchQuery
          ? options
          : filter(
              options,
              params.inputValue !== value
                ? params
                : { getOptionLabel: params.getOptionLabel, inputValue: '' },
            )

        // Suggest the creation of a new value
        if (filtered.length === 0 && !emptyText && allowAddValue && addValueProps) {
          filtered.push({
            value: params.inputValue,
            label: addValueProps.label || `Add "${params.inputValue}"`,
            addValueRedirectionUrl: addValueProps.redirectionUrl,
            customValue: true,
          })
        }

        return filtered
      }}
      ListboxComponent={
        ComboboxList as unknown as JSXElementConstructor<HTMLAttributes<HTMLElement>>
      }
      ListboxProps={{
        // @ts-expect-error we're using props from ComboboxList which are not recognized by the Autocomplete MUI component
        value,
        renderGroupHeader,
        virtualized,
        style: {
          maxHeight: `${COMBOBOX_CONFIG.getListboxMaxHeight()}px`,
        },
      }}
      PopperComponent={ComboBoxPopperFactory(PopperProps)}
      getOptionDisabled={(option) => !!option?.disabled}
      getOptionLabel={(option) => {
        const optionForString =
          typeof option === 'string' ? data.find(({ value: val }) => val === option) : null

        if (typeof option === 'string') {
          if (optionForString) {
            return optionForString.label || optionForString.value
          }
          return option
        }
        return option.label || option.value
      }}
    />
  )
}
