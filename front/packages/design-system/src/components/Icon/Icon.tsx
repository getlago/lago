import { cva, VariantProps } from 'class-variance-authority'

import { tw } from '~/lib'

import { ALL_ICONS } from './mapping'

const iconStyles = cva('text-inherit', {
  variants: {
    animation: {
      spin: 'animate-spin',
      pulse: 'animate-pulse',
    },
    color: {
      primary: 'text-blue-600',
      success: 'text-green-600',
      error: 'text-red-600',
      warning: 'text-yellow-600',
      info: 'text-purple-600',
      light: 'text-white',
      black: 'text-grey-700',
      dark: 'text-grey-600',
      input: 'text-grey-500',
      disabled: 'text-grey-400',
      skeleton: 'text-grey-100',
    },
    size: {
      xsmall: 'size-2 min-w-2',
      small: 'size-3 min-w-3',
      medium: 'size-4 min-w-4',
      large: 'size-6 min-w-6',
    },
  },
})

export type IconName = keyof typeof ALL_ICONS
export type IconColor =
  | 'success'
  | 'error'
  | 'warning'
  | 'info'
  | 'light'
  | 'black'
  | 'dark'
  | 'skeleton'
  | 'disabled'
  | 'input'
  | 'primary'

type IconVariantProps = VariantProps<typeof iconStyles>

export interface IconProps extends IconVariantProps {
  name: IconName
  className?: string
  onClick?: () => void | void | Promise<void>
}

export const Icon = ({
  name,
  size = 'medium',
  color,
  className,
  animation,
  onClick,
}: IconProps) => {
  const SVGIcon = ALL_ICONS[name]

  return (
    <SVGIcon
      title={`${name}/${size}`}
      data-test={`${name}/${size}`}
      className={tw(iconStyles({ animation, color, size }), className, {
        'cursor-pointer': !!onClick,
      })}
      onClick={onClick}
    />
  )
}
