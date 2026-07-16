import MuiDialog from '@mui/material/Dialog'
import { forwardRef, ReactNode, useEffect, useImperativeHandle, useState } from 'react'

import { tw } from '~/styles/utils'

import { Typography } from './Typography'

// Test IDs
export const DIALOG_TITLE_TEST_ID = 'dialog-title'
export const DIALOG_DESCRIPTION_TEST_ID = 'dialog-description'

export interface DialogProps {
  actions: (args: { closeDialog: () => void }) => JSX.Element
  title: ReactNode
  open?: boolean
  description?: ReactNode
  children?: ReactNode
  formId?: string
  formSubmit?: (e: React.FormEvent) => void
  onOpen?: () => void
  onClose?: () => void
  onEntered?: () => void
}

export interface DialogRef {
  openDialog: () => unknown
  closeDialog: () => unknown
}

export const Dialog = forwardRef<DialogRef, DialogProps>(
  (
    {
      title,
      description,
      actions,
      children,
      onOpen,
      onClose,
      onEntered,
      open = false,
      formId,
      formSubmit,
      ...props
    }: DialogProps,
    ref,
  ) => {
    const [isOpen, setIsOpen] = useState(open)

    useImperativeHandle(ref, () => ({
      openDialog: () => {
        setIsOpen(true)
        onOpen && onOpen()
      },
      closeDialog: () => closeDialog(),
    }))

    const closeDialog = () => {
      setIsOpen(false)
      onClose && onClose()
    }

    useEffect(() => setIsOpen(open), [open])

    return (
      <>
        <MuiDialog
          className="z-dialog box-border"
          classes={{
            container: 'px-4 py-20 box-border',
            scrollBody: 'after:h-20',
          }}
          scroll="body"
          onKeyDown={(e) => {
            if (e.code === 'Escape') {
              closeDialog()
            }
          }}
          open={isOpen}
          onClose={(_, reason) => {
            if (['backdropClick', 'escapeKeyDown'].includes(reason)) {
              closeDialog()
            }
          }}
          slotProps={{
            backdrop: {
              classes: {
                root: 'bg-grey-700/40',
              },
            },
          }}
          PaperProps={{
            className:
              'flex flex-col md:max-w-xl mx-auto my-0 rounded-xl z-dialog p-10 max-w-full shadow-xl',
          }}
          transitionDuration={80}
          TransitionProps={{ onEntered }}
          {...props}
        >
          <Typography
            className={tw(!!description ? 'mb-3' : 'mb-8')}
            variant="headline"
            data-test={DIALOG_TITLE_TEST_ID}
          >
            {title}
          </Typography>

          {description && (
            <Typography className="mb-8" data-test={DIALOG_DESCRIPTION_TEST_ID}>
              {description}
            </Typography>
          )}

          {formId ? (
            <form id={formId} onSubmit={formSubmit}>
              {children && children}

              <div className="flex flex-col-reverse flex-wrap justify-end gap-3 md:flex-row">
                {actions({ closeDialog })}
              </div>
            </form>
          ) : (
            <>
              {children}

              <div className="flex flex-col-reverse flex-wrap justify-end gap-3 md:flex-row">
                {actions({ closeDialog })}
              </div>
            </>
          )}
        </MuiDialog>
      </>
    )
  },
)

Dialog.displayName = 'Dialog'
