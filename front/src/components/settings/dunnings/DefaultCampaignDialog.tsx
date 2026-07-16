import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type ActionType = 'setDefault' | 'removeDefault'

type TDefaultCampaignDialogProps = {
  type: ActionType
  onConfirm: () => void
}

export interface DefaultCampaignDialogRef {
  openDialog: (props: TDefaultCampaignDialogProps) => unknown
  closeDialog: () => unknown
}

export const DefaultCampaignDialog = forwardRef<DefaultCampaignDialogRef, unknown>(
  (_props, ref) => {
    const { translate } = useInternationalization()
    const dialogRef = useRef<DialogRef>(null)
    const [localData, setLocalData] = useState<TDefaultCampaignDialogProps>()

    useImperativeHandle(ref, () => ({
      openDialog: (props) => {
        setLocalData(props)
        dialogRef.current?.openDialog()
      },
      closeDialog: () => {
        setLocalData(undefined)
        dialogRef.current?.closeDialog()
      },
    }))

    return (
      <Dialog
        ref={dialogRef}
        title={
          localData?.type === 'setDefault'
            ? translate('text_1728574726495xzb3xvrlprn')
            : translate('text_1728575305796wa2yf2sn2ct')
        }
        description={translate(
          localData?.type === 'setDefault'
            ? 'text_17285753057960sioe6ltl0p'
            : 'text_1728575305796optuxlg8q3p',
        )}
        actions={({ closeDialog }) => (
          <>
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_62728ff857d47b013204c7e4')}
            </Button>

            <Button
              variant="primary"
              onClick={async () => {
                await localData?.onConfirm()
                closeDialog()
              }}
              data-test="set-organization-dunning-default-campaign"
            >
              {localData?.type === 'setDefault'
                ? translate('text_1728574726495n9jdse2hnrf')
                : translate('text_1728575305796o7kwackkbj6')}
            </Button>
          </>
        )}
        data-test="set-campaign-default-dialog"
      />
    )
  },
)

DefaultCampaignDialog.displayName = 'DefaultCampaignDialog'
