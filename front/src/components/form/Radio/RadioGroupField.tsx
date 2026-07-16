import Stack from '@mui/material/Stack'
import { FormikProps } from 'formik'
import { Icon } from 'lago-design-system'
import { FC } from 'react'

import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

import { RadioProps } from './Radio'
import { RadioField, RadioFieldProps } from './RadioField'

interface RadioGroupFieldProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formikProps: FormikProps<any>
  name: string
  label?: string
  optionLabelVariant?: RadioProps['labelVariant']
  infoText?: string
  description?: string
  optionsGapSpacing?: number
  options: Pick<RadioFieldProps, 'value' | 'label' | 'disabled' | 'sublabel'>[]
  disabled?: boolean
}

export const RadioGroupField: FC<RadioGroupFieldProps> = ({
  name,
  formikProps,
  options,
  disabled,
  label,
  optionLabelVariant,
  optionsGapSpacing = 2,
  description,
  infoText,
}) => {
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
              <RadioField
                {...props}
                name={name}
                formikProps={formikProps}
                disabled={disabled || optionDisabled}
                key={`radio-group-field-${optionValue}`}
                label={optionLabel ?? optionValue}
                labelVariant={optionLabelVariant}
                value={optionValue}
                data-test={`radio-group-field-${optionValue}`}
              />
            )
          },
        )}
      </Stack>
    </div>
  )
}
