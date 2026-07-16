import { ReactNode } from 'react'

import { Tooltip } from '~/components/designSystem/Tooltip'
import { useFieldError } from '~/hooks/forms/useFieldError'

interface FieldErrorTooltipProps {
  children: ReactNode
  title?: string
}

export const FieldErrorTooltip = ({ children, title }: FieldErrorTooltipProps) => {
  const errorMessage = useFieldError({ noBoolean: true, translateErrors: true, firstOnly: true })
  const displayTitle = title || errorMessage

  return (
    <Tooltip placement="top" title={displayTitle || ''} disableHoverListener={!errorMessage}>
      {children}
    </Tooltip>
  )
}
