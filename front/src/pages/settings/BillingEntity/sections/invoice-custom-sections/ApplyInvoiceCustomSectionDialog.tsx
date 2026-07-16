import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useMemo, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import {
  BillingEntity,
  useApplyBillingEntityInvoiceCustomSectionMutation,
  useGetOrganizationSettingsInvoiceSectionsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation applyBillingEntityInvoiceCustomSection($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
    }
  }
`

export type ApplyInvoiceCustomSectionDialogRef = {
  openDialog: (billingEntity: BillingEntity) => unknown
  closeDialog: () => unknown
}

export const ApplyInvoiceCustomSectionDialog = forwardRef<ApplyInvoiceCustomSectionDialogRef>(
  (_, ref) => {
    const { translate } = useInternationalization()
    const dialogRef = useRef<DialogRef>(null)
    const [billingEntity, setBillingEntity] = useState<BillingEntity | null>(null)
    const [invoiceCustomSectionId, setInvoiceCustomSectionId] = useState<string | null>(null)

    const { data, loading } = useGetOrganizationSettingsInvoiceSectionsQuery()

    const clear = () => {
      setInvoiceCustomSectionId(null)
      setBillingEntity(null)
    }

    const [applyBillingEntityInvoiceCustomSection] =
      useApplyBillingEntityInvoiceCustomSectionMutation({
        onCompleted(_data) {
          if (_data) {
            addToast({
              message: translate('text_17490267676054m9hrn2vs3h'),
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

    const invoiceCustomSections = useMemo(
      () =>
        data?.invoiceCustomSections?.collection
          ?.filter(
            (item) => !billingEntity?.selectedInvoiceCustomSections?.find((s) => s.id === item.id),
          )
          .map((item) => ({
            value: item.id,
            label: item.name,
            description: item.code,
          })) || [],
      [data, billingEntity?.selectedInvoiceCustomSections],
    )

    return (
      <Dialog
        ref={dialogRef}
        title={translate('text_17490246341928gnllhmzx4w')}
        description={<Typography>{translate('text_1749024634192qi2o0ycntua')}</Typography>}
        actions={({ closeDialog }) => (
          <>
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_63eba8c65a6c8043feee2a14')}
            </Button>

            <Button
              variant="primary"
              disabled={!invoiceCustomSectionId}
              onClick={async () => {
                if (billingEntity && invoiceCustomSectionId) {
                  applyBillingEntityInvoiceCustomSection({
                    variables: {
                      input: {
                        id: billingEntity.id,
                        invoiceCustomSectionIds: [
                          ...(billingEntity.selectedInvoiceCustomSections?.map((s) => s.id) || []),
                          invoiceCustomSectionId,
                        ],
                      },
                    },
                  })
                }

                closeDialog()
              }}
            >
              {translate('text_1749026767605z63gakijt0o')}
            </Button>
          </>
        )}
      >
        <ComboBox
          name="billingEntityApplyCustomSection"
          label={translate('text_1749026767605u5u8ww3dhov')}
          className="mb-8"
          loading={loading}
          data={invoiceCustomSections}
          value={invoiceCustomSectionId || ''}
          onChange={(t) => setInvoiceCustomSectionId(t)}
          placeholder={translate('text_1749026767603ihrnxpf72wu')}
          PopperProps={{ displayInDialog: true }}
          emptyText={translate('text_17490267676058ycg9lekpiq')}
        />
      </Dialog>
    )
  },
)

ApplyInvoiceCustomSectionDialog.displayName = 'ApplyInvoiceCustomSectionDialog'
