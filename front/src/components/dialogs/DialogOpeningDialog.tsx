import { create, useModal } from '@ebay/nice-modal-react'
import { tw } from 'lago-design-system'

import { Button } from '~/components/designSystem/Button'

import BaseDialog from './BaseDialog'
import { CentralizedDialogProps, useCentralizedDialog } from './CentralizedDialog'
import { CLOSE_PARAMS, DIALOG_OPENING_DIALOG_NAME, OPEN_OTHER_DIALOG_PARAMS } from './const'
import { DialogResult, HookDialogReturnType } from './types'
import { useDialogActions } from './useDialogActions'

export type DialogOpeningDialogProps = CentralizedDialogProps & {
  canOpenDialog?: boolean
  openDialogText: string
  otherDialogProps: CentralizedDialogProps
}

const DialogOpeningDialog = create(
  ({
    title,
    description,
    headerContent,
    children,
    onAction,
    actionText,
    colorVariant = 'info',
    disableOnContinue = false,
    cancelOrCloseText = 'close',
    closeOnError = true,
    onError,
    canOpenDialog,
    openDialogText,
    otherDialogProps,
  }: DialogOpeningDialogProps) => {
    const modal = useModal()
    const centralizedDialog = useCentralizedDialog()

    const { handleCancel, handleContinue, closeText } = useDialogActions({
      modal,
      onAction,
      cancelOrCloseText,
      closeOnError,
      onError,
    })

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
          <Button variant="quaternary" onClick={handleCancel}>
            {closeText}
          </Button>
          <Button
            disabled={disableOnContinue}
            danger={colorVariant === 'danger'}
            onClick={handleContinue}
          >
            {actionText}
          </Button>
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
      >
        {children}
      </BaseDialog>
    )
  },
)

export default DialogOpeningDialog

export const useDialogOpeningDialog = (): HookDialogReturnType<DialogOpeningDialogProps> => {
  const modal = useModal(DIALOG_OPENING_DIALOG_NAME)

  return {
    open: (props: DialogOpeningDialogProps) => modal.show(props) as Promise<DialogResult>,
    close: () => {
      modal.resolve(CLOSE_PARAMS)
      modal.hide()
    },
  }
}
