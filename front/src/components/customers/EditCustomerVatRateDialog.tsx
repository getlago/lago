import { gql } from '@apollo/client'
import { forwardRef, useMemo, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox, ComboboxItem } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { SEARCH_TAX_INPUT_FOR_CUSTOMER_CLASSNAME } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CREATE_TAX_ROUTE } from '~/core/router'
import {
  CustomerAppliedTaxRatesForSettingsFragmentDoc,
  EditCustomerVatRateFragment,
  useCreateCustomerAppliedTaxMutation,
  useGetTaxRatesForEditCustomerLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  fragment EditCustomerVatRate on Customer {
    id
    name
    displayName
    externalId
    taxes {
      id
      code
    }
  }

  query getTaxRatesForEditCustomer($limit: Int, $page: Int, $searchTerm: String) {
    taxes(limit: $limit, page: $page, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        name
        rate
        code
      }
    }
  }

  mutation createCustomerAppliedTax($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      ...CustomerAppliedTaxRatesForSettings
    }
  }

  ${CustomerAppliedTaxRatesForSettingsFragmentDoc}
`

export type EditCustomerVatRateDialogRef = DialogRef

interface EditCustomerVatRateDialogProps {
  customer: EditCustomerVatRateFragment
  appliedTaxRatesTaxesIds?: string[]
  forceOpen?: boolean
}

export const EditCustomerVatRateDialog = forwardRef<DialogRef, EditCustomerVatRateDialogProps>(
  (
    { appliedTaxRatesTaxesIds, customer, forceOpen = false }: EditCustomerVatRateDialogProps,
    ref,
  ) => {
    const { translate } = useInternationalization()
    const { hasPermissions } = usePermissions()
    const [localTax, setLocalTax] = useState<string>('')
    const [getTaxRates, { loading, data }] = useGetTaxRatesForEditCustomerLazyQuery({
      variables: { limit: 500 },
    })
    const customerName = customer?.displayName
    const [createCustomerAppliedTax] = useCreateCustomerAppliedTaxMutation({
      onCompleted({ updateCustomer: mutationRes }) {
        if (mutationRes?.id) {
          addToast({
            message: translate('text_64639f5e63a5cc0076779de0'),
            severity: 'success',
          })
        }
      },
    })

    const comboboxTaxRatesData = useMemo(() => {
      if (!data || !data?.taxes || !data?.taxes?.collection) return []

      return data?.taxes?.collection.map((taxRate) => {
        const { id, name, rate, code } = taxRate
        const formatedRate = intlFormatNumber(Number(rate) / 100 || 0, {
          style: 'percent',
        })

        return {
          label: `${name} (${formatedRate})`,
          labelNode: (
            <ComboboxItem>
              <Typography variant="body" color="grey700" noWrap>
                {name}
              </Typography>
              <Typography variant="caption" color="grey600" noWrap>
                {formatedRate}
              </Typography>
            </ComboboxItem>
          ),
          value: code,
          disabled: appliedTaxRatesTaxesIds?.includes(id),
        }
      })
    }, [appliedTaxRatesTaxesIds, data])

    return (
      <Dialog
        open={!!forceOpen}
        ref={ref}
        title={translate('text_64639f5e63a5cc0076779d42', { name: customerName })}
        description={translate('text_64639f5e63a5cc0076779d46')}
        onClose={() => {
          setLocalTax('')
        }}
        actions={({ closeDialog }) => (
          <>
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_627387d5053a1000c5287cab')}
            </Button>
            <Button
              variant="primary"
              disabled={!localTax}
              onClick={async () => {
                const res = await createCustomerAppliedTax({
                  variables: {
                    input: {
                      id: customer.id,
                      taxCodes: [...(customer?.taxes?.map((t) => t.code) || []), localTax],
                      // NOTE: API should not require those fields on customer update
                      // To be tackled as improvement
                      externalId: customer.externalId,
                      name: customer.name || '',
                    },
                  },
                })

                if (res.errors) return
                closeDialog()
              }}
            >
              {translate('text_64639f5e63a5cc0076779d57')}
            </Button>
          </>
        )}
        data-test="edit-customer-vat-rate-dialog"
      >
        <div className="mb-8">
          <ComboBox
            allowAddValue
            className={SEARCH_TAX_INPUT_FOR_CUSTOMER_CLASSNAME}
            addValueProps={
              hasPermissions(['organizationTaxesUpdate'])
                ? {
                    label: translate('text_64639c4d172d7a006ef30516'),
                    redirectionUrl: CREATE_TAX_ROUTE,
                  }
                : undefined
            }
            data={comboboxTaxRatesData}
            label={translate('text_64639c4d172d7a006ef30514')}
            loading={loading}
            onChange={setLocalTax}
            placeholder={translate('text_64639c4d172d7a006ef30515')}
            PopperProps={{ displayInDialog: true }}
            searchQuery={getTaxRates}
            value={localTax}
          />
        </div>
      </Dialog>
    )
  },
)

EditCustomerVatRateDialog.displayName = 'forwardRef'
