import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import { PURCHASE_ORDER_TRANSLATIONS } from './constants'
import { usePurchaseOrderContext } from './PurchaseOrderContext'
import { PurchaseOrderButtonProps } from './types'

export const PURCHASE_ORDER_ADD_BUTTON_TEST_ID = 'purchase-order-add-button'
export const PURCHASE_ORDER_EDIT_BUTTON_TEST_ID = 'purchase-order-edit-button'
export const PURCHASE_ORDER_TRASH_BUTTON_TEST_ID = 'purchase-order-trash-button'
export const PURCHASE_ORDER_DYNAMIC_INPUT_BUTTON_TEST_ID = 'purchase-order-dynamic-input-button'

export const PurchaseOrderAddButton = ({
  children,
  className,
  disabled,
  onClick,
}: PurchaseOrderButtonProps) => {
  const { translate } = useInternationalization()
  const { disabled: contextDisabled, openEditDialog } = usePurchaseOrderContext()

  return (
    <Button
      className={tw('self-start', className)}
      startIcon="plus"
      variant="inline"
      disabled={disabled || contextDisabled}
      onClick={onClick || openEditDialog}
      data-test={PURCHASE_ORDER_ADD_BUTTON_TEST_ID}
    >
      {children || translate(PURCHASE_ORDER_TRANSLATIONS.add)}
    </Button>
  )
}

export const PurchaseOrderEditButton = ({
  children,
  className,
  disabled,
  onClick,
}: PurchaseOrderButtonProps) => {
  const { translate } = useInternationalization()
  const { disabled: contextDisabled, openEditDialog } = usePurchaseOrderContext()

  return children ? (
    <Button
      className={className}
      startIcon="pen"
      variant="inline"
      disabled={disabled || contextDisabled}
      onClick={onClick || openEditDialog}
      data-test={PURCHASE_ORDER_EDIT_BUTTON_TEST_ID}
    >
      {children}
    </Button>
  ) : (
    <Tooltip placement="top" title={translate('text_63e51ef4985f0ebd75c212fc')}>
      <Button
        className={className}
        icon="pen"
        size="small"
        variant="quaternary"
        disabled={disabled || contextDisabled}
        onClick={onClick || openEditDialog}
        data-test={PURCHASE_ORDER_EDIT_BUTTON_TEST_ID}
      />
    </Tooltip>
  )
}

export const PurchaseOrderTrashButton = ({
  className,
  disabled,
  onClick,
}: Omit<PurchaseOrderButtonProps, 'children'>) => {
  const { translate } = useInternationalization()
  const { clearPurchaseOrderNumber, disabled: contextDisabled } = usePurchaseOrderContext()

  return (
    <Tooltip placement="top" title={translate('text_63aa085d28b8510cd46443ff')}>
      <Button
        className={className}
        icon="trash"
        size="small"
        variant="quaternary"
        disabled={disabled || contextDisabled}
        onClick={onClick || clearPurchaseOrderNumber}
        data-test={PURCHASE_ORDER_TRASH_BUTTON_TEST_ID}
      />
    </Tooltip>
  )
}

export const PurchaseOrderDynamicInputButton = ({
  children,
  className,
  disabled,
  onClick,
}: PurchaseOrderButtonProps) => {
  const { translate } = useInternationalization()
  const { disabled: contextDisabled, openEditDialog } = usePurchaseOrderContext()

  return (
    <Button
      className={tw('self-start', className)}
      startIcon="plus"
      variant="inline"
      disabled={disabled || contextDisabled}
      onClick={onClick || openEditDialog}
      data-test={PURCHASE_ORDER_DYNAMIC_INPUT_BUTTON_TEST_ID}
    >
      {children || translate(PURCHASE_ORDER_TRANSLATIONS.addShort)}
    </Button>
  )
}
