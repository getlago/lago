import { cva } from 'class-variance-authority'
import { ConditionalWrapper, Icon, IconName } from 'lago-design-system'
import { ReactElement, useState } from 'react'

import { tw } from '~/styles/utils'

import { Avatar } from './Avatar'
import { Button } from './Button'
import { Tooltip } from './Tooltip'
import { Typography } from './Typography'

export const SELECTOR_END_CONTENT_TEST_ID = 'selector-end-content'
export const SELECTOR_HOVER_ACTIONS_TEST_ID = 'selector-hover-actions'

interface SelectorProps {
  title: string
  subtitle?: string
  icon: ReactElement | IconName
  /** Right-side content. Hidden on hover when hoverActions is provided. */
  endContent?: ReactElement
  /** Content shown on hover, replacing endContent. */
  hoverActions?: ReactElement
  titleFirst?: boolean
  selected?: boolean
  className?: string
  fullWidth?: boolean
  disabled?: boolean
  onClick?: () => Promise<void> | unknown
  'data-test'?: string
}

export interface SelectorActionItem {
  /** Icon name. Defaults to 'dots-horizontal' */
  icon?: IconName
  /** Tooltip text. When absent, no tooltip is rendered. */
  tooltipCopy?: string
  onClick: (e: React.MouseEvent) => void
  disabled?: boolean
}

const selectorVariants = cva('flex h-18 items-center rounded-xl border p-4', {
  variants: {
    selected: {
      true: 'border-blue-600 bg-blue-100',
      false: 'border-grey-400 bg-white',
    },
    disabled: {
      true: 'cursor-not-allowed bg-grey-100',
      false: 'cursor-default',
    },
    clickable: {
      true: 'cursor-pointer focus-not-active:ring',
    },
    fullWidth: {
      true: 'w-full',
      false: 'min-w-full max-w-full md:min-w-[calc(50%-32px)] md:max-w-[calc(50%-32px)]',
    },
  },
  compoundVariants: [
    {
      selected: false,
      clickable: true,
      disabled: false,
      class: 'active:bg-grey-200 hover-not-active:bg-grey-100',
    },
    {
      selected: true,
      clickable: true,
      disabled: false,
      class: 'hover-not-active:bg-blue-200',
    },
  ],
  defaultVariants: {
    fullWidth: true,
    selected: false,
  },
})

export const Selector = ({
  title,
  subtitle,
  icon,
  endContent,
  hoverActions,
  titleFirst = true,
  className,
  selected = false,
  fullWidth = true,
  disabled = false,
  onClick,
  'data-test': dataTest,
}: SelectorProps) => {
  const [loading, setLoading] = useState(false)
  const clickable = !!onClick && !loading && !disabled

  return (
    <div
      role="button"
      tabIndex={clickable ? 0 : -1}
      data-test={dataTest}
      className={tw(
        'group/selector',
        selectorVariants({
          selected,
          disabled,
          clickable,
          fullWidth,
        }),
        className,
      )}
      onKeyDown={(e) => {
        if (e.key === ' ' || e.key === 'Enter') {
          e.preventDefault()
          e.currentTarget.click()
        }
      }}
      onClick={async () => {
        if (loading || disabled) return
        const result = !!onClick && onClick()

        if (result instanceof Promise) {
          setLoading(true)
          await result
          setLoading(false)
        }
      }}
    >
      <div className="mr-3">
        {typeof icon === 'string' ? (
          <Avatar size="big" variant="connector">
            <Icon color="dark" name={icon} />
          </Avatar>
        ) : (
          icon
        )}
      </div>
      <div
        className={tw('mr-4 flex flex-1 overflow-hidden text-left', {
          'flex-col': titleFirst,
          'flex-col-reverse': !titleFirst,
        })}
      >
        <Typography variant="bodyHl" color={disabled ? 'disabled' : 'textSecondary'} noWrap>
          {title}
        </Typography>
        <Typography variant="caption" color={disabled ? 'disabled' : undefined} noWrap>
          {subtitle}
        </Typography>
      </div>
      {loading && <Icon animation="spin" color="primary" name="processing" />}
      {!loading && endContent && (
        <div
          data-test={SELECTOR_END_CONTENT_TEST_ID}
          className={tw('flex items-center gap-3', hoverActions && 'group-hover/selector:hidden')}
        >
          {endContent}
        </div>
      )}
      {!loading && hoverActions && (
        <div
          data-test={SELECTOR_HOVER_ACTIONS_TEST_ID}
          className="hidden items-center gap-3 group-hover/selector:flex"
        >
          {hoverActions}
        </div>
      )}
    </div>
  )
}

export const SelectorActions = ({ actions }: { actions: SelectorActionItem[] }) => (
  <>
    {actions.map(({ icon = 'dots-horizontal', tooltipCopy, onClick, disabled }, index) => (
      <ConditionalWrapper
        key={index}
        condition={!!tooltipCopy}
        validWrapper={(children) => (
          <Tooltip title={tooltipCopy ?? ''} placement="top-end">
            {children}
          </Tooltip>
        )}
        invalidWrapper={(children) => <>{children}</>}
      >
        <Button
          icon={icon}
          variant="quaternary"
          disabled={disabled}
          onClick={(e) => {
            e.stopPropagation()
            onClick?.(e)
          }}
        />
      </ConditionalWrapper>
    ))}
  </>
)
