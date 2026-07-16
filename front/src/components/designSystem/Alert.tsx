import { cva } from 'class-variance-authority'
import { Icon, IconColor, IconName } from 'lago-design-system'
import { ReactNode } from 'react'

import { tw } from '~/styles/utils'

import { Button, ButtonProps as TButtonProps } from './Button'
import { Typography } from './Typography'

type AlertType = 'info' | 'success' | 'danger' | 'warning'

type AlertButtonProps = Partial<Omit<Omit<TButtonProps, 'variant' | 'icon'>, 'size'>> & {
  label: string
}

interface AlertProps {
  children: ReactNode
  type: AlertType
  ButtonProps?: AlertButtonProps
  className?: string
  fullWidth?: boolean
}

const getIcon = (type: AlertType): { name: IconName; color: IconColor } => {
  switch (type) {
    case 'success':
      return { name: 'validate-unfilled', color: 'success' }
    case 'warning':
      return { name: 'warning-unfilled', color: 'warning' }
    case 'danger':
      return { name: 'error-unfilled', color: 'error' }
    default:
      return { name: 'info-circle', color: 'info' }
  }
}

const alertStyles = cva('rounded-xl px-4', {
  variants: {
    backgroundColor: {
      info: 'bg-purple-100',
      success: 'bg-green-100',
      danger: 'bg-red-100',
      warning: 'bg-yellow-100',
    },
    isFullWidth: {
      true: 'w-full rounded-none',
    },
  },
})

export const Alert = ({
  ButtonProps: { label, ...ButtonProps } = {} as AlertButtonProps,
  children,
  className,
  fullWidth,
  type,
  ...props
}: AlertProps) => {
  const iconConfig = getIcon(type)

  return (
    <div
      className={tw(alertStyles({ backgroundColor: type, isFullWidth: fullWidth }), className)}
      data-test={`alert-type-${type}`}
      {...props}
    >
      <div className="flex flex-row items-center justify-between gap-4 py-4">
        <div className="flex flex-row items-center gap-4">
          <Icon name={iconConfig.name} color={iconConfig.color} />
          <Typography className="word-break-word" color="textSecondary">
            {children}
          </Typography>
        </div>
        {!!ButtonProps.onClick && !!label && (
          <Button variant="quaternary-dark" size="medium" {...ButtonProps}>
            {label}
          </Button>
        )}
      </div>
    </div>
  )
}
