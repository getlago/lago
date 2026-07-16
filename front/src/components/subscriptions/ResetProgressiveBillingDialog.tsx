import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { useResetSubscriptionProgressiveBillingMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation resetSubscriptionProgressiveBilling($input: UpdateSubscriptionInput!) {
    updateSubscription(input: $input) {
      id
      progressiveBillingDisabled
      usageThresholds {
        amountCents
        recurring
        thresholdDisplayName
      }
    }
  }
`

type ResetProgressiveBillingDialogProps = {
  subscriptionId: string
}

export interface ResetProgressiveBillingDialogRef {
  openDialog: (data: ResetProgressiveBillingDialogProps) => void
  closeDialog: () => void
}

export const ResetProgressiveBillingDialog = forwardRef<ResetProgressiveBillingDialogRef>(
  (_, ref) => {
    const dialogRef = useRef<DialogRef>(null)
    const { translate } = useInternationalization()
    const [localData, setLocalData] = useState<ResetProgressiveBillingDialogProps | null>(null)

    const [resetProgressiveBilling] = useResetSubscriptionProgressiveBillingMutation({
      onCompleted({ updateSubscription: result }) {
        if (result?.id) {
          addToast({
            severity: 'success',
            translateKey: 'text_1738071730498resetsuccess',
          })
        }
      },
    })

    useImperativeHandle(ref, () => ({
      openDialog: (data) => {
        setLocalData(data)
        dialogRef.current?.openDialog()
      },
      closeDialog: () => {
        dialogRef.current?.closeDialog()
      },
    }))

    return (
      <Dialog
        ref={dialogRef}
        title={translate('text_17380717304987v96qpfimgc')}
        description={
          <Typography variant="body" color="grey600">
            {translate('text_1738071730498zxzs6oy5tz3')}
          </Typography>
        }
        actions={({ closeDialog }) => (
          <>
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <Button
              danger
              variant="primary"
              onClick={async () => {
                if (localData?.subscriptionId) {
                  await resetProgressiveBilling({
                    variables: {
                      input: {
                        id: localData.subscriptionId,
                        progressiveBillingDisabled: false,
                        usageThresholds: [],
                      },
                    },
                  })
                }
                closeDialog()
              }}
            >
              {translate('text_1738071730498ht52blrjax6')}
            </Button>
          </>
        )}
      />
    )
  },
)

ResetProgressiveBillingDialog.displayName = 'ResetProgressiveBillingDialog'
