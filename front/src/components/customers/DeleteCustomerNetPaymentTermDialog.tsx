import { gql } from '@apollo/client'
import { forwardRef } from 'react'

import { DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { addToast } from '~/core/apolloClient'
import {
  DeleteCustomerNetPaymentTermFragment,
  useDeleteCustomerNetPaymentTermMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteCustomerNetPaymentTerm on Customer {
    id
    externalId
    name
    displayName
    netPaymentTerm
  }

  mutation deleteCustomerNetPaymentTerm($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      ...DeleteCustomerNetPaymentTerm
    }
  }
`

export type DeleteOrganizationNetPaymentTermDialogRef = WarningDialogRef

interface DeleteOrganizationNetPaymentTermDialogProps {
  customer: DeleteCustomerNetPaymentTermFragment
}

export const DeleteOrganizationNetPaymentTermDialog = forwardRef<
  DialogRef,
  DeleteOrganizationNetPaymentTermDialogProps
>(({ customer }: DeleteOrganizationNetPaymentTermDialogProps, ref) => {
  const customerName = customer?.displayName
  const [deleteCustomerNetPaymentTerm] = useDeleteCustomerNetPaymentTermMutation({
    onCompleted(data) {
      if (data && data.updateCustomer) {
        addToast({
          message: translate('text_64c7a89b6c67eb6c98898357'),
          severity: 'success',
        })
      }
    },
  })
  const { translate } = useInternationalization()

  return (
    <WarningDialog
      ref={ref}
      title={translate('text_64c7a89b6c67eb6c988980db')}
      description={
        <Typography
          html={translate('text_64c7a89b6c67eb6c988980f9', {
            customerName: `<span class="line-break-anywhere">${customerName}</span>`,
          })}
        />
      }
      onContinue={async () =>
        await deleteCustomerNetPaymentTerm({
          variables: {
            input: {
              id: customer.id,
              netPaymentTerm: null,
              // NOTE: API should not require those fields on customer update
              // To be tackled as improvement
              externalId: customer.externalId,
              name: customer.name || '',
            },
          },
        })
      }
      continueText={translate('text_64c7a89b6c67eb6c98898133')}
    />
  )
})

DeleteOrganizationNetPaymentTermDialog.displayName = 'DeleteOrganizationNetPaymentTermDialog'
