import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef, useMemo } from 'react'
import { array, mixed, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { MultipleComboBox, RadioField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import {
  CustomerAppliedInvoiceCustomSectionsFragmentDoc,
  UpdateCustomerInput,
  useEditCustomerInvoiceCustomSectionMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerInvoiceCustomSections } from '~/hooks/useCustomerInvoiceCustomSections'
import { useInvoiceCustomSectionsLazy } from '~/hooks/useInvoiceCustomSections'

gql`
  mutation editCustomerInvoiceCustomSection($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      ...CustomerAppliedInvoiceCustomSections
    }

    ${CustomerAppliedInvoiceCustomSectionsFragmentDoc}
  }
`

enum BehaviorType {
  FALLBACK = 'fallback',
  CUSTOM_SECTIONS = 'customSections',
  DEACTIVATE = 'deactivate',
}

export type EditCustomerInvoiceCustomSectionsDialogRef = DialogRef

interface EditCustomerInvoiceCustomSectionsDialogProps {
  customerId: string
}

export const EditCustomerInvoiceCustomSectionsDialog = forwardRef<
  DialogRef,
  EditCustomerInvoiceCustomSectionsDialogProps
>(({ customerId }: EditCustomerInvoiceCustomSectionsDialogProps, ref) => {
  const { translate } = useInternationalization()

  const { data: customerData, customer } = useCustomerInvoiceCustomSections(customerId)

  const { getInvoiceCustomSections, data: orgInvoiceCustomSections } =
    useInvoiceCustomSectionsLazy()

  const options = useMemo(() => {
    return (orgInvoiceCustomSections ?? []).map((section) => ({
      labelNode: section.name,
      label: section.name,
      description: section.code,
      value: section.id,
    }))
  }, [orgInvoiceCustomSections])

  const [editCustomerInvoiceCustomSection] = useEditCustomerInvoiceCustomSectionMutation({
    refetchQueries: ['getCustomerSettings'],
    onCompleted: () => {
      addToast({
        severity: 'success',
        message: translate('text_17352280436833uy9uxzbqn7'),
      })
    },
  })

  const initialBehavior = useMemo((): BehaviorType => {
    if (customerData?.hasOverwrittenInvoiceCustomSectionsSelection) {
      return BehaviorType.CUSTOM_SECTIONS
    } else if (customerData?.skipInvoiceCustomSections) {
      return BehaviorType.DEACTIVATE
    }

    return BehaviorType.FALLBACK
  }, [customerData])

  const initialSectionIds = useMemo(() => {
    if (!customerData?.hasOverwrittenInvoiceCustomSectionsSelection) {
      return undefined
    }

    return customerData.configurableInvoiceCustomSections.map((section) => section.id)
  }, [customerData])

  const formikProps = useFormik<{
    behavior: BehaviorType | ''
    configurableInvoiceCustomSectionIds: string[] | undefined
  }>({
    initialValues: {
      behavior: initialBehavior,
      configurableInvoiceCustomSectionIds: initialSectionIds,
    },
    validationSchema: object().shape({
      behavior: mixed().oneOf(Object.values(BehaviorType)).required(''),
      configurableInvoiceCustomSectionIds: array()
        .of(string())
        .when('behavior', {
          is: (val: BehaviorType) => val === BehaviorType.CUSTOM_SECTIONS,
          then: (schema) => schema.min(1, ''),
        }),
    }),
    onSubmit: async (values) => {
      if (!customer) return

      let formattedValues: UpdateCustomerInput = {
        id: customer.id,
        externalId: customer.externalId,
      }

      switch (values.behavior) {
        case BehaviorType.FALLBACK:
          formattedValues = {
            ...formattedValues,
            skipInvoiceCustomSections: false,
            configurableInvoiceCustomSectionIds: [],
          }
          break
        case BehaviorType.CUSTOM_SECTIONS:
          formattedValues = {
            ...formattedValues,
            skipInvoiceCustomSections: false,
            configurableInvoiceCustomSectionIds: values.configurableInvoiceCustomSectionIds,
          }
          break
        case BehaviorType.DEACTIVATE:
          formattedValues = {
            ...formattedValues,
            skipInvoiceCustomSections: true,
            configurableInvoiceCustomSectionIds: null,
          }
          break
      }

      await editCustomerInvoiceCustomSection({ variables: { input: formattedValues } })
    },
    validateOnMount: true,
    enableReinitialize: true,
  })

  return (
    <Dialog
      ref={ref}
      onOpen={async () => {
        await getInvoiceCustomSections()
      }}
      title={translate('text_17352239389168sdqd97zo0t')}
      description={translate('text_1735223938916hla21yfwyzw')}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_63ea0f84f400488553caa6a5')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={async () => {
              await formikProps.submitForm()
              closeDialog()
            }}
          >
            {translate('text_1735223938916q9pq0j0z0ju')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 not-last-child:mb-4">
        <RadioField
          name="behavior"
          formikProps={formikProps}
          value={BehaviorType.FALLBACK}
          label={translate('text_17352239389166kugn45zj95')}
          labelVariant="body"
        />
        <RadioField
          name="behavior"
          formikProps={formikProps}
          value={BehaviorType.CUSTOM_SECTIONS}
          label={translate('text_1735223938916ed8ef8phwaz')}
          labelVariant="body"
        />
        {formikProps.values.behavior === BehaviorType.CUSTOM_SECTIONS && (
          <MultipleComboBox
            hideTags={false}
            forcePopupIcon
            name="configurableInvoiceCustomSectionIds"
            data={options}
            onChange={(section) =>
              formikProps.setFieldValue(
                'configurableInvoiceCustomSectionIds',
                section.map(({ value }) => value),
              )
            }
            value={
              formikProps.values.configurableInvoiceCustomSectionIds?.map((id) => {
                const foundSection = options.find((section) => section.value === id)

                return {
                  value: id,
                  label: foundSection?.label,
                }
              }) ?? []
            }
            placeholder={translate('text_1735223938916qvvv12r7je0')}
            PopperProps={{ displayInDialog: true }}
            emptyText={translate('text_173642092241713ws50zg9v4')}
          />
        )}
        <RadioField
          name="behavior"
          formikProps={formikProps}
          value={BehaviorType.DEACTIVATE}
          label={translate('text_1735223938916dhd7cyzokib')}
          labelVariant="body"
        />
      </div>
    </Dialog>
  )
})

EditCustomerInvoiceCustomSectionsDialog.displayName = 'EditCustomerInvoiceCustomSectionsDialog'
