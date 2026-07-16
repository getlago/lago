import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { generatePath } from 'react-router-dom'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { TextInputField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { CASHFREE_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  AddCashfreePaymentProviderInput,
  AddCashfreeProviderDialogFragment,
  CashfreeIntegrationDetailsFragmentDoc,
  LagoApiError,
  useAddCashfreeApiKeyMutation,
  useGetProviderByCodeForCashfreeLazyQuery,
  useUpdateCashfreeApiKeyMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment AddCashfreeProviderDialog on CashfreeProvider {
    id
    name
    code
    clientId
    clientSecret
    successRedirectUrl
  }

  query getProviderByCodeForCashfree($code: String) {
    paymentProvider(code: $code) {
      ... on CashfreeProvider {
        id
      }
      ... on GocardlessProvider {
        id
      }
      ... on FlutterwaveProvider {
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

  mutation addCashfreeApiKey($input: AddCashfreePaymentProviderInput!) {
    addCashfreePaymentProvider(input: $input) {
      id
      ...AddCashfreeProviderDialog
      ...CashfreeIntegrationDetails
    }
  }

  mutation updateCashfreeApiKey($input: UpdateCashfreePaymentProviderInput!) {
    updateCashfreePaymentProvider(input: $input) {
      id
      ...AddCashfreeProviderDialog
      ...CashfreeIntegrationDetails
    }
  }

  ${CashfreeIntegrationDetailsFragmentDoc}
`

type TAddCashfreeDialogProps = Partial<{
  provider: AddCashfreeProviderDialogFragment
  onDeleteClick: () => void
}>

export interface AddCashfreeDialogRef {
  openDialog: (props?: TAddCashfreeDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddCashfreeDialog = forwardRef<AddCashfreeDialogRef>((_, ref) => {
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)

  const { translate } = useInternationalization()
  const [localData, setLocalData] = useState<TAddCashfreeDialogProps | undefined>(undefined)
  const cashfreeProvider = localData?.provider
  const isEdition = !!cashfreeProvider

  const [addApiKey] = useAddCashfreeApiKeyMutation({
    onCompleted({ addCashfreePaymentProvider }) {
      if (addCashfreePaymentProvider?.id) {
        navigate(
          generatePath(CASHFREE_INTEGRATION_DETAILS_ROUTE, {
            integrationId: addCashfreePaymentProvider.id,
            integrationGroup: IntegrationsTabsOptionsEnum.Community,
          }),
        )

        addToast({
          message: translate('text_17276219350329d36mgsotee'),
          severity: 'success',
        })
      }
    },
  })

  const [updateApiKey] = useUpdateCashfreeApiKeyMutation({
    onCompleted({ updateCashfreePaymentProvider }) {
      if (updateCashfreePaymentProvider?.id) {
        navigate(
          generatePath(CASHFREE_INTEGRATION_DETAILS_ROUTE, {
            integrationId: updateCashfreePaymentProvider.id,
            integrationGroup: IntegrationsTabsOptionsEnum.Community,
          }),
        )

        addToast({
          message: translate('text_1727621947600tg14usmdbb0'),
          severity: 'success',
        })
      }
    },
  })

  const [getCashfreeProviderByCode] = useGetProviderByCodeForCashfreeLazyQuery()

  const formikProps = useFormik<AddCashfreePaymentProviderInput>({
    initialValues: {
      code: cashfreeProvider?.code || '',
      name: cashfreeProvider?.name || '',
      clientId: cashfreeProvider?.clientId || '',
      clientSecret: cashfreeProvider?.clientSecret || '',
      successRedirectUrl: cashfreeProvider?.successRedirectUrl || '',
    },
    validationSchema: object().shape({
      name: string(),
      code: string().required(''),
      clientId: string().required(''),
      clientSecret: string().required(''),
      successRedirectUrl: string(),
    }),
    onSubmit: async ({ clientId, clientSecret, successRedirectUrl, ...values }, formikBag) => {
      const res = await getCashfreeProviderByCode({
        context: { silentErrorCodes: [LagoApiError.NotFound] },
        variables: {
          code: values.code,
        },
      })
      const isNotAllowedToMutate =
        (!!res.data?.paymentProvider?.id && !isEdition) ||
        (isEdition &&
          !!res.data?.paymentProvider?.id &&
          res.data?.paymentProvider?.id !== cashfreeProvider?.id)

      if (isNotAllowedToMutate) {
        formikBag.setFieldError('code', translate('text_632a2d437e341dcc76817556'))
        return
      }

      if (isEdition) {
        await updateApiKey({
          variables: {
            input: {
              id: cashfreeProvider?.id || '',
              successRedirectUrl: successRedirectUrl || undefined,
              ...values,
            },
          },
        })
      } else {
        await addApiKey({
          variables: {
            input: {
              clientId,
              clientSecret,
              successRedirectUrl: successRedirectUrl || undefined,
              ...values,
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
        isEdition ? 'text_658461066530343fe1808cd9' : 'text_172450747075633492aqpbm2',
        {
          name: cashfreeProvider?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_1724507963056bu20ky8z98g' : 'text_17245079170372xxmw737fhf',
      )}
      onClose={() => {
        formikProps.resetForm()
      }}
      actions={({ closeDialog }) => (
        <Stack
          direction="row"
          justifyContent="space-between"
          alignItems="center"
          width={isEdition ? '100%' : 'inherit'}
          spacing={3}
        >
          {isEdition && (
            <Button
              danger
              variant="quaternary"
              onClick={() => {
                closeDialog()
                localData?.onDeleteClick?.()
              }}
            >
              {translate('text_65845f35d7d69c3ab4793dad')}
            </Button>
          )}
          <Stack direction="row" spacing={3} alignItems="center">
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_62b1edddbf5f461ab971276d')}
            </Button>
            <Button
              variant="primary"
              disabled={!formikProps.isValid || !formikProps.dirty}
              onClick={formikProps.submitForm}
            >
              {translate(
                isEdition ? 'text_65845f35d7d69c3ab4793dac' : 'text_172450747075633492aqpbm2',
              )}
            </Button>
          </Stack>
        </Stack>
      )}
    >
      <div className="mb-8 flex flex-col gap-6">
        <div className="flex flex-row items-start gap-6 *:flex-1">
          <TextInputField
            // eslint-disable-next-line jsx-a11y/no-autofocus
            autoFocus
            formikProps={formikProps}
            name="name"
            label={translate('text_6584550dc4cec7adf861504d')}
            placeholder={translate('text_6584550dc4cec7adf861504f')}
          />
          <TextInputField
            formikProps={formikProps}
            name="code"
            label={translate('text_6584550dc4cec7adf8615051')}
            placeholder={translate('text_6584550dc4cec7adf8615053')}
          />
        </div>
        <TextInputField
          formikProps={formikProps}
          disabled={isEdition}
          name="clientId"
          label={translate('text_1727620558031ftsky1vpr55')}
          placeholder={translate('text_1727624537843s2ublm4rsyj')}
        />
        <TextInputField
          formikProps={formikProps}
          disabled={isEdition}
          name="clientSecret"
          label={translate('text_1727620574228qfyoqtsdih7')}
          placeholder={translate('text_17276245391922l9540z7f78')}
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

AddCashfreeDialog.displayName = 'AddCashfreeDialog'
