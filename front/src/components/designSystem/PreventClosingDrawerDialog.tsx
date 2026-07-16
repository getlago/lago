import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { DialogRef } from '~/components/designSystem/Dialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { WarningDialog } from './WarningDialog'

type PreventClosingDrawerDialogProps = {
  onContinue: () => void
}

export interface PreventClosingDrawerDialogRef {
  openDialog: (props: PreventClosingDrawerDialogProps) => unknown
  closeDialog: () => unknown
}

export const PreventClosingDrawerDialog = forwardRef<PreventClosingDrawerDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<PreventClosingDrawerDialogProps | null>(null)

  useImperativeHandle(ref, () => ({
    openDialog: (taxRateData) => {
      setLocalData(taxRateData)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => {
      dialogRef.current?.closeDialog()
    },
  }))

  return (
    <WarningDialog
      ref={dialogRef}
      title={translate('text_665deda4babaf700d603ea13')}
      description={translate('text_665dedd557dc3c00c62eb83d')}
      onCancel={async () => {
        dialogRef.current?.closeDialog()
      }}
      onContinue={async () => {
        localData?.onContinue()
      }}
      continueText={translate('text_645388d5bdbd7b00abffa033')}
    />
  )
})

PreventClosingDrawerDialog.displayName = 'forwardRef'
