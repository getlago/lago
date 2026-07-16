import { create, useModal } from '@ebay/nice-modal-react'
import { tw } from 'lago-design-system'

import { Button } from '~/components/designSystem/Button'

import BaseDialog from './BaseDialog'
import { CentralizedDialogProps, useCentralizedDialog } from './CentralizedDialog'
import {
  CLOSE_PARAMS,
  FORM_DIALOG_CANCEL_BUTTON_TEST_ID,
  FORM_DIALOG_OPENING_DIALOG_NAME,
  FORM_DIALOG_OPENING_DIALOG_TEST_ID,
  OPEN_OTHER_DIALOG_PARAMS,
} from './const'
import { FormDialogProps } from './FormDialog'
import { DialogResult, HookDialogReturnType } from './types'
import { useDialogActions } from './useDialogActions'

export type FormDialogOpeningDialogProps = FormDialogProps & {
  canOpenDialog?: boolean
  openDialogText: string
  otherDialogProps: CentralizedDialogProps
}

const FormDialogOpeningDialog = create(
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
    canOpenDialog,
    openDialogText,
    otherDialogProps,
  }: FormDialogOpeningDialogProps) => {
    const modal = useModal()
    const centralizedDialog = useCentralizedDialog()

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

    const definedActions = (
      <div
        className={tw('flex flex-row items-center justify-between gap-3', {
          'w-full': canOpenDialog,
        })}
      >
        {canOpenDialog && (
          <Button
            danger
            variant="quaternary"
            onClick={() => {
              const otherDialogPromise = centralizedDialog.open(otherDialogProps)

              modal.resolve({
                ...OPEN_OTHER_DIALOG_PARAMS,
                otherDialog: otherDialogPromise,
              })
              modal.hide()
            }}
          >
            {openDialogText}
          </Button>
        )}
        <div className="flex flex-row items-center gap-3">
          <Button
            variant="quaternary"
            onClick={handleCancel}
            data-test={FORM_DIALOG_CANCEL_BUTTON_TEST_ID}
          >
            {closeText}
          </Button>
          {mainAction}
        </div>
      </div>
    )

    return (
      <BaseDialog
        title={title}
        description={description}
        headerContent={headerContent}
        actions={definedActions}
        isOpen={modal.visible}
        closeDialog={handleCancel}
        removeDialog={modal.remove}
        data-test={FORM_DIALOG_OPENING_DIALOG_TEST_ID}
        form={formActions}
      >
        {children}
      </BaseDialog>
    )
  },
)

export default FormDialogOpeningDialog

export const useFormDialogOpeningDialog =
  (): HookDialogReturnType<FormDialogOpeningDialogProps> => {
    const modal = useModal(FORM_DIALOG_OPENING_DIALOG_NAME)

    return {
      open: (props: FormDialogOpeningDialogProps) => modal.show(props) as Promise<DialogResult>,
      close: () => {
        modal.resolve(CLOSE_PARAMS)
        modal.hide()
      },
    }
  }
