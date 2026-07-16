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
import { MONEYHASH_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  AddMoneyhashPaymentProviderInput,
  AddMoneyhashProviderDialogFragment,
  LagoApiError,
  MoneyhashIntegrationDetailsFragmentDoc,
  useAddMoneyhashApiKeyMutation,
  useGetProviderByCodeForMoneyhashLazyQuery,
  useUpdateMoneyhashApiKeyMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useDeleteMoneyhashIntegrationDialog } from './DeleteMoneyhashIntegrationDialog'

gql`
  fragment AddMoneyhashProviderDialog on MoneyhashProvider {
    id
    name
    code
    apiKey
    flowId
  }
  query getProviderByCodeForMoneyhash($code: String) {
    paymentProvider(code: $code) {
      ... on AdyenProvider {
        id
      }
      ... on CashfreeProvider {
        id
      }
      ... on GocardlessProvider {
        id
      }
      ... on FlutterwaveProvider {
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
  mutation addMoneyhashApiKey($input: AddMoneyhashPaymentProviderInput!) {
    addMoneyhashPaymentProvider(input: $input) {
      id
      ...AddMoneyhashProviderDialog
      ...MoneyhashIntegrationDetails
    }
  }
  mutation updateMoneyhashApiKey($input: UpdateMoneyhashPaymentProviderInput!) {
    updateMoneyhashPaymentProvider(input: $input) {
      id
      ...AddMoneyhashProviderDialog
      ...MoneyhashIntegrationDetails
    }
  }
  ${MoneyhashIntegrationDetailsFragmentDoc}
`

type TAddMoneyhashDialogProps = Partial<{
  provider: AddMoneyhashProviderDialogFragment
  deleteDialogCallback: () => void
}>

export interface AddMoneyhashDialogRef {
  openDialog: (props?: TAddMoneyhashDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddMoneyhashDialog = forwardRef<AddMoneyhashDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<TAddMoneyhashDialogProps | undefined>(undefined)
  const moneyhashProvider = localData?.provider
  const isEdition = !!moneyhashProvider
  const { openDeleteMoneyhashIntegrationDialog } = useDeleteMoneyhashIntegrationDialog()

  const [addApiKey] = useAddMoneyhashApiKeyMutation({
    onCompleted({ addMoneyhashPaymentProvider }) {
      if (addMoneyhashPaymentProvider?.id) {
        navigate(
          generatePath(MONEYHASH_INTEGRATION_DETAILS_ROUTE, {
            integrationId: addMoneyhashPaymentProvider.id,
            integrationGroup: IntegrationsTabsOptionsEnum.Community,
          }),
        )
        addToast({
          message: translate('text_1733730115018i122xlyi662'),
          severity: 'success',
        })
      }
    },
  })

  const [updateApiKey] = useUpdateMoneyhashApiKeyMutation({
    onCompleted({ updateMoneyhashPaymentProvider }) {
      if (updateMoneyhashPaymentProvider?.id) {
        addToast({
          message: translate('text_17337300102103wt4s6yz2gh'),
          severity: 'success',
        })
      }
    },
  })

  const [getMoneyhashProviderByCode] = useGetProviderByCodeForMoneyhashLazyQuery()

  const formikProps = useFormik<AddMoneyhashPaymentProviderInput>({
    initialValues: {
      name: moneyhashProvider?.name || '',
      code: moneyhashProvider?.code || '',
      apiKey: moneyhashProvider?.apiKey || '',
      flowId: moneyhashProvider?.flowId || '',
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      apiKey: string().required(''),
      flowId: string().required(''),
    }),
    onSubmit: async ({ apiKey, flowId, ...values }, formikBag) => {
      const res = await getMoneyhashProviderByCode({
        context: { silentErrorCodes: [LagoApiError.NotFound] },
        variables: {
          code: values.code,
        },
      })

      const isNotAllowedToMutate =
        (!!res.data?.paymentProvider?.id && !isEdition) ||
        (isEdition &&
          !!res.data?.paymentProvider?.id &&
          res.data?.paymentProvider?.id !== moneyhashProvider?.id)

      if (isNotAllowedToMutate) {
        formikBag.setFieldError('code', translate('text_632a2d437e341dcc76817556'))
        return
      }

      if (isEdition) {
        await updateApiKey({
          variables: {
            input: {
              ...values,
              id: moneyhashProvider?.id,
              flowId,
            },
          },
        })
      } else {
        await addApiKey({
          variables: {
            input: {
              ...values,
              apiKey,
              flowId,
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
        isEdition ? 'text_658461066530343fe1808cd9' : 'text_1733489819311q0nzqi3u7wz',
        {
          name: moneyhashProvider?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_17337299668343fncntgiyhf' : 'text_1733491430992msh3b2v8nlx',
      )}
      onClose={formikProps.resetForm}
      actions={({ closeDialog }) => (
        <div className="flex w-full items-center gap-3">
          {isEdition && (
            <Button
              danger
              variant="quaternary"
              onClick={() => {
                closeDialog()
                openDeleteMoneyhashIntegrationDialog({
                  provider: moneyhashProvider,
                  callback: localData?.deleteDialogCallback,
                })
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
                isEdition ? 'text_1733729938415dtehv31k9in' : 'text_1733489819311q0nzqi3u7wz',
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
          name="apiKey"
          disabled={isEdition}
          label={translate('text_645d071272418a14c1c76a77')}
          placeholder={translate('text_645d071272418a14c1c76a83')}
          formikProps={formikProps}
        />
        <TextInputField
          name="flowId"
          label={translate('text_1737453888927uw38sepj7xy')}
          placeholder={translate('text_1737453902655bnm8uycr7o7')}
          formikProps={formikProps}
        />
      </div>
    </Dialog>
  )
})

AddMoneyhashDialog.displayName = 'AddMoneyhashDialog'
