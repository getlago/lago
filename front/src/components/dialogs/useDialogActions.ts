import { useModal } from '@ebay/nice-modal-react'

import { useInternationalization } from '~/hooks/core/useInternationalization'

import { CLOSE_PARAMS } from './const'
import { DialogResult } from './types'

type UseDialogActionsParams = {
  modal: ReturnType<typeof useModal>
  onAction?: () => DialogResult | Promise<DialogResult> | void | Promise<void>
  cancelOrCloseText: 'close' | 'cancel'
  closeOnError: boolean
  onError?: (error: Error) => void
}

type UseDialogActionsReturn = {
  handleCancel: () => Promise<void>
  handleContinue: () => Promise<void>
  closeText: string
}

export const useDialogActions = ({
  modal,
  onAction,
  cancelOrCloseText,
  closeOnError,
  onError,
}: UseDialogActionsParams): UseDialogActionsReturn => {
  const { translate } = useInternationalization()

  const handleCancel = async (): Promise<void> => {
    modal.resolve(CLOSE_PARAMS)
    modal.hide()
  }

  const closeText =
    cancelOrCloseText === 'cancel'
      ? translate('text_6244277fe0975300fe3fb94a')
      : translate('text_62f50d26c989ab03196884ae')

  const handleContinue = async (): Promise<void> => {
    if (!onAction) return

    try {
      const result = await onAction()

      const response = result ?? { reason: 'success' }

      modal.resolve(response)
      modal.hide()
    } catch (error) {
      if (closeOnError) {
        modal.reject({
          reason: 'error',
          error: error as Error,
        })
        modal.hide()
      } else {
        onError?.(error as Error)
      }
    }
  }

  return {
    handleCancel,
    handleContinue,
    closeText,
  }
}
