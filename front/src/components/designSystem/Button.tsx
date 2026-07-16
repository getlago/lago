import MuiButton, { type ButtonProps as MuiButtonProps } from '@mui/material/Button'
import { cva } from 'class-variance-authority'
import { Icon, IconName } from 'lago-design-system'
import { forwardRef, MouseEvent, useEffect, useRef, useState } from 'react'

import { tw } from '~/styles/utils'

enum ButtonVariantEnum {
  primary = 'primary',
  secondary = 'secondary',
  tertiary = 'tertiary',
  quaternary = 'quaternary',
  'quaternary-dark' = 'quaternary-dark',
  'quaternary-light' = 'quaternary-light',
  inline = 'inline',
}

type ButtonSize = 'small' | 'medium' | 'large'
export type ButtonVariant = keyof typeof ButtonVariantEnum
type MuiVariant = 'text' | 'outlined' | 'contained'
type ButtonAlign = 'center' | 'left' | 'space-between'
type MuiColor =
  'inherit' | 'primary' | 'secondary' | 'success' | 'error' | 'info' | 'warning' | undefined

export interface SimpleButtonProps extends Pick<
  MuiButtonProps,
  'id' | 'disabled' | 'children' | 'onClick' | 'fullWidth' | 'tabIndex'
> {
  size?: ButtonSize
  variant?: ButtonVariant
  danger?: boolean
  icon?: never
  align?: ButtonAlign
  endIcon?: IconName
  startIcon?: IconName
  loading?: boolean // If the `onClick` function returns a promise, the loading state will be handled automatically
  className?: string
  inheritColor?: boolean // This will only work for quaternary buttons
  fitContent?: boolean
  type?: 'button' | 'submit' | 'reset'
}
interface ButtonIconProps extends Omit<
  SimpleButtonProps,
  'icon' | 'size' | 'endIcon' | 'startIcon' | 'children'
> {
  size?: ButtonSize
  icon: IconName // If used, the button will only display an icon (no matter if there's a children)
  endIcon?: never
  startIcon?: never
  children?: never
}

export type ButtonProps = ButtonIconProps | SimpleButtonProps

// Map the names used in our design system to match the MUI ones
const mapProperties = (
  variant: ButtonVariant,
  inheritColor: boolean,
): {
  color: MuiColor
  variant: MuiVariant
  sx?: { borderColor: MuiColor }
} => {
  switch (variant) {
    case ButtonVariantEnum.secondary:
      return {
        color: 'inherit',
        variant: 'contained',
      }
    case ButtonVariantEnum.tertiary:
      return {
        color: 'inherit',
        variant: 'outlined',
        sx: {
          borderColor: 'inherit',
        },
      }
    case ButtonVariantEnum.quaternary:
    case ButtonVariantEnum['quaternary-light']:
    case ButtonVariantEnum['quaternary-dark']:
      return {
        color: inheritColor ? 'inherit' : undefined,
        variant: 'text',
      }
    case ButtonVariantEnum.inline:
      return {
        color: 'primary',
        variant: 'text',
      }
    case ButtonVariantEnum.primary:
    default:
      return {
        color: 'primary',
        variant: 'contained',
      }
  }
}

const buttonVariants = cva('min-w-[unset] whitespace-nowrap [&>svg]:cursor-pointer', {
  variants: {
    fitContent: {
      true: 'w-fit',
    },
    align: {
      center: 'justify-center',
      left: 'justify-start',
      'space-between': 'justify-between',
    },
  },
  defaultVariants: {
    align: 'center',
    fitContent: false,
  },
})

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      align = 'center',
      variant = ButtonVariantEnum.primary,
      size = 'medium',
      danger = false,
      disabled = false,
      icon,
      startIcon,
      className,
      endIcon,
      fitContent = false,
      loading = false,
      children,
      inheritColor,
      onClick,
      type = 'button',
      ...props
    }: ButtonProps,
    ref,
  ) => {
    const [isLoading, setIsLoading] = useState(false)
    const mountedRef = useRef(false)

    useEffect(() => {
      // This is for preventing set state on unmounted component
      mountedRef.current = true

      return () => {
        mountedRef.current = false
      }
    }, [])

    const localLoading = loading || isLoading

    const handleClick = async (e: MouseEvent<HTMLButtonElement>) => {
      if (onClick && !localLoading) {
        const res = onClick(e)

        if (res !== null && (res as unknown) instanceof Promise) {
          let realLoading = true

          // This is to prevent icon blink if the loading time is really small
          setTimeout(() => {
            if (mountedRef.current && realLoading) setIsLoading(true)
          }, 100)
          ;(res as unknown as Promise<unknown>).finally(() => {
            if (mountedRef.current) {
              realLoading = false
              setIsLoading(false)
            }
          })
        }
      }
    }

    return (
      <MuiButton
        className={tw(
          {
            'button-danger': danger,
            'button-icon-only': icon && !children,
            'button-quaternary-light': variant === 'quaternary-light',
            'button-quaternary-dark': variant === 'quaternary-dark',
            'button-inline': variant === 'inline',
          },
          buttonVariants({
            align,
            fitContent,
          }),
          className,
        )}
        onClick={handleClick}
        size={size}
        data-test="button"
        disableElevation
        disableRipple
        disabled={disabled}
        type={type}
        ref={ref}
        endIcon={
          localLoading && !icon && !startIcon ? (
            <Icon animation="spin" name="processing" />
          ) : (
            endIcon && <Icon name={endIcon} />
          )
        }
        startIcon={
          localLoading && !icon && !!startIcon ? (
            <Icon animation="spin" name="processing" />
          ) : (
            startIcon && <Icon name={startIcon} />
          )
        }
        {...mapProperties(variant, !!inheritColor)}
        {...props}
      >
        {icon && localLoading && <Icon animation="spin" name="processing" />}
        {icon && !localLoading && <Icon name={icon} />}
        {!icon && children}
      </MuiButton>
    )
  },
)

Button.displayName = 'Button'
