import { useEffect, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog } from '~/components/designSystem/Dialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { PaymentMethodFields } from './PaymentMethodFields'
import { deriveBehavior, PaymentMethodBehavior, SelectedPaymentMethod } from './types'

import { VIEW_TYPE_TRANSLATION_KEYS, ViewTypeEnum } from '../paymentMethodsInvoiceSettings/types'

const EDIT_PM_DIALOG_CANCEL_BUTTON_TEST_ID = 'edit-payment-method-dialog-cancel-button'

export const EDIT_PM_DIALOG_SAVE_BUTTON_TEST_ID = 'edit-payment-method-dialog-save-button'

interface EditPaymentMethodDialogProps {
  open: boolean
  onClose: () => void
  externalCustomerId: string
  selectedPaymentMethod: SelectedPaymentMethod
  setSelectedPaymentMethod: (value: SelectedPaymentMethod) => void
  viewType: ViewTypeEnum
}

export const EditPaymentMethodDialog = ({
  open,
  onClose,
  externalCustomerId,
  selectedPaymentMethod,
  setSelectedPaymentMethod,
  viewType,
}: EditPaymentMethodDialogProps) => {
  const { translate } = useInternationalization()

  const seedValue = selectedPaymentMethod
  const [draft, setDraft] = useState<SelectedPaymentMethod>(seedValue)
  const [behavior, setBehavior] = useState<PaymentMethodBehavior>(() => deriveBehavior(seedValue))

  useEffect(() => {
    if (open) {
      setDraft(selectedPaymentMethod)
      setBehavior(deriveBehavior(selectedPaymentMethod))
    }
  }, [open, selectedPaymentMethod])

  const isSaveDisabled = behavior === PaymentMethodBehavior.SPECIFIC && !draft?.paymentMethodId

  const handleSave = (): void => {
    setSelectedPaymentMethod(draft)
    onClose()
  }

  const viewTypeLabel = translate(VIEW_TYPE_TRANSLATION_KEYS[viewType])

  return (
    <Dialog
      open={open}
      title={translate('text_1764327933607ccgjo6zvcqe', { object: viewTypeLabel })}
      description={translate('text_1764327933607muwda2648vk', { object: viewTypeLabel })}
      onClose={onClose}
      actions={({ closeDialog }) => (
        <>
          <Button
            variant="quaternary"
            onClick={closeDialog}
            data-test={EDIT_PM_DIALOG_CANCEL_BUTTON_TEST_ID}
          >
            {translate('text_63ea0f84f400488553caa6a5')}
          </Button>
          <Button
            variant="primary"
            disabled={isSaveDisabled}
            onClick={handleSave}
            data-test={EDIT_PM_DIALOG_SAVE_BUTTON_TEST_ID}
          >
            {translate('text_1764327933607yodbve95igk')}
          </Button>
        </>
      )}
    >
      <div className="mb-8">
        <PaymentMethodFields
          viewType={viewType}
          externalCustomerId={externalCustomerId}
          value={seedValue}
          onChange={setDraft}
          onBehaviorChange={setBehavior}
        />
      </div>
    </Dialog>
  )
}
