import { ReactNode } from 'react'

export type DropdownItem = {
  name: string
  value: string
  label?: string | ReactNode
  isActive: boolean
  onButtonClick: () => void
}
