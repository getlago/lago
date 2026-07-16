import { ReactNode } from 'react'

export type PurchaseOrderRootProps = {
  children: ReactNode
  className?: string
  description?: ReactNode
  disabled?: boolean
  value?: string | null
  onChange?: (value: string | null) => void | Promise<void>
}

export type PurchaseOrderContextValue = {
  value?: string | null
  description?: ReactNode
  disabled?: boolean
  openEditDialog: () => void
  clearPurchaseOrderNumber: () => void
}

export type PurchaseOrderButtonProps = {
  children?: ReactNode
  className?: string
  disabled?: boolean
  onClick?: () => void
}
