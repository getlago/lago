import { Button } from '~/components/designSystem/Button'

export const EDIT_ICS_DIALOG_CANCEL_BUTTON_TEST_ID =
  'edit-invoice-custom-section-dialog-cancel-button'
export const EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID = 'edit-invoice-custom-section-dialog-save-button'

export interface EditInvoiceCustomSectionDialogActionsProps {
  closeDialog: () => void
  onSave: () => void
  isSaveDisabled: boolean
  translate: (key: string) => string
}

export const EditInvoiceCustomSectionDialogActions = ({
  closeDialog,
  onSave,
  isSaveDisabled,
  translate,
}: EditInvoiceCustomSectionDialogActionsProps) => {
  return (
    <>
      <Button
        variant="quaternary"
        onClick={closeDialog}
        data-test={EDIT_ICS_DIALOG_CANCEL_BUTTON_TEST_ID}
      >
        {translate('text_63ea0f84f400488553caa6a5')}
      </Button>
      <Button
        variant="primary"
        disabled={isSaveDisabled}
        onClick={onSave}
        data-test={EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID}
      >
        {translate('text_1764327933607yodbve95igk')}
      </Button>
    </>
  )
}
