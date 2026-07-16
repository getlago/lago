import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { ComboBox, ComboboxItem } from '~/components/form'
import { SEARCH_TAX_INPUT_FOR_INVOICE_ADD_ON_CLASSNAME } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { useGetTaxesForInvoiceEditTaxDialogQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'

import { LocalFeeInput } from './types'

gql`
  fragment TaxForInvoiceEditTaxDialog on Tax {
    id
    name
    rate
    code
  }

  fragment AddOnForInvoiceEditTaxDialog on AddOn {
    id
    taxes {
      id
      ...TaxForInvoiceEditTaxDialog
    }
  }

  query getTaxesForInvoiceEditTaxDialog($limit: Int, $page: Int) {
    taxes(limit: $limit, page: $page) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        ...TaxForInvoiceEditTaxDialog
      }
    }
  }
`

export const EDIT_INVOICE_ITEM_TAX_FORM_ID = 'edit-invoice-item-tax-form'

type OpenEditInvoiceItemTaxDialogParams = {
  taxes?: LocalFeeInput['taxes']
  callback: (newTaxesArray: LocalFeeInput['taxes']) => void
}

const editInvoiceItemTaxFormDefaultValues: { taxes: LocalFeeInput['taxes'] } = {
  taxes: [],
}

const editInvoiceItemTaxValidationSchema = z.object({
  taxes: z.array(z.any()).refine((taxes) => taxes.every((tax) => !!tax?.id), {
    message: 'text_1782385268545ex9rk4gx0rf',
  }),
})

const EditInvoiceItemTaxDialogContent = withForm({
  defaultValues: editInvoiceItemTaxFormDefaultValues,
  render: function Render({ form }) {
    const { translate } = useInternationalization()
    const { data: taxesData, loading: taxesLoading } = useGetTaxesForInvoiceEditTaxDialogQuery({
      variables: { limit: 1000 },
    })
    const { collection: taxesCollection } = taxesData?.taxes || {}

    const taxes = useStore(form.store, (state) => state.values.taxes) || []

    // Array-level refine error (a row without an id). Lands on the `taxes` field
    // meta; surface it on the offending empty rows after a submit attempt.
    const taxesErrorMessage = useStore(
      form.store,
      (state) => state.fieldMeta.taxes?.errors?.[0]?.message,
    )

    // Include the currently selected taxes in the options so a pre-selected
    // value still resolves before the taxes query has finished loading.
    const taxOptions = [
      ...(taxesCollection || []),
      ...(taxes || []).filter(
        (tax) => !!tax?.id && !(taxesCollection || []).some((t) => t?.id === tax?.id),
      ),
    ]

    return (
      <div className="p-8">
        {!taxes?.length ? (
          <Typography className="mb-4" variant="caption" color="grey600">
            {translate('text_64d40b7e80e64e40710a4935')}
          </Typography>
        ) : (
          <>
            <div className="mb-1">
              <Typography variant="captionHl" color="grey700">
                {translate('text_636bedf292786b19d3398f06')}
              </Typography>
            </div>
            <div className="mb-4 flex flex-col gap-3">
              {taxes.map((tax, i) => (
                <div key={`tax-${i}-item-${tax?.code}`} className="flex items-center gap-3">
                  <ComboBox
                    disableClearable
                    containerClassName="flex-1"
                    className={SEARCH_TAX_INPUT_FOR_INVOICE_ADD_ON_CLASSNAME}
                    data={[
                      ...taxOptions.map(({ id: localTaxId = '', name = '', rate = 0 }) => {
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
                          value: localTaxId,
                          disabled:
                            taxes?.map((t) => t?.id)?.includes(localTaxId) &&
                            localTaxId !== tax?.id,
                        }
                      }),
                    ]}
                    value={tax?.id || ''}
                    error={!tax?.id && taxesErrorMessage ? translate(taxesErrorMessage) : undefined}
                    loading={taxesLoading}
                    placeholder={translate('text_64be910fba8ef9208686a8e7')}
                    emptyText={translate('text_64be91fd0678965126e5657b')}
                    onChange={(newTaxId) => {
                      const newTaxObject = taxesCollection?.find((t) => t?.id === newTaxId)
                      const newTaxesArray = [...(taxes || [])].map((t, j) => {
                        if (j === i) {
                          return newTaxObject
                        }

                        return t
                      })

                      form.setFieldValue('taxes', newTaxesArray as LocalFeeInput['taxes'])
                    }}
                    PopperProps={{ displayInDialog: true }}
                  />
                  <Tooltip placement="top-end" title={translate('text_63aa085d28b8510cd46443ff')}>
                    <Button
                      variant="quaternary"
                      icon="trash"
                      data-test="remove-charge"
                      onClick={() => {
                        const currentTaxes = [...(taxes || [])]

                        currentTaxes.splice(i, 1)
                        form.setFieldValue('taxes', currentTaxes as LocalFeeInput['taxes'])
                      }}
                    />
                  </Tooltip>
                </div>
              ))}
            </div>
          </>
        )}

        <Button
          className="flex w-fit"
          startIcon="plus"
          variant="inline"
          onClick={() => {
            form.setFieldValue('taxes', [...(taxes || []), {}] as LocalFeeInput['taxes'])
          }}
          data-test="add-tax-button"
        >
          {translate('text_645bb193927b375079d289af')}
        </Button>
      </div>
    )
  },
})

export const useEditInvoiceItemTaxDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const callbackRef = useRef<((newTaxesArray: LocalFeeInput['taxes']) => void) | null>(null)

  const form = useAppForm({
    defaultValues: editInvoiceItemTaxFormDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editInvoiceItemTaxValidationSchema,
    },
    onSubmit: async ({ value }) => {
      callbackRef.current?.(value.taxes as LocalFeeInput['taxes'])
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    await form.handleSubmit()

    // On validation error onSubmit never runs and isSubmitSuccessful stays false:
    // throw to keep the dialog open (closeOnError: false swallows the error, inline
    // field errors stay visible). Returning a result would let FormDialog close it.
    if (!form.state.isSubmitSuccessful) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openEditInvoiceItemTaxDialog = ({
    taxes,
    callback,
  }: OpenEditInvoiceItemTaxDialogParams) => {
    callbackRef.current = callback
    form.reset({ taxes: (taxes || []) as LocalFeeInput['taxes'] }, { keepDefaultValues: true })

    formDialog
      .open({
        title: translate('text_645bb193927b375079d289b5'),
        description: translate('text_64d40b7e80e64e40710a4931'),
        cancelOrCloseText: 'cancel',
        children: <EditInvoiceItemTaxDialogContent form={form} />,
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton dataTest="edit-invoice-item-tax-dialog-submit-button">
              {translate('text_645bb193927b375079d289b5')}
            </form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_INVOICE_ITEM_TAX_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          callbackRef.current = null
        }
      })
  }

  return { openEditInvoiceItemTaxDialog }
}
