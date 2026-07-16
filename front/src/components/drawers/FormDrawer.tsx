import { create, useModal } from '@ebay/nice-modal-react'
import { tw } from 'lago-design-system'
import { ReactNode } from 'react'

import { Button } from '~/components/designSystem/Button'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { BaseDrawer } from './BaseDrawer'
import { FormDrawerProps as FormProps } from './types'
import { useDrawerActions } from './useDrawerActions'

export type FormDrawerProps = {
  title: ReactNode
  children?: ReactNode
  mainAction?: ReactNode
  secondaryAction?: ReactNode
  cancelOrCloseText?: 'close' | 'cancel'
  closeOnError?: boolean
  onError?: (error: Error) => void
  /**
   * When true (default), the drawer resolves and hides automatically once
   * `form.submit` settles. Set false for drawers that own their close logic
   * inside the form's `onSubmit` (e.g. close on success, stay open on a failed
   * mutation): the submit is then forwarded raw and never auto-closes.
   */
  closeOnSubmitSuccess?: boolean
  form: FormProps
  className?: string
  withPadding?: boolean
  fullContentHeight?: boolean
  onClose?: () => void
  onEntered?: (container: HTMLElement) => void
  shouldPromptOnClose?: () => boolean
}

const FormDrawer = create(
  ({
    title,
    children,
    mainAction,
    secondaryAction,
    cancelOrCloseText = 'close',
    closeOnError = true,
    onError,
    closeOnSubmitSuccess = true,
    form,
    className,
    withPadding,
    fullContentHeight,
    onClose,
    onEntered,
    shouldPromptOnClose,
  }: FormDrawerProps) => {
    const modal = useModal()
    const { translate } = useInternationalization()
    const centralizedDialog = useCentralizedDialog()
    const { handleCancel, closeText, handleContinue } = useDrawerActions({
      modal,
      onAction: form.submit,
      cancelOrCloseText,
      closeOnError,
      onError,
    })

    const doClose = () => {
      onClose?.()
      handleCancel()
    }

    const promptBeforeClosing = () => {
      centralizedDialog.open({
        title: translate('text_665deda4babaf700d603ea13'),
        description: translate('text_665dedd557dc3c00c62eb83d'),
        actionText: translate('text_645388d5bdbd7b00abffa033'),
        colorVariant: 'danger',
        onAction: doClose,
      })
    }

    const handleClose = () => {
      if (shouldPromptOnClose?.()) {
        promptBeforeClosing()
      } else {
        doClose()
      }
    }

    return (
      <BaseDrawer
        isOpen={modal.visible}
        title={title}
        onClose={handleClose}
        onExited={modal.remove}
        onEntered={onEntered}
        className={className}
        withPadding={withPadding}
        fullContentHeight={fullContentHeight}
        form={{
          id: form.id,
          submit: closeOnSubmitSuccess ? handleContinue : form.submit,
        }}
        actions={
          <div
            className={tw(
              'flex w-full items-center gap-3',
              secondaryAction ? 'justify-between' : 'justify-end',
            )}
          >
            {secondaryAction}
            <div className="flex items-center gap-3">
              <Button variant="quaternary" onClick={handleClose}>
                {closeText}
              </Button>
              {mainAction}
            </div>
          </div>
        }
      >
        {children}
      </BaseDrawer>
    )
  },
)

export default FormDrawer
