import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef } from 'react'
import { object, string } from 'yup'

import { DialogRef } from '~/components/designSystem/Dialog'
import { EditInvoiceIssuingDatePolicyDialogContentBase } from '~/components/invoiceIssuingDatePolicy/EditInvoiceIssuingDatePolicyDialogContentBase'
import { addToast } from '~/core/apolloClient'
import { ALL_ADJUSTMENT_VALUES, ALL_ANCHOR_VALUES } from '~/core/constants/issuingDatePolicy'
import {
  EditCustomerIssuingDatePolicyDialogFragment,
  useUpdateCustomerIssuingDatePolicyMutation,
} from '~/generated/graphql'
import { useIssuingDatePolicy } from '~/hooks/useIssuingDatePolicy'

gql`
  fragment EditCustomerIssuingDatePolicyDialog on Customer {
    id
    invoiceGracePeriod
    externalId
    billingConfiguration {
      subscriptionInvoiceIssuingDateAdjustment
      subscriptionInvoiceIssuingDateAnchor
    }
  }

  mutation updateCustomerIssuingDatePolicy($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      ...EditCustomerIssuingDatePolicyDialog
    }
  }
`
type EditCustomerIssuingDatePolicyDialogProps = {
  customer: EditCustomerIssuingDatePolicyDialogFragment
}
export type EditCustomerIssuingDatePolicyDialogRef = DialogRef

export const EditCustomerIssuingDatePolicyDialog = forwardRef<
  EditCustomerIssuingDatePolicyDialogRef,
  EditCustomerIssuingDatePolicyDialogProps
>(({ customer }: EditCustomerIssuingDatePolicyDialogProps, ref) => {
  const { getIssuingDateInfoForAlert } = useIssuingDatePolicy()

  const [updateCustomerIssuingDatePolicy] = useUpdateCustomerIssuingDatePolicyMutation({
    onCompleted(res) {
      if (!res?.updateCustomer) return

      const isDeleting =
        !formikProps.values.subscriptionInvoiceIssuingDateAdjustment &&
        !formikProps.values.subscriptionInvoiceIssuingDateAnchor
      const translateKey = isDeleting
        ? 'text_1763407386499oel0dxfrp8i'
        : 'text_1763407386500wkf13gr42tj'

      addToast({
        severity: 'success',
        translateKey,
      })
    },
    refetchQueries: ['getCustomerSettings'],
  })

  const formikProps = useFormik({
    initialValues: {
      subscriptionInvoiceIssuingDateAdjustment:
        customer.billingConfiguration?.subscriptionInvoiceIssuingDateAdjustment || undefined,
      subscriptionInvoiceIssuingDateAnchor:
        customer.billingConfiguration?.subscriptionInvoiceIssuingDateAnchor || undefined,
    },
    validationSchema: object().shape({
      subscriptionInvoiceIssuingDateAdjustment: string().nullable(),
      subscriptionInvoiceIssuingDateAnchor: string().nullable(),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async (values) => {
      await updateCustomerIssuingDatePolicy({
        variables: {
          input: {
            id: customer.id,
            externalId: customer.externalId,
            billingConfiguration: {
              subscriptionInvoiceIssuingDateAdjustment:
                values.subscriptionInvoiceIssuingDateAdjustment,
              subscriptionInvoiceIssuingDateAnchor: values.subscriptionInvoiceIssuingDateAnchor,
            },
          },
        },
      })
    },
  })

  const { descriptionCopyAsHtml, expectedIssuingDateCopy } = getIssuingDateInfoForAlert({
    gracePeriod: customer.invoiceGracePeriod || 0,
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

EditCustomerIssuingDatePolicyDialog.displayName = 'forwardRef'
