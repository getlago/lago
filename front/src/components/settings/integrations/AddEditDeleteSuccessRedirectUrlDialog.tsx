import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useMemo, useRef, useState } from 'react'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { TextInputField } from '~/components/form'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { ADYEN_SUCCESS_LINK_SPEC_URL } from '~/core/constants/externalUrls'
import {
  AdyenForCreateAndEditSuccessRedirectUrlFragment,
  CashfreeForCreateAndEditSuccessRedirectUrlFragment,
  FlutterwaveForCreateAndEditSuccessRedirectUrlFragment,
  GocardlessForCreateAndEditSuccessRedirectUrlFragment,
  MoneyhashForCreateAndEditSuccessRedirectUrlFragment,
  StripeForCreateAndEditSuccessRedirectUrlFragment,
  UpdateAdyenPaymentProviderInput,
  UpdateCashfreePaymentProviderInput,
  UpdateFlutterwavePaymentProviderInput,
  UpdateGocardlessPaymentProviderInput,
  UpdateMoneyhashPaymentProviderInput,
  UpdateStripePaymentProviderInput,
  useUpdateAdyenPaymentProviderMutation,
  useUpdateCashfreePaymentProviderMutation,
  useUpdateFlutterwavePaymentProviderSuccessRedirectUrlMutation,
  useUpdateGocardlessPaymentProviderMutation,
  useUpdateMoneyhashPaymentProviderMutation,
  useUpdateStripePaymentProviderMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment AdyenForCreateAndEditSuccessRedirectUrl on AdyenProvider {
    id
    successRedirectUrl
  }

  fragment CashfreeForCreateAndEditSuccessRedirectUrl on CashfreeProvider {
    id
    successRedirectUrl
  }

  fragment FlutterwaveForCreateAndEditSuccessRedirectUrl on FlutterwaveProvider {
    id
    successRedirectUrl
  }

  fragment gocardlessForCreateAndEditSuccessRedirectUrl on GocardlessProvider {
    id
    successRedirectUrl
  }

  fragment StripeForCreateAndEditSuccessRedirectUrl on StripeProvider {
    id
    successRedirectUrl
  }

  fragment MoneyhashForCreateAndEditSuccessRedirectUrl on MoneyhashProvider {
    id
    flowId
    successRedirectUrl
  }

  mutation updateAdyenPaymentProvider($input: UpdateAdyenPaymentProviderInput!) {
    updateAdyenPaymentProvider(input: $input) {
      id
      successRedirectUrl
    }
  }

  mutation updateCashfreePaymentProvider($input: UpdateCashfreePaymentProviderInput!) {
    updateCashfreePaymentProvider(input: $input) {
      id
      successRedirectUrl
    }
  }

  mutation updateFlutterwavePaymentProviderSuccessRedirectUrl(
    $input: UpdateFlutterwavePaymentProviderInput!
  ) {
    updateFlutterwavePaymentProvider(input: $input) {
      id
      successRedirectUrl
    }
  }

  mutation updateGocardlessPaymentProvider($input: UpdateGocardlessPaymentProviderInput!) {
    updateGocardlessPaymentProvider(input: $input) {
      id
      successRedirectUrl
    }
  }

  mutation updateStripePaymentProvider($input: UpdateStripePaymentProviderInput!) {
    updateStripePaymentProvider(input: $input) {
      id
      successRedirectUrl
    }
  }

  mutation updateMoneyhashPaymentProvider($input: UpdateMoneyhashPaymentProviderInput!) {
    updateMoneyhashPaymentProvider(input: $input) {
      id
      flowId
    }
  }
`

const AddEditDeleteSuccessRedirectUrlDialogMode = {
  Add: 'Add',
  Edit: 'Edit',
  Delete: 'Delete',
} as const

const AddEditDeleteSuccessRedirectUrlDialogProviderType = {
  Adyen: 'Adyen',
  Stripe: 'Stripe',
  GoCardless: 'GoCardless',
  Cashfree: 'Cashfree',
  Flutterwave: 'Flutterwave',
  Moneyhash: 'Moneyhash',
} as const

type LocalProviderType = {
  mode: keyof typeof AddEditDeleteSuccessRedirectUrlDialogMode
  type: keyof typeof AddEditDeleteSuccessRedirectUrlDialogProviderType
  provider?:
    | AdyenForCreateAndEditSuccessRedirectUrlFragment
    | CashfreeForCreateAndEditSuccessRedirectUrlFragment
    | FlutterwaveForCreateAndEditSuccessRedirectUrlFragment
    | GocardlessForCreateAndEditSuccessRedirectUrlFragment
    | StripeForCreateAndEditSuccessRedirectUrlFragment
    | MoneyhashForCreateAndEditSuccessRedirectUrlFragment
    | null
}

export interface AddEditDeleteSuccessRedirectUrlDialogRef {
  openDialog: (incommingData?: LocalProviderType) => unknown
  closeDialog: () => unknown
}

export const AddEditDeleteSuccessRedirectUrlDialog =
  forwardRef<AddEditDeleteSuccessRedirectUrlDialogRef>((_, ref) => {
    const { translate } = useInternationalization()
    const dialogRef = useRef<DialogRef>(null)
    const [localData, setLocalData] = useState<LocalProviderType | undefined>(undefined)

    const getSuccessToastMessage = () => {
      if (localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Delete) {
        return 'text_65367cb78324b77fcb6af2c1'
      }
      if (localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Add) {
        return 'text_65367cb78324b77fcb6af261'
      }
      return 'text_65367cb78324b77fcb6af28f'
    }

    const getButtonText = () => {
      if (localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Delete) {
        return 'text_65367cb78324b77fcb6af255'
      }
      if (localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Edit) {
        return 'text_65367cb78324b77fcb6af249'
      }
      return 'text_65367cb78324b77fcb6af1ec'
    }

    const successToastMessage = translate(getSuccessToastMessage())
    const [updateAdyenProvider] = useUpdateAdyenPaymentProviderMutation({
      onCompleted(data) {
        if (data && data.updateAdyenPaymentProvider) {
          addToast({
            message: successToastMessage,
            severity: 'success',
          })
        }
      },
    })

    const [updateCashfreeProvider] = useUpdateCashfreePaymentProviderMutation({
      onCompleted(data) {
        if (data && data.updateCashfreePaymentProvider) {
          addToast({
            message: successToastMessage,
            severity: 'success',
          })
        }
      },
    })

    const [updateFlutterwaveProvider] =
      useUpdateFlutterwavePaymentProviderSuccessRedirectUrlMutation({
        onCompleted(data) {
          if (data && data.updateFlutterwavePaymentProvider) {
            addToast({
              message: successToastMessage,
              severity: 'success',
            })
          }
        },
      })

    const [updateGocardlessProvider] = useUpdateGocardlessPaymentProviderMutation({
      onCompleted(data) {
        if (data && data.updateGocardlessPaymentProvider) {
          addToast({
            message: successToastMessage,
            severity: 'success',
          })
        }
      },
    })

    const [updateStripeProvider] = useUpdateStripePaymentProviderMutation({
      onCompleted(data) {
        if (data && data.updateStripePaymentProvider) {
          addToast({
            message: successToastMessage,
            severity: 'success',
          })
        }
      },
    })

    const [updateMoneyhashProvider] = useUpdateMoneyhashPaymentProviderMutation({
      onCompleted(data) {
        if (data && data.updateMoneyhashPaymentProvider) {
          addToast({
            message: successToastMessage,
            severity: 'success',
          })
        }
      },
    })

    const formikProps = useFormik<
      | UpdateAdyenPaymentProviderInput
      | UpdateCashfreePaymentProviderInput
      | UpdateFlutterwavePaymentProviderInput
      | UpdateGocardlessPaymentProviderInput
      | UpdateStripePaymentProviderInput
      | UpdateMoneyhashPaymentProviderInput
    >({
      initialValues: {
        id: localData?.provider?.id || '',
        successRedirectUrl: localData?.provider?.successRedirectUrl || '',
      },
      validateOnMount: true,
      enableReinitialize: true,
      validationSchema: object().shape({
        successRedirectUrl: string().required(''),
      }),
      onSubmit: async ({ ...values }, formikBag) => {
        const methodLoojup = {
          [AddEditDeleteSuccessRedirectUrlDialogProviderType.Adyen]: updateAdyenProvider,
          [AddEditDeleteSuccessRedirectUrlDialogProviderType.Stripe]: updateStripeProvider,
          [AddEditDeleteSuccessRedirectUrlDialogProviderType.GoCardless]: updateGocardlessProvider,
          [AddEditDeleteSuccessRedirectUrlDialogProviderType.Cashfree]: updateCashfreeProvider,
          [AddEditDeleteSuccessRedirectUrlDialogProviderType.Flutterwave]:
            updateFlutterwaveProvider,
          [AddEditDeleteSuccessRedirectUrlDialogProviderType.Moneyhash]: updateMoneyhashProvider,
        }

        const method = methodLoojup[localData?.type as LocalProviderType['type']]

        const res = await method({
          variables: {
            input: {
              id: values.id,
              successRedirectUrl:
                localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Delete
                  ? null
                  : values.successRedirectUrl,
            },
          },
        })

        if (res?.errors) {
          if (hasDefinedGQLError('UrlIsInvalid', res.errors)) {
            formikBag.setFieldError('successRedirectUrl', 'true')
          }
          return
        }

        dialogRef.current?.closeDialog()
      },
    })

    const helperText: string = useMemo(() => {
      if (!!formikProps.errors.successRedirectUrl) {
        if (localData?.type === AddEditDeleteSuccessRedirectUrlDialogProviderType.Adyen) {
          return translate('text_65367cb78324b77fcb6af2eb', {
            href: ADYEN_SUCCESS_LINK_SPEC_URL,
          })
        }
        return translate('text_6538d6f6c43ecb00706e6ab6')
      }

      if (localData?.type === AddEditDeleteSuccessRedirectUrlDialogProviderType.Adyen) {
        return translate('text_65367cb78324b77fcb6af2e9', {
          href: ADYEN_SUCCESS_LINK_SPEC_URL,
        })
      }
      return translate('text_6538d6c00f753e0085cbd4ba')
    }, [formikProps.errors.successRedirectUrl, localData?.type, translate])

    useImperativeHandle(ref, () => ({
      openDialog: (data) => {
        formikProps.resetForm()
        setLocalData(data)
        dialogRef.current?.openDialog()
      },
      closeDialog: () => dialogRef.current?.closeDialog(),
    }))

    const getDialogTitle = () => {
      if (localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Delete) {
        return 'text_65367cb78324b77fcb6af200'
      }
      if (localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Edit) {
        return 'text_65367cb78324b77fcb6af216'
      }
      return 'text_65367cb78324b77fcb6af1b4'
    }

    return (
      <Dialog
        ref={dialogRef}
        title={translate(getDialogTitle())}
        description={translate(
          localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Delete
            ? 'text_65367cb78324b77fcb6af218'
            : 'text_65367cb78324b77fcb6af224',
          {
            connectionName: localData?.type,
          },
        )}
        onClose={() => {
          setLocalData(undefined)
          formikProps.resetForm()
        }}
        actions={({ closeDialog }) => (
          <>
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_6271200984178801ba8bdf4a')}
            </Button>
            <Button
              variant="primary"
              danger={localData?.mode === AddEditDeleteSuccessRedirectUrlDialogMode.Delete}
              disabled={
                localData?.mode !== AddEditDeleteSuccessRedirectUrlDialogMode.Delete &&
                (!formikProps.isValid || !formikProps.dirty)
              }
              onClick={async () => {
                await formikProps.submitForm()
              }}
            >
              {translate(getButtonText())}
            </Button>
          </>
        )}
      >
        {localData?.mode !== AddEditDeleteSuccessRedirectUrlDialogMode.Delete && (
          <TextInputField
            // eslint-disable-next-line jsx-a11y/no-autofocus
            autoFocus
            className="mb-8"
            error={!!formikProps.errors.successRedirectUrl}
            name="successRedirectUrl"
            label={translate('text_65367cb78324b77fcb6af1c6')}
            placeholder={translate('text_65367cb78324b77fcb6af1d0')}
            helperText={
              <Typography
                variant="caption"
                color={!!formikProps.errors.successRedirectUrl ? 'danger600' : 'grey600'}
                html={helperText}
              />
            }
            formikProps={formikProps}
          />
        )}
      </Dialog>
    )
  })

AddEditDeleteSuccessRedirectUrlDialog.displayName = 'forwardRef'
