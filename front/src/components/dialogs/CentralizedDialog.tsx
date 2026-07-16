import { create, useModal } from '@ebay/nice-modal-react'
import { ReactNode } from 'react'

import { Button } from '~/components/designSystem/Button'
import BaseDialog from '~/components/dialogs/BaseDialog'

import {
  CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  CENTRALIZED_DIALOG_TEST_ID,
  CLOSE_PARAMS,
} from './const'
import { DialogResult, HookDialogReturnType } from './types'
import { useDialogActions } from './useDialogActions'

export type CentralizedDialogProps = {
  title: ReactNode
  description?: ReactNode
  headerContent?: ReactNode
  children?: ReactNode
  onAction: () => DialogResult | Promise<DialogResult> | void | Promise<void>
  actionText: string
  colorVariant?: 'info' | 'danger'
  disableOnContinue?: boolean
  cancelOrCloseText?: 'close' | 'cancel'
  closeOnError?: boolean
  onError?: (error: Error) => void
}

const CentralizedDialog = create(
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
  }: CentralizedDialogProps) => {
    const modal = useModal()
    const { handleCancel, handleContinue, closeText } = useDialogActions({
      modal,
      onAction,
      cancelOrCloseText,
      closeOnError,
      onError,
    })

    return (
      <BaseDialog
        isOpen={modal.visible}
        closeDialog={handleCancel}
        removeDialog={modal.remove}
        title={title}
        description={description}
        headerContent={headerContent}
        data-test={CENTRALIZED_DIALOG_TEST_ID}
        actions={
          <>
            <Button
              variant="quaternary"
              onClick={handleCancel}
              data-test={CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID}
            >
              {closeText}
            </Button>
            <Button
              disabled={disableOnContinue}
              danger={colorVariant === 'danger'}
              onClick={handleContinue}
              data-test={CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID}
            >
              {actionText}
            </Button>
          </>
        }
      >
        {children}
      </BaseDialog>
    )
  },
)

export default CentralizedDialog

export const useCentralizedDialog = (): HookDialogReturnType<CentralizedDialogProps> => {
  const modal = useModal(CENTRALIZED_DIALOG_NAME)

  return {
    open: (props: CentralizedDialogProps) => modal.show(props) as Promise<DialogResult>,
    close: () => {
      modal.resolve(CLOSE_PARAMS)
      modal.hide()
    },
  }
}
