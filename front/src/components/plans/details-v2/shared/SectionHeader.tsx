import { IconName } from 'lago-design-system'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'

type SectionHeaderAction = {
  label: string
  onClick: () => void
  hidden?: boolean
  disabled?: boolean
  startIcon?: IconName
  endIcon?: IconName
  dataTest?: string
}

export type SectionHeaderProps = {
  title: string
  description?: string
  action?: SectionHeaderAction
}

export const SectionHeader = ({ title, description, action }: SectionHeaderProps) => {
  const showAction = !!action && !action.hidden

  return (
    <div className="flex items-start justify-between gap-4">
      <div className="flex flex-col gap-1">
        <Typography variant="subhead1" color="grey700">
          {title}
        </Typography>
        {!!description && (
          <Typography variant="caption" color="grey600">
            {description}
          </Typography>
        )}
      </div>
      {showAction && (
        <Button
          variant="inline"
          data-test={action.dataTest}
          onClick={action.onClick}
          disabled={action.disabled}
          startIcon={action.startIcon}
          endIcon={action.endIcon}
        >
          {action.label}
        </Button>
      )}
    </div>
  )
}
