import { useCallback, useMemo } from 'react'

import { tw } from '~/styles/utils'

import { PurchaseOrderContext } from './PurchaseOrderContext'
import { PurchaseOrderContextValue, PurchaseOrderRootProps } from './types'
import { usePurchaseOrderNumberDialogs } from './usePurchaseOrderNumberDialogs'

export const PURCHASE_ORDER_ROOT_TEST_ID = 'purchase-order-root'

export const PurchaseOrderRoot = ({
  children,
  className,
  description,
  disabled,
  onChange,
  value,
}: PurchaseOrderRootProps) => {
  const { openEditDialog } = usePurchaseOrderNumberDialogs({
    description,
    onChange,
    value,
  })
  const clearPurchaseOrderNumber = useCallback(() => {
    onChange?.(null)
  }, [onChange])

  const contextValue = useMemo<PurchaseOrderContextValue>(
    () => ({
      value,
      description,
      disabled,
      openEditDialog,
      clearPurchaseOrderNumber,
    }),
    [value, description, disabled, openEditDialog, clearPurchaseOrderNumber],
  )

  return (
    <PurchaseOrderContext.Provider value={contextValue}>
      <div className={tw('flex flex-col gap-3', className)} data-test={PURCHASE_ORDER_ROOT_TEST_ID}>
        {children}
      </div>
    </PurchaseOrderContext.Provider>
  )
}
