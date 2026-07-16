import MuiTooltip, { type TooltipProps as MuiTooltipProps } from '@mui/material/Tooltip'
import { forwardRef, ReactNode, useCallback, useState } from 'react'

import { tw } from '~/styles/utils'

export interface TooltipProps extends Pick<
  MuiTooltipProps,
  'placement' | 'title' | 'onClose' | 'disableHoverListener' | 'PopperProps'
> {
  children?: ReactNode
  className?: string
  maxWidth?: string
}

export const Tooltip = forwardRef<HTMLDivElement, TooltipProps>(
  ({ children, disableHoverListener, className, maxWidth = '320px', ...props }, ref) => {
    const [isOpen, setIsOpen] = useState(false)

    const handleOpen = useCallback(() => {
      if (!disableHoverListener) {
        setIsOpen(true)
      }
    }, [disableHoverListener])

    const handleClose = useCallback(() => setIsOpen(false), [])

    return (
      <div
        className={tw(className)}
        ref={ref}
        onMouseEnter={handleOpen}
        onMouseLeave={handleClose}
        onFocus={handleOpen}
        onBlur={handleClose}
      >
        <MuiTooltip
          componentsProps={{
            tooltip: {
              style: {
                maxWidth: maxWidth,
              },
            },
          }}
          open={isOpen}
          enterDelay={400}
          leaveDelay={0}
          {...props}
        >
          {/* eslint-disable-next-line */}
          <div onClick={handleClose}>{children}</div>
        </MuiTooltip>
      </div>
    )
  },
)

Tooltip.displayName = 'Tooltip'
