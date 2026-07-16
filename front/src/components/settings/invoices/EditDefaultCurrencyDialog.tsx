import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast } from '~/core/apolloClient'
import {
  CurrencyEnum,
  EditBillingEntityDefaultCurrencyForDialogFragment,
  useUpdateBillingEntityDefaultCurrencyMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  fragment EditBillingEntityDefaultCurrencyForDialog on BillingEntity {
    id
    defaultCurrency
  }

  mutation updateBillingEntityDefaultCurrency($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      ...EditBillingEntityDefaultCurrencyForDialog
    }
  }
`

export const EDIT_DEFAULT_CURRENCY_FORM_ID = 'edit-default-currency-form'

const EDIT_DEFAULT_CURRENCY_DIALOG_SUBMIT_BUTTON_TEST_ID =
  'edit-default-currency-dialog-submit-button'
const EDIT_DEFAULT_CURRENCY_DIALOG_CURRENCY_FIELD_TEST_ID =
  'edit-default-currency-dialog-currency-field'

const editDefaultCurrencyValidationSchema = z.object({
  defaultCurrency: z.enum(CurrencyEnum),
})

const initialValues = {
  defaultCurrency: CurrencyEnum.Usd,
}

type EditDefaultCurrencyDialogData = {
  billingEntity?: EditBillingEntityDefaultCurrencyForDialogFragment | null
}

export const useEditDefaultCurrencyDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const dataRef = useRef<EditDefaultCurrencyDialogData | null>(null)
  const successRef = useRef(false)

  const [updateBillingEntity] = useUpdateBillingEntityDefaultCurrencyMutation({
    onCompleted(res) {
      if (res?.updateBillingEntity) {
        addToast({
          severity: 'success',
          translateKey: 'text_6543ca0fdebf76a18e159303',
        })
      }
    },
    refetchQueries: ['getBillingEntitySettings'],
  })

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editDefaultCurrencyValidationSchema,
    },
    onSubmit: async ({ value }) => {
      const result = await updateBillingEntity({
        variables: {
          input: {
            id: dataRef.current?.billingEntity?.id as string,
            ...value,
          },
        },
      })

      if (result.data?.updateBillingEntity) {
        successRef.current = true
      }
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    successRef.current = false
    await form.handleSubmit()

    if (!successRef.current) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openEditDefaultCurrencyDialog = (data: EditDefaultCurrencyDialogData) => {
    dataRef.current = data
    form.reset()
    form.setFieldValue('defaultCurrency', data.billingEntity?.defaultCurrency || CurrencyEnum.Usd)

    formDialog
      .open({
        title: translate('text_6543ca0fdebf76a18e159294'),
        description: translate('text_6543ca0fdebf76a18e159298'),
        cancelOrCloseText: 'cancel',
        children: (
          <div className="flex flex-col gap-3 p-8">
            <form.AppField name="defaultCurrency">
              {(field) => (
                <field.ComboBoxField
                  disableClearable
                  label={translate('text_6543ca0fdebf76a18e15929c')}
                  data={Object.values(CurrencyEnum).map((currencyType) => ({
                    value: currencyType,
                  }))}
                  PopperProps={{ displayInDialog: true }}
                  dataTest={EDIT_DEFAULT_CURRENCY_DIALOG_CURRENCY_FIELD_TEST_ID}
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton dataTest={EDIT_DEFAULT_CURRENCY_DIALOG_SUBMIT_BUTTON_TEST_ID}>
              {translate('text_17432414198706rdwf76ek3u')}
            </form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_DEFAULT_CURRENCY_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          dataRef.current = null
        }
      })
  }

  return { openEditDefaultCurrencyDialog }
}
