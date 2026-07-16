import { create, useModal } from '@ebay/nice-modal-react'
import { ReactNode } from 'react'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { BaseDrawer } from './BaseDrawer'
import { CLOSE_DRAWER_PARAMS } from './const'

export type CentralizedDrawerProps = {
  title: ReactNode
  children: ReactNode
  actions?: ReactNode
  actionsClassName?: string
  withPadding?: boolean
  fullContentHeight?: boolean
  className?: string
  onClose?: () => void
  onEntered?: (container: HTMLElement) => void
  shouldPromptOnClose?: () => boolean
}

const CentralizedDrawer = create(
  ({
    title,
    children,
    actions,
    actionsClassName,
    withPadding,
    fullContentHeight,
    className,
    onClose: onCloseProp,
    onEntered,
    shouldPromptOnClose,
  }: CentralizedDrawerProps) => {
    const modal = useModal()
    const { translate } = useInternationalization()
    const centralizedDialog = useCentralizedDialog()

    const doClose = () => {
      onCloseProp?.()
      modal.resolve(CLOSE_DRAWER_PARAMS)
      modal.hide()
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
        actions={actions}
        actionsClassName={actionsClassName}
        withPadding={withPadding}
        fullContentHeight={fullContentHeight}
        className={className}
      >
        {children}
      </BaseDrawer>
    )
  },
)

export default CentralizedDrawer
