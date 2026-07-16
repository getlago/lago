import { isBoolean } from 'lodash'
import { forwardRef, ReactNode, useId, useRef, useState } from 'react'

import { Typography, TypographyProps } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

import { RadioIcon } from './RadioIcon'

export interface RadioProps {
  name?: string
  value: string | number | boolean
  checked: boolean
  disabled?: boolean
  label?: string | ReactNode
  labelVariant?: TypographyProps['variant']
  sublabel?: string | ReactNode
  onChange?: (value: string | number | boolean) => void
}

export const Radio = forwardRef<HTMLLabelElement, RadioProps>(
  (
    { name, checked, label, labelVariant, sublabel, disabled, value, onChange }: RadioProps,
    ref,
  ) => {
    const componentId = useId()

    const inputRef = useRef<HTMLInputElement>(null)
    const [focused, setFocused] = useState(false)

    return (
      <label
        ref={ref}
        htmlFor={componentId}
        className={tw('flex w-full items-start', !disabled && 'group/radio-icon cursor-pointer')}
      >
        <div className="mr-3 flex items-start pt-1">
          <input
            readOnly
            id={componentId}
            ref={inputRef}
            disabled={disabled}
            aria-label={name}
            name={name}
            {...(isBoolean(value) ? { checked: value } : { value: value })}
            type="radio"
            onClick={() => onChange && onChange(value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            className="absolute m-0 size-0 p-0 opacity-0"
          />
          <RadioIcon checked={checked} disabled={disabled} focused={focused} />
        </div>
        <div className="w-full">
          <Typography
            variant={labelVariant || 'bodyHl'}
            color={disabled ? 'disabled' : 'textSecondary'}
            className={tw(!disabled && 'cursor-pointer')}
            component={(labelProps) => <label htmlFor={componentId} {...labelProps} />}
          >
            {label}
          </Typography>
          {!!label &&
            (typeof sublabel === 'string' ? (
              <Typography variant="caption" color={disabled ? 'disabled' : 'grey600'}>
                {sublabel}
              </Typography>
            ) : (
              sublabel
            ))}
        </div>
      </label>
    )
  },
)

Radio.displayName = 'Radio'
