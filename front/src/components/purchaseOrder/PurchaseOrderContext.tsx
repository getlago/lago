import { createContext, useContext } from 'react'

import { PurchaseOrderContextValue } from './types'

export const PurchaseOrderContext = createContext<PurchaseOrderContextValue | null>(null)

export const usePurchaseOrderContext = () => {
  const context = useContext(PurchaseOrderContext)

  if (!context) {
    throw new Error('PO compound components must be used inside <PO>.')
  }

  return context
}
