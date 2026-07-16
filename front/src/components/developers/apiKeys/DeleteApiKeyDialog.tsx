import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { intlFormatDateTime } from '~/core/timezone/utils'
import {
  ApiKeyForDeleteApiKeyDialogFragment,
  TimezoneEnum,
  useDestroyApiKeyMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment ApiKeyForDeleteApiKeyDialog on SanitizedApiKey {
    id
    lastUsedAt
  }

  mutation destroyApiKey($input: DestroyApiKeyInput!) {
    destroyApiKey(input: $input) {
      id
    }
  }
`

type DeleteApiKeyDialogProps = {
  apiKey: ApiKeyForDeleteApiKeyDialogFragment
}

export interface DeleteApiKeyDialogRef {
  openDialog: (data: DeleteApiKeyDialogProps) => unknown
  closeDialog: () => unknown
}

export const DeleteApiKeyDialog = forwardRef<DeleteApiKeyDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<DeleteApiKeyDialogProps | undefined>(undefined)
  const apiKey = localData?.apiKey

  const [destroyApiKey] = useDestroyApiKeyMutation({
    onCompleted(data) {
      if (!!data?.destroyApiKey?.id) {
        addToast({
          message: translate('text_17325256621362d6ocmq1lhw'),
          severity: 'success',
        })
        dialogRef.current?.closeDialog()
      }
    },
    refetchQueries: ['getApiKeys'],
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
      title={translate('text_1732182455718y0m5fijuray')}
      description={translate('text_1732182455718jvfke15s5qj')}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_64352657267c3d916f962769')}
          </Button>
          <Button
            danger
            variant="primary"
            onClick={async () => {
              await destroyApiKey({
                variables: { input: { id: apiKey?.id as string } },
              })
            }}
          >
            {translate('text_1732182455718y0m5fijuray')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 flex flex-col gap-8">
        <div className="flex w-full items-center">
          <Typography className="w-35" variant="caption" color="grey600">
            {translate('text_1731515447290xbe4iqm5n6r')}
          </Typography>
          <Typography className="flex-1" variant="body" color="grey700">
            {!!apiKey?.lastUsedAt
              ? intlFormatDateTime(apiKey?.lastUsedAt, {
                  timezone: TimezoneEnum.TzUtc,
                }).date
              : '-'}
          </Typography>
        </div>
      </div>
    </Dialog>
  )
})

DeleteApiKeyDialog.displayName = 'DeleteApiKeyDialog'
