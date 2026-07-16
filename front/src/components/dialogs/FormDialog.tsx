import { create, useModal } from '@ebay/nice-modal-react'
import { ReactNode } from 'react'

import { Button } from '~/components/designSystem/Button'
import BaseDialog from '~/components/dialogs/BaseDialog'

import {
  CLOSE_PARAMS,
  FORM_DIALOG_CANCEL_BUTTON_TEST_ID,
  FORM_DIALOG_NAME,
  FORM_DIALOG_TEST_ID,
} from './const'
import { DialogResult, FormProps, HookDialogReturnType } from './types'
import { useDialogActions } from './useDialogActions'

export type FormDialogProps = {
  title: ReactNode
  description?: ReactNode
  headerContent?: ReactNode
  children?: ReactNode
  mainAction?: ReactNode
  cancelOrCloseText?: 'close' | 'cancel'
  closeOnError?: boolean
  onError?: (error: Error) => void
  form: FormProps
}

const FormDialog = create(
  ({
    title,
    description,
    headerContent,
    children,
    mainAction,
    cancelOrCloseText = 'close',
    closeOnError = true,
    onError,
    form,
  }: FormDialogProps) => {
    const modal = useModal()
    const { handleCancel, closeText, handleContinue } = useDialogActions({
      modal,
      onAction: form.submit,
      cancelOrCloseText,
      closeOnError,
      onError,
    })

    const formActions = {
      id: form.id,
      submit: handleContinue,
    }

    return (
      <BaseDialog
        isOpen={modal.visible}
        closeDialog={handleCancel}
        removeDialog={modal.remove}
        title={title}
        description={description}
        headerContent={headerContent}
        data-test={FORM_DIALOG_TEST_ID}
        form={formActions}
        actions={
          <>
            <Button
              variant="quaternary"
              onClick={handleCancel}
              data-test={FORM_DIALOG_CANCEL_BUTTON_TEST_ID}
            >
              {closeText}
            </Button>
            {mainAction}
          </>
        }
      >
        {children}
      </BaseDialog>
    )
  },
)

export default FormDialog

export const useFormDialog = (): HookDialogReturnType<FormDialogProps> => {
  const modal = useModal(FORM_DIALOG_NAME)

  return {
    open: (props: FormDialogProps) => modal.show(props) as Promise<DialogResult>,
    close: () => {
      modal.resolve(CLOSE_PARAMS)
      modal.hide()
    },
  }
}
