import InputAdornment from '@mui/material/InputAdornment'
import { Icon } from 'lago-design-system'
import _omit from 'lodash/omit'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

import { ComboBoxInputProps } from './types'

import { TextInput } from '../TextInput'

export const ComboBoxInput = ({
  className,
  error,
  helperText,
  label,
  description,
  name,
  loading,
  searchQuery,
  placeholder,
  infoText,
  params,
  disableClearable,
  startAdornmentValue,
  hasValueSelected,
  variant = 'default',
  'data-test': dataTest,
}: ComboBoxInputProps) => {
  const { inputProps, InputProps, ...restParams } = params

  return (
    <TextInput
      variant={variant}
      onChange={(newVal) => {
        // needed because useAutocomplete expect a DOM onChange listener...
        inputProps.onChange({ target: { value: newVal } })
        searchQuery && searchQuery(newVal)
      }}
      className={tw('group/combobox-input', className)}
      name={name}
      placeholder={placeholder}
      label={label}
      description={description}
      error={error}
      infoText={infoText}
      autoComplete="off"
      helperText={helperText}
      data-test={dataTest}
      onBlur={() => {
        if (!hasValueSelected) {
          inputProps.onChange({ target: { value: '' } })
          searchQuery && searchQuery('')
        }
      }}
      InputProps={{
        ..._omit(InputProps, 'className'),
        endAdornment: (
          <InputAdornment position="end">
            {!disableClearable && (
              <Button
                // To make sure the "clear button" is displayed only on hover or focus
                className={tw(
                  'MuiAutocomplete-clearIndicator',
                  'hidden',
                  inputProps?.value &&
                    'MuiAutocomplete-clearIndicatorDirty group-hover/combobox-input:flex',
                )}
                disabled={restParams.disabled}
                size="small"
                icon="close-circle-filled"
                variant="quaternary"
                onClick={(e) => {
                  e.preventDefault()
                  e.stopPropagation()
                  inputProps.onChange({ target: { value: '' } })
                  searchQuery && searchQuery('')
                }}
              />
            )}
            {loading ? (
              <span className="flex size-6 items-center justify-center">
                <Icon name="processing" animation="spin" size="small" />
              </span>
            ) : (
              <Button
                variant="quaternary"
                size="small"
                icon="chevron-up-down"
                disabled={restParams.disabled}
                onClick={restParams.disabled ? undefined : () => inputProps.onMouseDown()}
              />
            )}
          </InputAdornment>
        ),
        startAdornment: startAdornmentValue && (
          <InputAdornment position="start">
            <Typography noWrap variant="body" color="grey700">
              <span className="mr-2">{startAdornmentValue}</span>
              <span>•</span>
            </Typography>
          </InputAdornment>
        ),
      }}
      inputProps={_omit(inputProps, 'className')}
      {...restParams}
    />
  )
}
