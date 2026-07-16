import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { generatePath } from 'react-router-dom'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { TextInputField } from '~/components/form'
import { addToast, envGlobalVar } from '~/core/apolloClient'
import { buildGocardlessAuthUrl } from '~/core/constants/externalUrls'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { GOCARDLESS_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  AddGocardlessPaymentProviderInput,
  AddGocardlessProviderDialogFragment,
  GocardlessIntegrationDetailsFragmentDoc,
  LagoApiError,
  useGetProviderByCodeForGocardlessLazyQuery,
  useUpdateGocardlessApiKeyMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useDeleteGocardlessIntegrationDialog } from './DeleteGocardlessIntegrationDialog'

gql`
  fragment AddGocardlessProviderDialog on GocardlessProvider {
    id
    name
    code
  }

  query getProviderByCodeForGocardless($code: String) {
    paymentProvider(code: $code) {
      ... on GocardlessProvider {
        id
      }
      ... on CashfreeProvider {
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

  mutation updateGocardlessApiKey($input: UpdateGocardlessPaymentProviderInput!) {
    updateGocardlessPaymentProvider(input: $input) {
      id
      ...AddGocardlessProviderDialog
      ...GocardlessIntegrationDetails
    }
  }

  ${GocardlessIntegrationDetailsFragmentDoc}
`

type TAddGocardlessDialogProps = Partial<{
  provider: AddGocardlessProviderDialogFragment
  deleteDialogCallback: () => void
}>

export interface AddGocardlessDialogRef {
  openDialog: (props?: TAddGocardlessDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddGocardlessDialog = forwardRef<AddGocardlessDialogRef>((_, ref) => {
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const { lagoOauthProxyUrl } = envGlobalVar()

  const { translate } = useInternationalization()
  const [localData, setLocalData] = useState<TAddGocardlessDialogProps | undefined>(undefined)
  const gocardlessProvider = localData?.provider
  const isEdition = !!gocardlessProvider
  const { openDeleteGocardlessIntegrationDialog } = useDeleteGocardlessIntegrationDialog()

  const [updateApiKey] = useUpdateGocardlessApiKeyMutation({
    onCompleted({ updateGocardlessPaymentProvider }) {
      if (updateGocardlessPaymentProvider?.id) {
        navigate(
          generatePath(GOCARDLESS_INTEGRATION_DETAILS_ROUTE, {
            integrationId: updateGocardlessPaymentProvider.id,
            integrationGroup: IntegrationsTabsOptionsEnum.Lago,
          }),
        )

        addToast({
          message: translate(
            isEdition ? 'Edit gocardless success toast' : 'Add gocardless success toast',
          ),
          severity: 'success',
        })
      }
    },
  })

  const [getGocardlessProviderByCode] = useGetProviderByCodeForGocardlessLazyQuery()

  const formikProps = useFormik<AddGocardlessPaymentProviderInput>({
    initialValues: {
      code: gocardlessProvider?.code || '',
      name: gocardlessProvider?.name || '',
    },
    validationSchema: object().shape({
      name: string(),
      code: string().required(''),
    }),
    onSubmit: async (values, formikBag) => {
      const res = await getGocardlessProviderByCode({
        context: { silentErrorCodes: [LagoApiError.NotFound] },
        variables: {
          code: values.code,
        },
      })
      const isNotAllowedToMutate =
        (!!res.data?.paymentProvider?.id && !isEdition) ||
        (isEdition &&
          !!res.data?.paymentProvider?.id &&
          res.data?.paymentProvider?.id !== gocardlessProvider?.id)

      if (isNotAllowedToMutate) {
        formikBag.setFieldError('code', translate('text_632a2d437e341dcc76817556'))
        return
      }

      if (isEdition) {
        await updateApiKey({
          variables: {
            input: { ...values, id: gocardlessProvider?.id || '' },
          },
        })

        dialogRef.current?.closeDialog()
      } else {
        setTimeout(() => {
          const myWindow = window.open('', '_blank')

          if (myWindow?.location?.href) {
            myWindow.location.href = buildGocardlessAuthUrl(
              lagoOauthProxyUrl,
              values.name,
              values.code,
            )
            dialogRef.current?.closeDialog()
            return myWindow?.focus()
          }

          myWindow?.close()
          addToast({
            severity: 'danger',
            translateKey: 'text_62b31e1f6a5b8b1b745ece48',
          })
        }, 0)
      }
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
        isEdition ? 'text_658461066530343fe1808cd9' : 'text_658466afe6140b469140e1f9',
        {
          name: gocardlessProvider?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_658461066530343fe1808cdd' : 'text_658466afe6140b469140e1fb',
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
                openDeleteGocardlessIntegrationDialog({
                  provider: gocardlessProvider,
                  callback: localData?.deleteDialogCallback,
                })
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
                isEdition ? 'text_65845f35d7d69c3ab4793dac' : 'text_658466afe6140b469140e207',
              )}
            </Button>
          </Stack>
        </Stack>
      )}
    >
      <div className="mb-8 flex flex-row items-start gap-6">
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
    </Dialog>
  )
})

AddGocardlessDialog.displayName = 'AddGocardlessDialog'
