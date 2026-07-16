import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef } from 'react'
import { object, string } from 'yup'

import { DialogRef } from '~/components/designSystem/Dialog'
import { EditInvoiceIssuingDatePolicyDialogContentBase } from '~/components/invoiceIssuingDatePolicy/EditInvoiceIssuingDatePolicyDialogContentBase'
import { addToast } from '~/core/apolloClient'
import { ALL_ADJUSTMENT_VALUES, ALL_ANCHOR_VALUES } from '~/core/constants/issuingDatePolicy'
import {
  BillingEntitySubscriptionInvoiceIssuingDateAdjustmentEnum,
  BillingEntitySubscriptionInvoiceIssuingDateAnchorEnum,
  EditBillingEntityInvoiceIssuingDatePolicyDialogFragment,
  useUpdateBillingEntityInvoiceIssuingDatePolicyMutation,
} from '~/generated/graphql'
import { useIssuingDatePolicy } from '~/hooks/useIssuingDatePolicy'

gql`
  fragment EditBillingEntityInvoiceIssuingDatePolicyDialog on BillingEntity {
    id
    billingConfiguration {
      invoiceGracePeriod
      subscriptionInvoiceIssuingDateAdjustment
      subscriptionInvoiceIssuingDateAnchor
    }
  }

  mutation updateBillingEntityInvoiceIssuingDatePolicy($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      ...EditBillingEntityInvoiceIssuingDatePolicyDialog
    }
  }
`

type EditBillingEntityInvoiceIssuingDatePolicyDialogProps = {
  billingEntity: EditBillingEntityInvoiceIssuingDatePolicyDialogFragment
}

export type EditBillingEntityInvoiceIssuingDatePolicyDialogRef = DialogRef

export const EditBillingEntityInvoiceIssuingDatePolicyDialog = forwardRef<
  EditBillingEntityInvoiceIssuingDatePolicyDialogRef,
  EditBillingEntityInvoiceIssuingDatePolicyDialogProps
>(({ billingEntity }: EditBillingEntityInvoiceIssuingDatePolicyDialogProps, ref) => {
  const { getIssuingDateInfoForAlert } = useIssuingDatePolicy()

  const [updateBillingEntityInvoiceIssuingDatePolicy] =
    useUpdateBillingEntityInvoiceIssuingDatePolicyMutation({
      onCompleted(res) {
        if (!res?.updateBillingEntity) return

        addToast({
          severity: 'success',
          translateKey: 'text_1763407386500wkf13gr42tj',
        })
      },
      refetchQueries: ['getBillingEntitySettings'],
    })

  const formikProps = useFormik({
    initialValues: {
      subscriptionInvoiceIssuingDateAdjustment:
        billingEntity.billingConfiguration?.subscriptionInvoiceIssuingDateAdjustment,
      subscriptionInvoiceIssuingDateAnchor:
        billingEntity.billingConfiguration?.subscriptionInvoiceIssuingDateAnchor,
    },
    validationSchema: object().shape({
      subscriptionInvoiceIssuingDateAdjustment: string().nullable(),
      subscriptionInvoiceIssuingDateAnchor: string().nullable(),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async (values) => {
      await updateBillingEntityInvoiceIssuingDatePolicy({
        variables: {
          input: {
            id: billingEntity.id,
            billingConfiguration: {
              subscriptionInvoiceIssuingDateAdjustment:
                values.subscriptionInvoiceIssuingDateAdjustment ||
                BillingEntitySubscriptionInvoiceIssuingDateAdjustmentEnum.AlignWithFinalizationDate,
              subscriptionInvoiceIssuingDateAnchor:
                values.subscriptionInvoiceIssuingDateAnchor ||
                BillingEntitySubscriptionInvoiceIssuingDateAnchorEnum.NextPeriodStart,
            },
          },
        },
      })
    },
  })

  const { descriptionCopyAsHtml, expectedIssuingDateCopy } = getIssuingDateInfoForAlert({
    gracePeriod: billingEntity.billingConfiguration?.invoiceGracePeriod,
    subscriptionInvoiceIssuingDateAdjustment: formikProps.values
      .subscriptionInvoiceIssuingDateAdjustment as
      (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES] | undefined,
    subscriptionInvoiceIssuingDateAnchor: formikProps.values
      .subscriptionInvoiceIssuingDateAnchor as
      (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES] | undefined,
  })

  return (
    <EditInvoiceIssuingDatePolicyDialogContentBase
      formikProps={formikProps}
      ref={ref}
      descriptionCopyAsHtml={descriptionCopyAsHtml}
      expectedIssuingDateCopy={expectedIssuingDateCopy}
    />
  )
})

EditBillingEntityInvoiceIssuingDatePolicyDialog.displayName = 'forwardRef'
