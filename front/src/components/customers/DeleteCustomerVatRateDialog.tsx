import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  CustomerAppliedTaxRatesForSettingsFragmentDoc,
  EditCustomerVatRateFragment,
  TaxRateForDeleteCustomerVatRateDialogFragment,
  useRemoveAppliedTaxRateOnCustomerMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment CustomerForDeleteVatRateDialog on Customer {
    id
    name
    externalId
    taxes {
      id
      code
    }
  }

  fragment TaxRateForDeleteCustomerVatRateDialog on Tax {
    id
    name
  }

  mutation removeAppliedTaxRateOnCustomer($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
    }
  }

  ${CustomerAppliedTaxRatesForSettingsFragmentDoc}
`

type DeleteCustomerVatRateDialogData = {
  customer: EditCustomerVatRateFragment
  taxRate: TaxRateForDeleteCustomerVatRateDialogFragment
}

export const useDeleteCustomerVatRateDialog = () => {
  const { translate } = useInternationalization()
  const centralizedDialog = useCentralizedDialog()
  const [removeAppliedTaxRateOnCustomer] = useRemoveAppliedTaxRateOnCustomerMutation({
    onCompleted({ updateCustomer }) {
      if (updateCustomer?.id) {
        addToast({
          message: translate('text_64639f5e63a5cc0076779dd9'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getCustomerSettings'],
  })

  const openDeleteCustomerVatRateDialog = ({
    customer,
    taxRate,
  }: DeleteCustomerVatRateDialogData) => {
    centralizedDialog.open({
      title: translate('text_64639f5e63a5cc0076779d37', {
        name: taxRate.name,
      }),
      description: translate('text_64639f5e63a5cc0076779d3b'),
      colorVariant: 'danger',
      actionText: translate('text_64639f5e63a5cc0076779d43'),
      onAction: async () => {
        await removeAppliedTaxRateOnCustomer({
          variables: {
            input: {
              id: customer.id,
              taxCodes:
                customer.taxes?.filter((tax) => tax.id !== taxRate.id).map((tax) => tax.code) || [],
              // NOTE: API should not require those fields on customer update
              // To be tackled as improvement
              externalId: customer.externalId || '',
              name: customer.name || '',
            },
          },
        })
      },
    })
  }

  return { openDeleteCustomerVatRateDialog }
}
