import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useMemo, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import {
  useApplyBillingEntityTaxesMutation,
  useGetTaxesForApplyTaxLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  APPLY_TAX_DIALOG_SUBMIT_BUTTON_TEST_ID,
  APPLY_TAX_DIALOG_TEST_ID,
} from '~/pages/settings/BillingEntity/sections/taxes/dataTestConstants'

gql`
  fragment TaxItemForApplyTax on Tax {
    id
    code
    name
  }

  query getTaxesForApplyTax($limit: Int, $page: Int, $searchTerm: String) {
    taxes(limit: $limit, page: $page, order: "name", searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        ...TaxItemForApplyTax
      }
    }
  }

  mutation applyBillingEntityTaxes($input: ApplyTaxesInput!) {
    billingEntityApplyTaxes(input: $input) {
      __typename
    }
  }
`

export type ApplyTaxDialogRef = {
  openDialog: (billingEntityId: string) => unknown
  closeDialog: () => unknown
}

export const ApplyTaxDialog = forwardRef<ApplyTaxDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)

  const [getTaxes, { data, loading }] = useGetTaxesForApplyTaxLazyQuery({
    variables: {
      limit: 50,
    },
    notifyOnNetworkStatusChange: true,
  })

  const [applyTax] = useApplyBillingEntityTaxesMutation({
    onCompleted(_data) {
      if (_data) {
        addToast({
          message: translate('text_1743600025133ouzufhpiyw8'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getBillingEntityTaxes'],
  })

  const taxes = useMemo(
    () =>
      data?.taxes?.collection?.map((item) => ({
        value: item.code,
        label: item.name,
        description: item.code,
      })) || [],
    [data],
  )

  const [billingEntityId, setBillingEntityId] = useState<string | null>(null)
  const [taxCode, setTaxCode] = useState<string | null>(null)

  useImperativeHandle(ref, () => ({
    openDialog: (_billingEntityId) => {
      setBillingEntityId(_billingEntityId)

      dialogRef.current?.openDialog()
    },
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  return (
    <Dialog
      ref={dialogRef}
      data-test={APPLY_TAX_DIALOG_TEST_ID}
      title={translate('text_1743600025132l3aadb2il09')}
      description={<Typography>{translate('text_17436000251322d5x6wtpjq1')}</Typography>}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_63eba8c65a6c8043feee2a14')}
          </Button>

          <Button
            variant="primary"
            data-test={APPLY_TAX_DIALOG_SUBMIT_BUTTON_TEST_ID}
            onClick={async () => {
              if (billingEntityId && taxCode) {
                applyTax({
                  variables: {
                    input: {
                      billingEntityId,
                      taxCodes: [taxCode],
                    },
                  },
                })
              }

              closeDialog()
            }}
          >
            {translate('text_1743600025133natje9qmw0q')}
          </Button>
        </>
      )}
    >
      <ComboBox
        name="billingEntityApplyTaxes"
        label={translate('text_1743241419870gwqt1b54uuq')}
        className="mb-8"
        loading={loading}
        data={taxes}
        value={taxCode || ''}
        onChange={(t) => setTaxCode(t)}
        searchQuery={getTaxes}
        placeholder={translate('text_17436000251334xxp8qsljsk')}
        PopperProps={{ displayInDialog: true }}
        emptyText={translate('text_1743600025133454kb04evs6')}
      />
    </Dialog>
  )
})

ApplyTaxDialog.displayName = 'ApplyTaxDialog'
