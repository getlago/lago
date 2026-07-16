import { ReactNode } from 'react'

interface ConditionalWrapperProps {
  condition: boolean
  validWrapper: (children: ReactNode) => JSX.Element | null
  invalidWrapper: (children: ReactNode) => JSX.Element | null
  children: ReactNode
}

export const ConditionalWrapper = ({
  condition,
  validWrapper,
  invalidWrapper,
  children,
}: ConditionalWrapperProps) => {
  return condition ? validWrapper(children) : invalidWrapper(children)
}
