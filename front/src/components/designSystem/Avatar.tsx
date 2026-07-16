import { cva, cx, VariantProps } from 'class-variance-authority'
import { colors } from 'lago-configs/tailwind'
import { Icon, IconName, IconProps } from 'lago-design-system'
import { FC, ReactNode } from 'react'

import { tw } from '~/styles/utils'

import { Typography } from './Typography'

export type AvatarSize = 'tiny' | 'small' | 'intermediate' | 'medium' | 'big' | 'large'
type AvatarUserCompanyVariant = 'user' | 'company'
export type AvatarConnectorVariant = 'connector' | 'connector-full'

interface AvatarConnectorProps {
  variant: AvatarConnectorVariant
  children: ReactNode | string
  size?: AvatarSize
  initials?: never
  identifier?: never
  className?: string
}

export interface AvatarGenericProps {
  variant: AvatarUserCompanyVariant
  identifier: string
  initials?: string // Note that only the first initial will be displayed in small size
  size?: AvatarSize
  children?: never
  className?: string
}

const mapTypographyVariant = (size: AvatarSize) => {
  switch (size) {
    case 'tiny':
    case 'small':
    case 'intermediate':
      return 'noteHl'
    case 'large':
      return 'subhead1'
    default:
      return 'bodyHl'
  }
}

// The need here is to get a color from the AVATAR_PALETTE according to
// an identifier (can be an id, fullname, company name... whaterver)
const getBackgroundColorKey = (identifier?: string): keyof typeof colors.avatar | null => {
  if (!identifier) return null

  // Get the sum of the UTF-16 code for each char
  const charcodeSum = identifier.split('').reduce((acc, char) => {
    acc = acc + (char.codePointAt(0) ?? 0)
    return acc
  }, 0)

  const colorKeys = Object.keys(colors.avatar) as Array<keyof typeof colors.avatar>
  const colorIndex = charcodeSum % colorKeys.length

  return colorKeys[colorIndex]
}

export const avatarSizeStyles: Record<AvatarSize, string> = {
  tiny: cx('w-2 min-w-2 h-2 rounded'),
  small: cx('w-4 min-w-4 h-4 rounded'),
  intermediate: cx('w-6 min-w-6 h-6 rounded-lg'),
  medium: cx('w-8 min-w-8 h-8 rounded-xl'),
  big: cx('w-10 min-w-10 h-10 rounded-xl'),
  large: cx('w-16 min-w-16 h-16 rounded-xl'),
}

const avatarStyles = cva(
  'relative flex items-center justify-center [&>img]:size-full [&>img]:rounded-[inherit] [&>img]:object-cover',
  {
    variants: {
      size: avatarSizeStyles,
      rounded: {
        false: 'rounded-full',
      },
      backgroundColor: {
        default: 'bg-grey-100',
        orange: 'bg-avatar-orange',
        brown: 'bg-avatar-brown',
        green: 'bg-avatar-green',
        turquoise: 'bg-avatar-turquoise',
        blue: 'bg-avatar-blue',
        indigo: 'bg-avatar-indigo',
        grey: 'bg-avatar-grey',
        pink: 'bg-avatar-pink',
      },
      color: {
        default: 'text-grey-600',
        white: 'text-white',
      },
    },
    defaultVariants: {
      size: 'big',
      backgroundColor: 'default',
      color: 'default',
    },
  },
)

export const Avatar = ({
  variant,
  size = 'big',
  identifier,
  initials,
  children,
  className,
}: AvatarGenericProps | AvatarConnectorProps) => {
  if (variant === 'connector' || variant === 'connector-full') {
    return (
      <div
        className={tw(
          avatarStyles({ size, rounded: true }),
          variant === 'connector-full' && '[&>svg]:size-full',
          className,
        )}
        data-test={`${variant}/${size}`}
      >
        {children}
      </div>
    )
  }

  const getContent = () => {
    // Remove all non-alphanumeric characters
    const text = initials || identifier || ''
    const sanitizedText = text.replaceAll(/[^a-zA-Z0-9]/g, '')

    const cursor = size === 'small' || size === 'intermediate' ? 1 : 2

    return (
      <Typography color="inherit" variant={mapTypographyVariant(size)}>
        {sanitizedText.substring(0, cursor).toUpperCase()}
      </Typography>
    )
  }

  return (
    <div
      className={tw(
        avatarStyles({
          size,
          backgroundColor: getBackgroundColorKey(identifier) ?? 'default',
          color: identifier ? 'white' : 'default',
          rounded: variant === 'company',
        }),
        className,
      )}
      data-test={`${variant}/${size}`}
    >
      {getContent()}
    </div>
  )
}

const avatarBadgeStyles = cva(
  'absolute bottom-0 right-0 flex items-center justify-center rounded-full',
  {
    variants: {
      size: {
        big: 'size-4',
        large: 'size-6',
      },
      color: {
        primary: 'bg-blue-600',
        success: 'bg-green-600',
        error: 'bg-red-600',
        warning: 'bg-yellow-600',
        info: 'bg-purple-600',
        light: 'bg-white',
        black: 'bg-grey-700',
        dark: 'bg-grey-600',
        input: 'bg-grey-500',
        disabled: 'bg-grey-400',
        skeleton: 'bg-grey-100',
      },
    },
  },
)

export const AvatarBadge: FC<{ icon: IconName } & VariantProps<typeof avatarBadgeStyles>> = ({
  icon,
  color,
  size = 'big',
}) => {
  let iconSize: IconProps['size']

  if (size === 'big') iconSize = 'xsmall'
  if (size === 'large') iconSize = 'small'

  return (
    <div className={tw(avatarBadgeStyles({ color, size }))}>
      <Icon name={icon} size={iconSize} color="light" />
    </div>
  )
}
