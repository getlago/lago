import { cva } from 'class-variance-authority'

import { tw } from '~/styles/utils'

import { AvatarSize, avatarSizeStyles } from './Avatar'
import { TypographyProps } from './Typography'

import { ConditionalWrapper } from '../ConditionalWrapper'

type SkeletonVariant =
  | 'connectorAvatar' // squared with rounded corners
  | 'userAvatar' // rounded
  | 'text'
  | 'circular'

type SkeletonColor = 'dark' | 'light'

interface SkeletonConnectorProps {
  className?: string
  color?: SkeletonColor
  size: AvatarSize
  textVariant?: never
  variant: Extract<SkeletonVariant, 'userAvatar' | 'connectorAvatar' | 'circular'>
}

interface SkeletonGenericProps {
  className?: string
  color?: SkeletonColor
  size?: never
  textVariant?: TypographyProps['variant']
  variant: Extract<SkeletonVariant, 'text'>
}

const textWrapperStyles = cva('flex w-full max-w-full items-center', {
  variants: {
    textVariant: {
      headline: 'h-8',
      subhead1: 'h-6',
      subhead2: 'h-6',
      bodyHl: 'h-6',
      body: 'h-6',
      captionHl: 'h-6',
      caption: 'h-6',
      captionCode: 'h-6',
      noteHl: 'h-4',
      note: 'h-4',
      button: '', // here to satisfy the type
      inherit: '', // here to satisfy the type
    },
  },
})

const skeletonStyles = cva('animate-pulse bg-grey-100', {
  variants: {
    size: avatarSizeStyles,
    variant: {
      connectorAvatar: '', // defined in avatarSizeStyles
      userAvatar: '', // defined in avatarSizeStyles
      text: 'h-3 w-full rounded-3xl',
      circular: 'rounded-full',
    },
    color: {
      dark: 'bg-grey-300',
      light: 'bg-grey-100',
    },
    defaultVariants: {
      color: 'light',
    },
  },
})

export const Skeleton = ({
  className,
  color,
  size,
  textVariant = 'body',
  variant,
}: SkeletonConnectorProps | SkeletonGenericProps) => {
  return (
    <ConditionalWrapper
      condition={!!textVariant && variant === 'text'}
      validWrapper={(children) => (
        <div className={tw(textWrapperStyles({ textVariant }), className)}>{children}</div>
      )}
      invalidWrapper={(children) => <>{children}</>}
    >
      <div className={tw(skeletonStyles({ variant, color, size }), className)} />
    </ConditionalWrapper>
  )
}
