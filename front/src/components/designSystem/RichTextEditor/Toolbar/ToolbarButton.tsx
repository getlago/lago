import { forwardRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'

type ToolbarButtonProps = {
  isActive: boolean
  children: React.ReactNode
  testId: string
  tooltip?: string
  isPopper?: boolean
  isDisabled?: boolean
  onClick?: () => void
}

const ToolbarButton = forwardRef<HTMLButtonElement, ToolbarButtonProps>(
  ({ isActive, onClick, children, testId, tooltip, isPopper = false, isDisabled = false }, ref) => {
    const buttonContent = () => (
      <Button
        ref={ref}
        data-test={testId}
        variant={isActive ? 'secondary' : 'quaternary'}
        onClick={onClick}
        endIcon={isPopper ? 'chevron-down' : undefined}
        disabled={isDisabled}
      >
        {children}
      </Button>
    )

    if (tooltip) {
      return (
        <Tooltip title={tooltip} placement="top">
          {buttonContent()}
        </Tooltip>
      )
    }

    return buttonContent()
  },
)

ToolbarButton.displayName = 'ToolbarButton'

export default ToolbarButton
