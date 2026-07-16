import { FC } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { MenuPopper } from '~/styles'

import { ACTIONS_BLOCK_TEST_ID } from './mainHeaderTestIds'
import { MainHeaderAction, MainHeaderActionsConfig } from './types'

/** Returns true when a top-level action should be rendered. */
const isVisible = (action: MainHeaderAction): boolean => {
  if (action.type === 'action' || action.type === 'custom') return !action.hidden
  if (action.type === 'dropdown') return action.items.some((item) => !item.hidden)

  return true
}

/**
 * Renders the full actions block: skeleton during loading, action buttons otherwise.
 */
export const ActionsBlock: FC<{
  actions?: MainHeaderActionsConfig
  dataTest?: string
}> = ({ actions, dataTest }) => {
  if (actions?.loading) return <Skeleton variant="text" className="w-30" />

  const visibleActions = actions?.items.filter(isVisible)

  if (!visibleActions || visibleActions.length === 0) return null

  return (
    <div
      className="flex shrink-0 items-center justify-center gap-4"
      data-test={dataTest ?? ACTIONS_BLOCK_TEST_ID}
    >
      {visibleActions.map((action) => (
        <ActionItem key={action.label} action={action} />
      ))}
    </div>
  )
}

/** Renders a single action based on its type. */
const ActionItem: FC<{ action: MainHeaderAction }> = ({ action }) => {
  switch (action.type) {
    case 'dropdown': {
      const visibleItems = action.items.filter((item) => !item.hidden)

      return (
        <Popper
          PopperProps={{ placement: 'bottom-end' }}
          opener={
            <Button endIcon="chevron-down" data-test={action.dataTest}>
              {action.label}
            </Button>
          }
        >
          {({ closePopper }) => (
            <MenuPopper>
              {visibleItems.map((item) => {
                const button = (
                  <Button
                    key={item.label}
                    variant="quaternary"
                    align="left"
                    disabled={item.disabled}
                    danger={item.danger}
                    startIcon={item.startIcon}
                    endIcon={item.endIcon}
                    onClick={() => item.onClick(closePopper)}
                    data-test={item.dataTest}
                  >
                    {item.label}
                  </Button>
                )

                if (item.tooltip) {
                  return (
                    <Tooltip key={item.label} placement="left" title={item.tooltip}>
                      {button}
                    </Tooltip>
                  )
                }

                return button
              })}
            </MenuPopper>
          )}
        </Popper>
      )
    }

    case 'action':
      return (
        <Button
          variant={action.variant ?? 'secondary'}
          startIcon={action.startIcon}
          endIcon={action.endIcon}
          disabled={action.disabled}
          onClick={action.onClick}
          data-test={action.dataTest}
        >
          {action.label}
        </Button>
      )

    case 'custom':
      return <>{action.content}</>
  }
}
