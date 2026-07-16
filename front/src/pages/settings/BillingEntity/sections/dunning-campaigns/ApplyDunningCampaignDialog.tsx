import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useMemo, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import {
  BillingEntity,
  useApplyBillingEntityDunningCampaignMutation,
  useGetDunningCampaignsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation applyBillingEntityDunningCampaign(
    $input: BillingEntityUpdateAppliedDunningCampaignInput!
  ) {
    billingEntityUpdateAppliedDunningCampaign(input: $input) {
      id
    }
  }
`

export type ApplyDunningCampaignDialogRef = {
  openDialog: (billingEntity: BillingEntity) => unknown
  closeDialog: () => unknown
}

export const ApplyDunningCampaignDialog = forwardRef<ApplyDunningCampaignDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)
  const [billingEntity, setBillingEntity] = useState<BillingEntity | null>(null)
  const [appliedDunningCampaignId, setAppliedDunningCampaignId] = useState<string | null>(null)

  const { data, loading } = useGetDunningCampaignsQuery()

  const clear = () => {
    setAppliedDunningCampaignId(null)
    setBillingEntity(null)
  }

  const [applyBillingEntityDunningCampaign] = useApplyBillingEntityDunningCampaignMutation({
    onCompleted(_data) {
      if (_data) {
        addToast({
          message: translate('text_1750663218390945tme6j9he'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getBillingEntity'],
  })

  useImperativeHandle(ref, () => ({
    openDialog: (_billingEntity) => {
      clear()

      setBillingEntity(_billingEntity)

      dialogRef.current?.openDialog()
    },
    closeDialog: () => {
      clear()

      dialogRef.current?.closeDialog()
    },
  }))

  const dunningCampaigns = useMemo(
    () =>
      data?.dunningCampaigns?.collection?.map((item) => ({
        value: item.id,
        label: item.name,
        description: item.code,
      })) || [],
    [data],
  )

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_17506632183903il25h0wuik')}
      description={<Typography>{translate('text_1750663218390ndvitukei2q')}</Typography>}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_63eba8c65a6c8043feee2a14')}
          </Button>

          <Button
            variant="primary"
            disabled={!appliedDunningCampaignId}
            onClick={async () => {
              if (billingEntity && appliedDunningCampaignId) {
                applyBillingEntityDunningCampaign({
                  variables: {
                    input: {
                      appliedDunningCampaignId: appliedDunningCampaignId,
                      billingEntityId: billingEntity.id,
                    },
                  },
                })
              }

              closeDialog()
            }}
          >
            {translate('text_1750663218390xxlt86n0fhu')}
          </Button>
        </>
      )}
    >
      <ComboBox
        name="billingEntityApplyDunningCampaign"
        label={translate('text_1750663218390lixhj94mgbp')}
        className="mb-8"
        loading={loading}
        data={dunningCampaigns}
        value={appliedDunningCampaignId || ''}
        onChange={(t) => setAppliedDunningCampaignId(t)}
        placeholder={translate('text_1750663218390emesat7jusk')}
        PopperProps={{ displayInDialog: true }}
        emptyText={translate('text_1750663218390rdqsn5fzioi')}
      />
    </Dialog>
  )
})

ApplyDunningCampaignDialog.displayName = 'ApplyDunningCampaignDialog'
