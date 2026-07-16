import { Icon } from 'lago-design-system'

import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

import { TabButton } from './TabButton'

type ValueType = string | number | boolean

interface ButtonSelectorOption {
  value: ValueType
  label?: string
  disabled?: boolean
}

export interface ButtonSelectorProps {
  className?: string
  label?: string
  description?: string
  options: ButtonSelectorOption[]
  value?: ValueType
  error?: string
  infoText?: string
  helperText?: string
  disabled?: boolean
  onChange: (value: ValueType) => void
}

export const ButtonSelector = ({
  className,
  label,
  description,
  options,
  value,
  error,
  infoText,
  helperText,
  disabled,
  onChange,
  ...props
}: ButtonSelectorProps) => {
  return (
    <div className={tw('flex flex-col gap-1', className)} {...props}>
      {!!label && (
        <div className="flex items-center gap-1">
          <Typography variant="captionHl" color="textSecondary">
            {label}
          </Typography>
          {!!infoText && (
            <Tooltip placement="top-start" title={infoText}>
              <Icon name="info-circle" />
            </Tooltip>
          )}
        </div>
      )}
      {!!description && (
        <Typography variant="caption" className="mb-3">
          {description}
        </Typography>
      )}
      <div className="flex flex-row flex-wrap items-center gap-3">
        {options.map(({ value: optionValue, label: optionLabel, disabled: optionDisabled }) => {
          return (
            <TabButton
              disabled={disabled || optionDisabled}
              key={`button-selector-${optionValue}`}
              title={optionLabel ?? optionValue}
              active={value === optionValue}
              onClick={() => onChange(optionValue)}
              data-test={`button-selector-${optionValue}`}
            />
          )
        })}
      </div>
      {(!!error || !!helperText) && (
        <Typography variant="caption" color={error ? 'danger600' : 'textPrimary'}>
          {error || helperText}
        </Typography>
      )}
    </div>
  )
}
