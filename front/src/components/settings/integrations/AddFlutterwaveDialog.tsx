import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { generatePath } from 'react-router-dom'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { TextInputField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { FLUTTERWAVE_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  AddFlutterwavePaymentProviderInput,
  FlutterwaveIntegrationDetailsFragment,
  LagoApiError,
  useAddFlutterwavePaymentProviderMutation,
  useGetProviderByCodeForFlutterwaveLazyQuery,
  useUpdateFlutterwavePaymentProviderMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment AddFlutterwaveProviderDialog on FlutterwaveProvider {
    id
    name
    code
    secretKey
    webhookSecret
    successRedirectUrl
  }

  query getProviderByCodeForFlutterwave($code: String) {
    paymentProvider(code: $code) {
      ... on FlutterwaveProvider {
        id
      }
      ... on CashfreeProvider {
        id
      }
      ... on GocardlessProvider {
        id
      }
      ... on AdyenProvider {
        id
      }
      ... on StripeProvider {
        id
      }
      ... on MoneyhashProvider {
        id
      }
    }
  }

  mutation addFlutterwavePaymentProvider($input: AddFlutterwavePaymentProviderInput!) {
    addFlutterwavePaymentProvider(input: $input) {
      id
      ...AddFlutterwaveProviderDialog
    }
  }

  mutation updateFlutterwavePaymentProvider($input: UpdateFlutterwavePaymentProviderInput!) {
    updateFlutterwavePaymentProvider(input: $input) {
      id
      ...AddFlutterwaveProviderDialog
    }
  }
`

type TAddFlutterwaveDialogProps = Partial<{
  onDelete: (provider: FlutterwaveIntegrationDetailsFragment) => void
  provider: FlutterwaveIntegrationDetailsFragment
}>

export interface AddFlutterwaveDialogRef {
  openDialog: (props?: TAddFlutterwaveDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddFlutterwaveDialog = forwardRef<AddFlutterwaveDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<TAddFlutterwaveDialogProps | undefined>(undefined)
  const flutterwaveProvider = localData?.provider
  const isEdition = !!flutterwaveProvider
  const [addFlutterwaveProvider] = useAddFlutterwavePaymentProviderMutation({
    onCompleted(data) {
      if (data?.addFlutterwavePaymentProvider) {
        addToast({
          severity: 'success',
          translateKey: 'text_1749803444837pl1ketrhm8a',
        })
        navigate(
          generatePath(FLUTTERWAVE_INTEGRATION_DETAILS_ROUTE, {
            integrationId: data.addFlutterwavePaymentProvider.id,
            integrationGroup: IntegrationsTabsOptionsEnum.Community,
          }),
        )
      }
    },
  })
  const [updateFlutterwaveProvider] = useUpdateFlutterwavePaymentProviderMutation({
    onCompleted(data) {
      if (data?.updateFlutterwavePaymentProvider) {
        addToast({
          severity: 'success',
          translateKey: 'text_174980344483769h5q79g4ap',
        })
      }
    },
    onError() {
      // Handle update errors - typically just display generic error since sensitive fields are not updated
      addToast({
        severity: 'danger',
        translateKey: 'text_629728388c4d2300e2d380d5',
      })
    },
  })
  const [getProviderByCode] = useGetProviderByCodeForFlutterwaveLazyQuery()

  const formikProps = useFormik<AddFlutterwavePaymentProviderInput>({
    initialValues: {
      name: flutterwaveProvider?.name || '',
      code: flutterwaveProvider?.code || '',
      secretKey: flutterwaveProvider?.secretKey || '',
      successRedirectUrl: flutterwaveProvider?.successRedirectUrl || '',
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      secretKey: string().required(''),
      successRedirectUrl: string().url(''),
    }),
    onSubmit: async (values, formikBag) => {
      const { name, code, secretKey, successRedirectUrl } = values

      // Check if code already exists
      const res = await getProviderByCode({
        context: { silentErrorCodes: [LagoApiError.NotFound] },
        variables: {
          code,
        },
      })
      const isNotAllowedToMutate =
        (!!res.data?.paymentProvider?.id && !isEdition) ||
        (isEdition &&
          !!res.data?.paymentProvider?.id &&
          res.data?.paymentProvider?.id !== flutterwaveProvider?.id)

      if (isNotAllowedToMutate) {
        formikBag.setFieldError('code', translate('text_632a2d437e341dcc76817556'))
        return
      }

      if (isEdition) {
        await updateFlutterwaveProvider({
          variables: {
            input: {
              id: flutterwaveProvider?.id || '',
              name,
              code,
              successRedirectUrl: successRedirectUrl || undefined,
            },
          },
        })
      } else {
        await addFlutterwaveProvider({
          variables: {
            input: {
              name,
              code,
              secretKey,
              successRedirectUrl: successRedirectUrl || undefined,
            },
          },
        })
      }

      dialogRef.current?.closeDialog()
    },
    validateOnMount: true,
    enableReinitialize: true,
  })

  useImperativeHandle(ref, () => ({
    openDialog: (data) => {
      setLocalData(data)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  return (
    <Dialog
      ref={dialogRef}
      title={translate(
        isEdition ? 'text_1749725331374i3p14ewcpn5' : 'text_1749725331374clf07sez01f',
      )}
      description={translate('text_174972533137460li1pvmw34')}
      onClose={formikProps.resetForm}
      actions={({ closeDialog }) => (
        <div className="flex w-full items-center gap-3">
          {isEdition && (
            <Button
              danger
              variant="quaternary"
              onClick={() => {
                closeDialog()
                if (flutterwaveProvider) {
                  localData?.onDelete?.(flutterwaveProvider)
                }
              }}
            >
              {translate('text_65845f35d7d69c3ab4793dad')}
            </Button>
          )}
          <div className="ml-auto flex items-center gap-3">
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_63eba8c65a6c8043feee2a14')}
            </Button>
            <Button
              variant="primary"
              disabled={!formikProps.isValid || !formikProps.dirty}
              onClick={formikProps.submitForm}
            >
              {translate(
                isEdition ? 'text_65845f35d7d69c3ab4793dac' : 'text_1749725331374clf07sez01f',
              )}
            </Button>
          </div>
        </div>
      )}
    >
      <div className="mb-8 flex flex-col gap-6">
        <div className="flex items-start gap-6">
          <TextInputField
            className="flex-1"
            // eslint-disable-next-line jsx-a11y/no-autofocus
            autoFocus
            formikProps={formikProps}
            name="name"
            label={translate('text_6584550dc4cec7adf861504d')}
            placeholder={translate('text_6584550dc4cec7adf861504f')}
          />
          <TextInputField
            className="flex-1"
            formikProps={formikProps}
            name="code"
            label={translate('text_6584550dc4cec7adf8615051')}
            placeholder={translate('text_6584550dc4cec7adf8615053')}
          />
        </div>
        <TextInputField
          name="secretKey"
          disabled={isEdition}
          label={translate('text_17497252876688ai900wowoc')}
          placeholder={translate('text_1749725331374uzvwfxs7m82')}
          formikProps={formikProps}
        />
        <TextInputField
          formikProps={formikProps}
          name="successRedirectUrl"
          label={translate('text_65367cb78324b77fcb6af21c')}
          placeholder={translate('text_1733303818769298k0fvsgcz')}
        />
      </div>
    </Dialog>
  )
})

AddFlutterwaveDialog.displayName = 'AddFlutterwaveDialog'
