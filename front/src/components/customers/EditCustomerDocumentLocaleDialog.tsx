import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { Typography } from '~/components/designSystem/Typography'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast } from '~/core/apolloClient'
import { documentLocalesDataForComboBox } from '~/core/translations/documentLocales'
import {
  EditCustomerDocumentLocaleFragment,
  useUpdateCustomerDocumentLocaleMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  fragment EditCustomerDocumentLocale on Customer {
    id
    name
    displayName
    externalId
    billingConfiguration {
      id
      documentLocale
    }
  }

  mutation updateCustomerDocumentLocale($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      billingConfiguration {
        id
        documentLocale
      }
    }
  }
`

export const EDIT_CUSTOMER_DOCUMENT_LOCALE_FORM_ID = 'edit-customer-document-locale-form'

const editCustomerDocumentLocaleValidationSchema = z.object({
  documentLocale: z
    .string({ message: 'text_624ea7c29103fd010732ab7d' })
    .min(1, { message: 'text_624ea7c29103fd010732ab7d' }),
})

export const useEditCustomerDocumentLocaleDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const customerRef = useRef<EditCustomerDocumentLocaleFragment | null>(null)
  const successRef = useRef(false)

  const [updateDocumentLocale] = useUpdateCustomerDocumentLocaleMutation({
    onCompleted(res) {
      if (res.updateCustomer) {
        addToast({
          severity: 'success',
          translateKey: !!customerRef.current?.billingConfiguration?.documentLocale
            ? 'text_63ea0f84f400488553caa76f'
            : 'text_63ea0f84f400488553caa77b',
        })
      }
    },
  })

  const form = useAppForm({
    defaultValues: {
      documentLocale: '' as string,
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editCustomerDocumentLocaleValidationSchema,
    },
    onSubmit: async ({ value }) => {
      const customer = customerRef.current

      if (!customer) {
        return
      }

      const result = await updateDocumentLocale({
        variables: {
          input: {
            id: customer.id,
            billingConfiguration: {
              documentLocale: value.documentLocale,
            },
            // NOTE: API should not require those fields on customer update
            // To be tackled as improvement
            externalId: customer.externalId,
            name: customer.name || '',
          },
        },
      })

      if (result.data?.updateCustomer) {
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

  const openEditCustomerDocumentLocaleDialog = (customer: EditCustomerDocumentLocaleFragment) => {
    customerRef.current = customer
    const isEdition = !!customer.billingConfiguration?.documentLocale

    form.reset()
    form.setFieldValue('documentLocale', customer.billingConfiguration?.documentLocale ?? '')

    formDialog
      .open({
        title: translate(
          isEdition ? 'text_63ea0f84f400488553caa65c' : 'text_63ea0f84f400488553caa678',
        ),
        description: (
          <Typography
            html={translate('text_63ea0f84f400488553caa680', {
              customerName: `<span class="line-break-anywhere">${customer.displayName}</span>`,
            })}
          />
        ),
        children: (
          <div className="p-8">
            <form.AppField name="documentLocale">
              {(field) => (
                <field.ComboBoxField
                  disableClearable
                  label={translate('text_63ea0f84f400488553caa687')}
                  placeholder={translate('text_63ea0f84f400488553caa68f')}
                  helperText={
                    <Typography
                      variant="caption"
                      html={translate('text_63e51ef4985f0ebd75c21312')}
                    />
                  }
                  data={documentLocalesDataForComboBox}
                  PopperProps={{ displayInDialog: true }}
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>
              {translate(
                isEdition ? 'text_63ea0f84f400488553caa681' : 'text_63ea0f84f400488553caa6ad',
              )}
            </form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_CUSTOMER_DOCUMENT_LOCALE_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          customerRef.current = null
        }
      })
  }

  return { openEditCustomerDocumentLocaleDialog }
}
