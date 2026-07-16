import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { number, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { ComboBoxField, TextInputField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { NetPaymentTermValuesEnum } from '~/core/constants/paymentTerm'
import {
  EditBillingEntityNetPaymentTermForDialogFragment,
  EditCustomerNetPaymentTermForDialogFragment,
  useUpdateBillingEntityNetPaymentTermMutation,
  useUpdateCustomerNetPaymentTermMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment EditCustomerNetPaymentTermForDialog on Customer {
    id
    externalId
    name
    netPaymentTerm
  }

  fragment EditBillingEntityNetPaymentTermForDialog on BillingEntity {
    id
    netPaymentTerm
  }

  mutation updateCustomerNetPaymentTerm($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      ...EditCustomerNetPaymentTermForDialog
    }
  }

  mutation updateBillingEntityNetPaymentTerm($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      ...EditBillingEntityNetPaymentTermForDialog
    }
  }
`

enum NetPaymentTermModelTypesEnum {
  Customer = 'Customer',
  BillingEntity = 'BillingEntity',
}

export interface EditNetPaymentTermDialogRef {
  openDialog: (
    model:
      | EditCustomerNetPaymentTermForDialogFragment
      | EditBillingEntityNetPaymentTermForDialogFragment
      | null
      | undefined,
  ) => unknown
  closeDialog: () => unknown
}

interface EditNetPaymentTermDialogProps {
  description: string
}

export const EditNetPaymentTermDialog = forwardRef<
  EditNetPaymentTermDialogRef,
  EditNetPaymentTermDialogProps
>(({ description }: EditNetPaymentTermDialogProps, ref) => {
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)
  const [model, setLocalModel] = useState<
    EditCustomerNetPaymentTermForDialogFragment | EditBillingEntityNetPaymentTermForDialogFragment
  >()
  const [isEdit, setIsEdit] = useState<boolean>(false)
  const [updateBillingEntity] = useUpdateBillingEntityNetPaymentTermMutation({
    onCompleted(res) {
      if (res?.updateBillingEntity) {
        addToast({
          severity: 'success',
          translateKey: isEdit ? 'text_64c7a89b6c67eb6c98898181' : 'text_64c7a89b6c67eb6c98898350',
        })
      }
    },
    refetchQueries: ['getBillingEntitySettings'],
  })
  const [updateCustomer] = useUpdateCustomerNetPaymentTermMutation({
    onCompleted(res) {
      if (res?.updateCustomer) {
        addToast({
          severity: 'success',
          translateKey: isEdit ? 'text_64c7a89b6c67eb6c98898181' : 'text_64c7a89b6c67eb6c98898350',
        })
      }
    },
  })

  const getNetPaymentTermInitialValue = () => {
    if (typeof model?.netPaymentTerm !== 'number') {
      return null
    }
    const isCustomValue = !Object.values(NetPaymentTermValuesEnum).includes(
      String(model?.netPaymentTerm) as unknown as NetPaymentTermValuesEnum,
    )

    return isCustomValue ? NetPaymentTermValuesEnum.custom : String(model?.netPaymentTerm)
  }

  const formikProps = useFormik<{
    netPaymentTerm: string | null
    customPeriod: number | null
  }>({
    initialValues: {
      netPaymentTerm: getNetPaymentTermInitialValue(),
      customPeriod:
        typeof model?.netPaymentTerm === 'number' &&
        !Object.values(NetPaymentTermValuesEnum).includes(
          String(model?.netPaymentTerm) as unknown as NetPaymentTermValuesEnum,
        )
          ? model?.netPaymentTerm
          : null,
    },
    validationSchema: object().shape({
      netPaymentTerm: string().required(''),
      customPeriod: number()
        .when('netPaymentTerm', {
          is: (netPaymentTerm: string) => netPaymentTerm === NetPaymentTermValuesEnum.custom,
          then: (schema) => schema.required(''),
        })
        .nullable(),
    }),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: async (values) => {
      if (!model) return

      const localInput = {
        netPaymentTerm:
          values.netPaymentTerm === NetPaymentTermValuesEnum.custom
            ? Number(values.customPeriod)
            : Number(values.netPaymentTerm),
      }

      if (model.__typename === NetPaymentTermModelTypesEnum.Customer) {
        await updateCustomer({
          variables: {
            input: {
              id: model.id,
              externalId: model.externalId,
              name: model.name || '',
              ...localInput,
            },
          },
        })
      } else if (model.__typename === NetPaymentTermModelTypesEnum.BillingEntity) {
        await updateBillingEntity({
          variables: {
            input: {
              ...localInput,
              id: model.id,
            },
          },
        })
      }
    },
  })

  useImperativeHandle(ref, () => ({
    openDialog: (data) => {
      !!data && setLocalModel(data)
      setIsEdit(typeof data?.netPaymentTerm === 'number')
      dialogRef.current?.openDialog()
    },
    closeDialog: () => {
      dialogRef.current?.closeDialog()
    },
  }))

  return (
    <Dialog
      ref={dialogRef}
      title={translate(isEdit ? 'text_64c7a89b6c67eb6c988981e0' : 'text_64c7a89b6c67eb6c9889822d')}
      description={description}
      onClose={() => {
        formikProps.resetForm()
        formikProps.validateForm()
        setIsEdit(false)
        setLocalModel(undefined)
      }}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_62bb10ad2a10bd182d002031')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={async () => {
              await formikProps.submitForm()
              closeDialog()
            }}
          >
            {translate('text_17432414198706rdwf76ek3u')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 flex flex-col gap-3">
        <ComboBoxField
          name="netPaymentTerm"
          label={translate('text_64c7a89b6c67eb6c98898109')}
          placeholder={translate('text_64c7b3014f5c4639c4a51ab0')}
          formikProps={formikProps}
          sortValues={false}
          data={[
            {
              value: NetPaymentTermValuesEnum.zero,
              label: translate('text_64c7a89b6c67eb6c98898125'),
            },
            {
              value: NetPaymentTermValuesEnum.thirty,
              label: translate(
                'text_64c7a89b6c67eb6c9889815f',
                {
                  days: 30,
                },
                30,
              ),
            },
            {
              value: NetPaymentTermValuesEnum.sixty,
              label: translate(
                'text_64c7a89b6c67eb6c9889815f',
                {
                  days: 60,
                },
                60,
              ),
            },
            {
              value: NetPaymentTermValuesEnum.ninety,
              label: translate(
                'text_64c7a89b6c67eb6c9889815f',
                {
                  days: 90,
                },
                90,
              ),
            },
            {
              value: NetPaymentTermValuesEnum.custom,
              label: translate('text_64c7a89b6c67eb6c988981ae'),
            },
          ]}
          PopperProps={{ displayInDialog: true }}
        />

        {formikProps.values.netPaymentTerm === NetPaymentTermValuesEnum.custom && (
          <TextInputField
            name="customPeriod"
            label={translate('text_64c7a89b6c67eb6c988981ae')}
            placeholder={translate('text_62ff5d01a306e274d4ffcc3c')}
            beforeChangeFormatter={['positiveNumber', 'int']}
            formikProps={formikProps}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  {translate('text_638dc196fb209d551f3d814d')}
                </InputAdornment>
              ),
            }}
          />
        )}
      </div>
    </Dialog>
  )
})

EditNetPaymentTermDialog.displayName = 'forwardRef'
