import MuiChip, { type ChipOwnProps } from '@mui/material/Chip'
import { Icon, IconColor, IconName, IconProps } from 'lago-design-system'

import { tw } from '~/styles/utils'

import { Button } from './Button'
import { Tooltip } from './Tooltip'
import { Typography, TypographyColor, TypographyProps } from './Typography'

import { ConditionalWrapper } from '../ConditionalWrapper'

enum ChipTypeEnum {
  primary = 'primary',
  secondary = 'secondary',
}

type ChipSize = 'small' | 'medium' | 'big'
type ChipType = keyof typeof ChipTypeEnum

type ChipProps = Omit<ChipOwnProps, 'color' | 'variant' | 'size' | 'deleteIcon' | 'icon'> & {
  className?: string
  color?: TypographyColor
  deleteIcon?: IconName
  deleteIconLabel?: string
  error?: boolean
  icon?: IconName
  iconColor?: IconColor
  iconSize?: IconProps['size']
  size?: ChipSize
  type?: ChipType
  variant?: TypographyProps['variant']
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  onDelete?: React.EventHandler<any>
}

export const Chip = ({
  className,
  color = 'textSecondary',
  deleteIcon,
  deleteIconLabel,
  error,
  icon,
  iconColor,
  iconSize,
  label,
  size = 'medium',
  type,
  variant,
  onDelete,
  ...chipProps
}: ChipProps) => {
  return (
    <MuiChip
      {...chipProps}
      tabIndex={onDelete ? -1 : undefined}
      className={tw(
        {
          'chip--error': !!error,
          'chip-size--small': size === 'small',
          'chip-size--big': size === 'big',
        },
        className,
      )}
      icon={
        icon ? (
          <Icon
            className="!m-0"
            name={icon}
            size={iconSize ?? 'small'}
            color={iconColor ?? 'dark'}
          />
        ) : undefined
      }
      label={
        <Typography variant={variant || 'captionHl'} color={!!error ? 'danger600' : color} noWrap>
          {label}
        </Typography>
      }
      variant={type === ChipTypeEnum.secondary ? 'outlined' : 'filled'}
      color="default"
      deleteIcon={
        <ConditionalWrapper
          condition={!!deleteIconLabel}
          invalidWrapper={(children) => <>{children}</>}
          validWrapper={(children) => (
            <Tooltip placement="top-end" title={deleteIconLabel}>
              {children}
            </Tooltip>
          )}
        >
          <Button
            danger={error}
            icon={deleteIcon || 'close-circle-filled'}
            onClick={onDelete}
            size="small"
            variant="quaternary"
          />
        </ConditionalWrapper>
      }
      onDelete={onDelete}
    />
  )
}
