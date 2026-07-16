import MuiAccordion from '@mui/material/Accordion'
import AccordionDetails from '@mui/material/AccordionDetails'
import AccordionSummary from '@mui/material/AccordionSummary'
import { TransitionProps } from '@mui/material/transitions'
import { ReactNode, useState } from 'react'

import { useInternationalization } from '~/hooks/core/useInternationalization'
import { NAV_HEIGHT, theme } from '~/styles'
import { tw } from '~/styles/utils'

import { Button } from './Button'
import { Tooltip } from './Tooltip'

enum AccordionSizeEnum {
  medium = 'medium',
  large = 'large',
}

type AccordionSize = keyof typeof AccordionSizeEnum

interface AccordionBaseProps {
  id?: string
  className?: string
  summary: ReactNode
  children: ReactNode | ((args: { isOpen: boolean }) => ReactNode)
  initiallyOpen?: boolean
  isOpen?: boolean
  onToggle?: (open: boolean) => void
  transitionProps?: TransitionProps
  onOpen?: () => void
}

interface AccordionCardProps extends AccordionBaseProps {
  variant?: 'card'
  size?: AccordionSize
  noContentMargin?: boolean
}

interface AccordionBorderlessProps extends AccordionBaseProps {
  variant?: 'borderless'
  size?: never
  noContentMargin?: never
}

type AccordionProps = AccordionCardProps | AccordionBorderlessProps

export const Accordion = ({
  id,
  className,
  summary,
  children,
  initiallyOpen = false,
  isOpen: controlledOpen,
  onToggle,
  size: localSize,
  noContentMargin = false,
  transitionProps = {},
  variant = 'card',
  onOpen,
  ...props
}: AccordionProps) => {
  const [uncontrolledOpen, setUncontrolledOpen] = useState(initiallyOpen)
  const isControlled = controlledOpen !== undefined
  const isOpen = isControlled ? controlledOpen : uncontrolledOpen
  const { translate } = useInternationalization()

  const getSize = () => {
    if (localSize) return localSize
    if (variant === 'card') return AccordionSizeEnum.medium
    return undefined
  }

  const size = getSize()

  const getPadding = () => {
    if (size === AccordionSizeEnum.medium) {
      return theme.spacing(4)
    }
    if (size === AccordionSizeEnum.large) {
      return theme.spacing(8)
    }
    return undefined
  }

  const getHeight = () => {
    if (size === AccordionSizeEnum.medium) {
      return NAV_HEIGHT
    }
    if (size === AccordionSizeEnum.large) {
      return 92
    }
    return undefined
  }

  return (
    <MuiAccordion
      id={id}
      expanded={isOpen}
      slotProps={{
        transition: {
          unmountOnExit: true,
          ...transitionProps,
        },
      }}
      className={tw(
        {
          // Ring the whole card (open or closed), not just the summary. The root is
          // rounded 12px via the MUI theme, so the ring follows the card outline.
          'border border-solid border-grey-400 has-[:focus-visible]:ring': variant === 'card',
          '!rounded-none': variant === 'borderless',
        },
        className,
      )}
      onChange={(_, expanded) => {
        const selection = window.getSelection()

        if (selection?.type !== 'Range') {
          if (!isControlled) setUncontrolledOpen(expanded)

          onToggle?.(expanded)
          if (expanded && !!onOpen) onOpen()
        }
      }}
      {...props}
    >
      <AccordionSummary
        className={tw(
          // Card variant rings the whole card (on the root, above); the borderless
          // variant has no card outline, so it keeps the ring on its summary.
          // Firefox draws its own blue UA focus outline on the focusable summary
          // div (role=button), which stacks on top of our box-shadow ring and
          // repaints incorrectly during the expand transition. Suppress it so only
          // our intentional ring shows.
          'select-text focus:bg-inherit focus:outline-none',
          {
            'h-23': size === AccordionSizeEnum.large,
            'h-18': size === AccordionSizeEnum.medium,
          },
          variant === 'card' && (isOpen ? 'rounded-t-xl' : 'rounded-xl'),
          {
            'hover:bg-grey-100 active:bg-grey-200': variant === 'card',
            'h-auto focus:rounded-lg focus-visible:ring': variant === 'borderless',
          },
        )}
        sx={{
          '& .MuiAccordionSummary-content': {
            padding: getPadding(),
            alignItems: variant === 'borderless' ? 'baseline' : 'center',
            height: getHeight(),
          },
        }}
      >
        <Tooltip
          className="mr-3"
          placement="top-start"
          title={translate(
            isOpen ? 'text_624aa732d6af4e0103d40e61' : 'text_624aa79870f60300a3c4d074',
          )}
        >
          <Button
            tabIndex={-1}
            data-test="open-charge"
            variant="quaternary"
            size="small"
            icon={isOpen ? 'chevron-down-filled' : 'chevron-right-filled'}
          />
        </Tooltip>
        {summary}
      </AccordionSummary>
      <AccordionDetails
        className={tw('flex flex-col', {
          'shadow-t': variant === 'card',
          'mt-6': variant === 'borderless',
          'p-4': size === AccordionSizeEnum.medium,
          'p-8': size === AccordionSizeEnum.large,
          'p-0': noContentMargin,
        })}
      >
        {typeof children === 'function' ? children({ isOpen }) : children}
      </AccordionDetails>
    </MuiAccordion>
  )
}
