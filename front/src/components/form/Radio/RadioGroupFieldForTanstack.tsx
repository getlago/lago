import Stack from '@mui/material/Stack'
import { Icon } from 'lago-design-system'
import { FC } from 'react'

import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useFieldContext } from '~/hooks/forms/formContext'
import { tw } from '~/styles/utils'

import { Radio, RadioProps } from './Radio'

interface RadioGroupFieldOption {
  value: string | number | boolean
  label?: string
  sublabel?: string
  disabled?: boolean
}

interface RadioGroupFieldProps {
  label?: string
  optionLabelVariant?: RadioProps['labelVariant']
  infoText?: string
  description?: string
  optionsGapSpacing?: number
  options: RadioGroupFieldOption[]
  disabled?: boolean
}

const RadioGroupField: FC<RadioGroupFieldProps> = ({
  options,
  disabled,
  label,
  optionLabelVariant,
  optionsGapSpacing = 2,
  description,
  infoText,
}) => {
  const field = useFieldContext<string | number | boolean>()

  return (
    <div>
      {!!label && (
        <div className="flex justify-between">
          {label && (
            <div
              className={tw(
                'flex items-center justify-between',
                !!infoText && '*:first-child:mr-1',
              )}
            >
              <Typography variant="captionHl" color="textSecondary" component="legend">
                {label}
              </Typography>
              {!!infoText && (
                <Tooltip className="flex h-5 items-end" placement="top-start" title={infoText}>
                  <Icon name="info-circle" />
                </Tooltip>
              )}
            </div>
          )}
        </div>
      )}
      {!!description && (
        <Typography className="mb-4" variant="caption">
          {description}
        </Typography>
      )}

      <Stack width="100%" gap={optionsGapSpacing}>
        {options.map(
          ({ value: optionValue, label: optionLabel, disabled: optionDisabled, ...props }) => {
            return (
              <Radio
                {...props}
                name={field.name}
                disabled={disabled || optionDisabled}
                key={`radio-group-field-${optionValue}`}
                label={optionLabel ?? String(optionValue)}
                labelVariant={optionLabelVariant}
                value={optionValue}
                checked={field.state.value === optionValue}
                onChange={(value) => field.handleChange(value)}
                data-test={`radio-group-field-${optionValue}`}
              />
            )
          },
        )}
      </Stack>
    </div>
  )
}

export default RadioGroupField
