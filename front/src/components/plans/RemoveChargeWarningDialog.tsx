import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { DialogRef } from '~/components/designSystem/Dialog'
import { WarningDialog } from '~/components/designSystem/WarningDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type LocalData = { callback: () => void }

export interface RemoveChargeWarningDialogRef {
  openDialog: ({ callback }: LocalData) => unknown
  closeDialog: () => unknown
}

export const RemoveChargeWarningDialog = forwardRef<RemoveChargeWarningDialogRef>((_, ref) => {
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<LocalData | undefined>(undefined)
  const { translate } = useInternationalization()

  useImperativeHandle(ref, () => ({
    openDialog: (data) => {
      setLocalData(data)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  return (
    <WarningDialog
      ref={dialogRef}
      title={translate('text_63cfe20ad6c1a53c5352a46e')}
      description={translate('text_63cfe20ad6c1a53c5352a470')}
      continueText={translate('text_63cfe20ad6c1a53c5352a474')}
      onContinue={localData?.callback}
    />
  )
})

RemoveChargeWarningDialog.displayName = 'RemoveChargeWarningDialog'
