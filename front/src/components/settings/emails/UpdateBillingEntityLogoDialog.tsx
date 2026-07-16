import { gql } from '@apollo/client'
import { forwardRef, useState } from 'react'
import { useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { LogoPicker } from '~/components/LogoPicker'
import { useGetBillingEntityQuery, useUpdateBillingEntityLogoMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation updateBillingEntityLogo($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      logoUrl
    }
  }
`

export type UpdateBillingEntityLogoDialogRef = DialogRef

type TUpdateBillingEntityLogoDialog = {
  existingLogoUrl: string | null | undefined
}

export const UpdateBillingEntityLogoDialog = forwardRef<
  UpdateBillingEntityLogoDialogRef,
  TUpdateBillingEntityLogoDialog
>(({ existingLogoUrl }, ref) => {
  const { billingEntityCode } = useParams<string>()
  const { translate } = useInternationalization()
  const [logo, setLogo] = useState<string | null>()
  const [updateLogo] = useUpdateBillingEntityLogoMutation()

  const { data: billingEntityData } = useGetBillingEntityQuery({
    variables: {
      code: billingEntityCode as string,
    },
    skip: !billingEntityCode,
  })

  const billingEntity = billingEntityData?.billingEntity

  return (
    <Dialog
      ref={ref}
      title={translate('text_6411e69b9bda18008db7ad51')}
      description={translate('text_6411e6a2de0b3f00b25ae488')}
      onClose={() => {
        setLogo(undefined)
      }}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            variant="primary"
            disabled={logo === undefined}
            onClick={async () => {
              await updateLogo({
                variables: { input: { id: billingEntity?.id as string, logo } },
              })
              closeDialog()
            }}
          >
            {translate('text_6411e6ac9a8c9700a7570a4e')}
          </Button>
        </>
      )}
    >
      <LogoPicker
        className="mb-8"
        logoValue={logo}
        onChange={(value) => setLogo(value)}
        logoUrl={existingLogoUrl}
      />
    </Dialog>
  )
})

UpdateBillingEntityLogoDialog.displayName = 'UpdateBillingEntityLogoDialog'
