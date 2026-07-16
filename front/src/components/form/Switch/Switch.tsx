import { cva } from 'class-variance-authority'
import { Icon } from 'lago-design-system'
import { MouseEvent, useEffect, useRef, useState } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { theme } from '~/styles'
import { tw } from '~/styles/utils'

enum LabelPositionEnum {
  left = 'left',
  right = 'right',
}

type LabelPosition = keyof typeof LabelPositionEnum
export interface SwitchProps {
  name: string
  disabled?: boolean
  checked?: boolean
  label?: string
  subLabel?: string
  labelPosition?: LabelPosition
  onChange?: (value: boolean, e: MouseEvent<HTMLDivElement>) => Promise<unknown> | void
  className?: string
  'data-test'?: string
}

const switchVariants = cva(
  'relative flex h-8 w-15 min-w-15 max-w-15 items-center justify-between rounded-[32px] px-1 transition-[background-color] duration-250 ease-in-out',
  {
    variants: {
      loading: {
        true: 'justify-center bg-blue',
      },
      checked: {
        true: 'bg-blue',
        false: 'bg-grey-200',
      },
      disabled: {
        true: 'bg-grey-100 text-grey-400',
      },
      focused: {
        true: '',
      },
    },
    compoundVariants: [
      {
        loading: false,
        disabled: false,
        className: 'cursor-pointer',
      },
      {
        disabled: false,
        checked: true,
        className: 'hover:bg-blue-700 active:hover:bg-blue-800',
      },
      {
        disabled: false,
        checked: false,
        className: 'hover:bg-grey-300 active:hover:bg-grey-400',
      },
      {
        disabled: false,
        focused: true,
        className: 'ring',
      },
    ],
  },
)

export const Switch = ({
  name,
  label,
  subLabel,
  disabled,
  checked,
  labelPosition = LabelPositionEnum.right,
  onChange,
  className,
  'data-test': dataTest,
  ...props
}: SwitchProps) => {
  const inputRef = useRef<HTMLInputElement>(null)
  const mountedRef = useRef(false)
  const [focused, setFocused] = useState(false)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    // This is for preventing setState on unmounted component
    mountedRef.current = true

    return () => {
      mountedRef.current = false
    }
  }, [])

  let circleFillColor = theme.palette.grey[500]

  if (disabled) {
    circleFillColor = theme.palette.grey[300]
  } else if (checked) {
    circleFillColor = theme.palette.common.white
  }

  return (
    // eslint-disable-next-line jsx-a11y/click-events-have-key-events
    <div
      data-test={dataTest}
      className={tw(
        'h-[initial] p-0',
        'flex items-center',
        {
          'flex-row-reverse': labelPosition === LabelPositionEnum.left,
          'flex-row': labelPosition === LabelPositionEnum.right,
          'cursor-text': disabled,
        },
        className,
      )}
      onClick={
        disabled
          ? undefined
          : (e) => {
              e.stopPropagation()

              if (onChange) {
                const res = onChange(!checked, e)

                if (res !== null && res instanceof Promise) {
                  let realLoading = true

                  // This is to prevent icon blink if the loading time is really small
                  setTimeout(() => {
                    if (mountedRef.current && realLoading) setLoading(true)
                  }, 100)
                  res.finally(() => {
                    if (mountedRef.current) {
                      realLoading = false
                      setLoading(false)
                    }
                  })
                }
              } else {
                inputRef.current?.click()
              }
            }
      }
    >
      <div
        className={tw(
          'switchField',
          switchVariants({
            loading: !!loading,
            disabled: !!disabled,
            checked: !!checked,
            focused: !!focused,
          }),
          'transition-all duration-250 ease-in-out',
        )}
      >
        <input
          readOnly
          {...props}
          ref={inputRef}
          disabled={disabled || loading}
          aria-label={name}
          checked={checked}
          type="checkbox"
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          className="absolute m-0 size-0 p-0 opacity-0"
        />
        {loading && (
          <Icon
            className="absolute left-5 opacity-100"
            animation="spin"
            name="processing"
            color="light"
          />
        )}
        <Typography
          className={tw('w-6 text-center', loading ? 'opacity-0' : 'opacity-100')}
          color={disabled ? 'inherit' : 'white'}
          variant="noteHl"
        >
          On
        </Typography>
        <Typography
          className={tw('w-6 text-center', loading ? 'opacity-0' : 'opacity-100')}
          color={disabled ? 'inherit' : 'disabled'}
          variant="noteHl"
        >
          Off
        </Typography>
        <svg
          width="24"
          height="24"
          viewBox="0 0 24 24"
          className={tw(
            'absolute',
            loading ? 'opacity-0' : 'opacity-100',
            checked ? 'left-8' : 'left-1',
          )}
        >
          <circle cx="12" cy="12" r="12" fill={circleFillColor} />
          <circle cx="12" cy="12" r="11" fill={theme.palette.common.white} />
        </svg>
      </div>
      {(!!label || !!subLabel) && (
        <>
          <div className="flex min-h-px w-3 min-w-3" />
          <div>
            {!!label && (
              <Typography color="textSecondary" className="text-left">
                {label}
              </Typography>
            )}
            {!!subLabel && (
              <Typography variant="caption" className="text-left">
                {subLabel}
              </Typography>
            )}
          </div>
        </>
      )}
    </div>
  )
}
Switch.displayName = 'Switch'
