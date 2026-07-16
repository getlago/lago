import { ChangeEvent, useId, useRef, useState } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import { CheckboxIcon } from './CheckboxIcon'

export interface CheckboxProps {
  canBeIndeterminate?: boolean
  className?: string
  disabled?: boolean
  error?: string
  label: string | React.ReactNode | null
  sublabel?: string | React.ReactNode
  name?: string
  value?: boolean | undefined
  onChange?: (event: ChangeEvent<HTMLInputElement>, checked: boolean) => void
  'data-test'?: string
}

export const Checkbox = ({
  canBeIndeterminate,
  className,
  disabled,
  error,
  label,
  sublabel,
  name,
  value,
  onChange,
  'data-test': dataTest,
}: CheckboxProps) => {
  const componentId = useId()
  const { translate } = useInternationalization()

  const inputRef = useRef<HTMLInputElement>(null)
  const [focused, setFocused] = useState(false)

  return (
    <label
      htmlFor={componentId}
      data-test={dataTest || `checkbox-${name}`}
      className={tw('flex flex-col', !disabled && 'cursor-pointer', className)}
    >
      <div className={tw('mx-0 flex items-start align-middle *:leading-7')}>
        <div className="mr-3 inline-flex items-center pt-1">
          <input
            id={componentId}
            aria-checked={value === undefined ? 'mixed' : value}
            aria-labelledby={typeof label === 'string' ? label : name}
            type="checkbox"
            readOnly
            ref={inputRef}
            disabled={disabled}
            checked={!!value}
            onChange={(e) => {
              if (disabled || !onChange) return

              if (value === undefined) {
                onChange(e, true)
              } else {
                onChange(e, (e.target as HTMLInputElement).checked)
              }
            }}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            className="absolute m-0 size-0 p-0 opacity-0"
          />
          <CheckboxIcon
            value={value}
            canBeIndeterminate={canBeIndeterminate}
            disabled={disabled}
            focused={focused}
          />
        </div>
        <div>
          {typeof label === 'string' && (
            <Typography color={disabled ? 'disabled' : 'textSecondary'}>{label}</Typography>
          )}
          {label && typeof label !== 'string' && label}
          {!!label &&
            (typeof sublabel === 'string' ? (
              <Typography variant="caption" color={disabled ? 'disabled' : 'grey600'}>
                {sublabel}
              </Typography>
            ) : (
              sublabel
            ))}
        </div>
      </div>
      {!!error && (
        <Typography className="mt-1" variant="caption" color="danger600">
          {translate(error)}
        </Typography>
      )}
    </label>
  )
}
