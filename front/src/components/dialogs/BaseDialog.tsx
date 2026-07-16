import MuiDialog from '@mui/material/Dialog'
import { tw } from 'lago-design-system'
import { ReactNode } from 'react'

import { Typography } from '~/components/designSystem/Typography'

import { DIALOG_TITLE_TEST_ID } from './const'
import { FormProps } from './types'

export type BaseDialogProps = {
  title: ReactNode
  description?: ReactNode
  headerContent?: ReactNode
  children?: ReactNode
  actions: ReactNode
  isOpen: boolean
  closeDialog: () => Promise<unknown>
  removeDialog: () => void
  'data-test'?: string
  form?: FormProps
}

const BaseDialog = ({
  title,
  description,
  headerContent,
  children,
  actions,
  isOpen,
  closeDialog,
  removeDialog,
  'data-test': dataTest,
  form,
}: BaseDialogProps) => {
  const childrenNeedsWrapping = children && typeof children === 'string'

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    return form?.submit()
  }

  const generateContent = () => {
    return (
      <>
        {/* Header */}
        <header className="p-8">
          <div className="flex flex-col gap-8">
            {/* Header is made of two main parts: title/description and optional header content */}
            <div className="flex flex-col gap-2">
              <Typography variant="subhead1" data-test={DIALOG_TITLE_TEST_ID}>
                {title}
              </Typography>
              {description && <Typography variant="body">{description}</Typography>}
            </div>
            {headerContent && <div>{headerContent}</div>}
          </div>
        </header>

        {/* Content */}
        {children && (
          <div
            className={tw('overflow-auto shadow-t', {
              'p-8': childrenNeedsWrapping,
            })}
          >
            {children}
          </div>
        )}

        {/* Footer */}
        <div className="flex flex-col-reverse flex-wrap justify-end gap-3 px-8 py-4 shadow-t md:flex-row">
          {actions}
        </div>
      </>
    )
  }

  return (
    <MuiDialog
      className="z-dialog box-border"
      classes={{
        container: 'px-4 py-20 box-border overflow-hidden',
        scrollBody: 'after:h-20',
        paper: 'max-h-[calc(100vh-10rem)]', // 10 rem because of py-20 on the container
      }}
      scroll="body"
      open={isOpen}
      onClose={(_, reason) => {
        if (['backdropClick', 'escapeKeyDown'].includes(reason)) {
          closeDialog()
        }
      }}
      TransitionProps={{
        onExited: () => removeDialog(),
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
          'flex flex-col md:max-w-xl my-0 rounded-xl z-dialog max-w-full shadow-xl mx-auto',
      }}
      transitionDuration={80}
      data-test={dataTest}
    >
      {form ? (
        <form
          id={form.id}
          onSubmit={handleSubmit}
          className="flex max-h-[calc(100vh-10rem)] flex-col"
        >
          {generateContent()}
        </form>
      ) : (
        <>{generateContent()}</>
      )}
    </MuiDialog>
  )
}

export default BaseDialog
