import { FetchResult, gql } from '@apollo/client'
import { captureException } from '@sentry/react'
import { useFormik } from 'formik'
import { forwardRef, useId, useImperativeHandle, useRef, useState } from 'react'
import { generatePath } from 'react-router-dom'
import { object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { TextInputField } from '~/components/form'
import { addToast, envGlobalVar, hasDefinedGQLError } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { AVALARA_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  AddAvalaraIntegrationDialogFragment,
  AvalaraIntegrationDetailsFragmentDoc,
  CreateAvalaraIntegrationInput,
  CreateAvalaraIntegrationMutation,
  LagoApiError,
  UpdateAvalaraIntegrationMutation,
  useCreateAvalaraIntegrationMutation,
  useUpdateAvalaraIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { AvalaraIntegrationDetailsTabs } from '~/pages/settings/AvalaraIntegrationDetails'
import { tw } from '~/styles/utils'

import { useDeleteAvalaraIntegrationDialog } from './DeleteAvalaraIntegrationDialog'

gql`
  fragment AddAvalaraIntegrationDialog on AvalaraIntegration {
    id
    accountId
    code
    companyCode
    licenseKey
    name
  }

  mutation createAvalaraIntegration($input: CreateAvalaraIntegrationInput!) {
    createAvalaraIntegration(input: $input) {
      ...AddAvalaraIntegrationDialog
      ...AvalaraIntegrationDetails
    }
  }

  mutation updateAvalaraIntegration($input: UpdateAvalaraIntegrationInput!) {
    updateAvalaraIntegration(input: $input) {
      id
      ...AddAvalaraIntegrationDialog
      ...AvalaraIntegrationDetails
    }
  }

  ${AvalaraIntegrationDetailsFragmentDoc}
`

type AddAvalaraDialogProps = {
  integration: AddAvalaraIntegrationDialogFragment
  deleteDialogCallback?: () => void
}

export interface AddAvalaraDialogRef {
  openDialog: (props?: AddAvalaraDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddAvalaraDialog = forwardRef<AddAvalaraDialogRef>((_, ref) => {
  const componentId = useId()
  const navigate = useNavigate()
  const { nangoPublicKey } = envGlobalVar()
  const dialogRef = useRef<DialogRef>(null)
  const { translate } = useInternationalization()
  const [localData, setLocalData] = useState<AddAvalaraDialogProps | undefined>(undefined)
  const [showGlobalError, setShowGlobalError] = useState(false)
  const avalaraIntegration = localData?.integration
  const isEdition = !!avalaraIntegration
  const { openDeleteAvalaraIntegrationDialog } = useDeleteAvalaraIntegrationDialog()

  const [addAvalara] = useCreateAvalaraIntegrationMutation({
    onCompleted({ createAvalaraIntegration }) {
      if (createAvalaraIntegration?.id) {
        navigate(
          generatePath(AVALARA_INTEGRATION_DETAILS_ROUTE, {
            integrationId: createAvalaraIntegration.id,
            tab: AvalaraIntegrationDetailsTabs.Settings,
            integrationGroup: IntegrationsTabsOptionsEnum.Lago,
          }),
        )

        addToast({
          message: translate('text_1744293680332cq4cd1dpiu6'),
          severity: 'success',
        })
      }
    },
  })

  const [updateAvalara] = useUpdateAvalaraIntegrationMutation({
    onCompleted({ updateAvalaraIntegration }) {
      if (updateAvalaraIntegration?.id) {
        addToast({
          message: translate('text_1744293680332firnbl6qch5'),
          severity: 'success',
        })

        dialogRef.current?.closeDialog()
      }
    },
  })

  const formikProps = useFormik<Omit<CreateAvalaraIntegrationInput, 'connectionId'>>({
    enableReinitialize: true,
    validateOnMount: true,
    initialValues: {
      accountId: avalaraIntegration?.accountId || '',
      code: avalaraIntegration?.code || '',
      companyCode: avalaraIntegration?.companyCode || '',
      licenseKey: avalaraIntegration?.licenseKey || '',
      name: avalaraIntegration?.name || '',
    },
    validationSchema: object().shape({
      accountId: string().required(''),
      code: string().required(''),
      companyCode: string().required(''),
      licenseKey: string().required(''),
      name: string().required(''),
    }),
    onSubmit: async ({ ...values }, formikBag) => {
      setShowGlobalError(false)
      let res

      if (isEdition) {
        res = await updateAvalara({
          variables: {
            input: {
              id: avalaraIntegration?.id || '',
              ...values,
            },
          },
          context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
        })
      } else {
        const { default: Nango, AuthError } = await import('@nangohq/frontend')
        const connectionId = `avalara-${componentId.replaceAll(':', '')}-${Date.now()}`
        const nango = new Nango({ publicKey: nangoPublicKey })

        try {
          const nangoApiKeyConnection = await nango.auth('avalara-sandbox', connectionId, {
            params: { avalaraClient: 'asd' },
            credentials: {
              username: values.accountId,
              password: values.licenseKey,
            },
          })

          res = await addAvalara({
            variables: {
              input: {
                ...values,
                connectionId: nangoApiKeyConnection?.connectionId || '',
              },
            },
          })
        } catch (error) {
          if (error instanceof AuthError) return setShowGlobalError(true)

          captureException(error, {
            tags: {
              integration: 'avalara',
              action: isEdition ? 'update' : 'create',
            },
            extra: {
              accountId: values.accountId,
            },
          })
        }
      }

      const { errors } = res as
        | FetchResult<UpdateAvalaraIntegrationMutation>
        | FetchResult<CreateAvalaraIntegrationMutation>

      if (!errors) dialogRef.current?.closeDialog()

      if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
        formikBag.setErrors({
          code: translate('text_632a2d437e341dcc76817556'),
        })
      }
    },
  })

  useImperativeHandle(ref, () => ({
    openDialog: (data) => {
      setShowGlobalError(false)
      setLocalData(data)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  return (
    <Dialog
      ref={dialogRef}
      title={translate(
        isEdition ? 'text_658461066530343fe1808cd9' : 'text_174429360927877m0kmo6gmm',
        {
          name: avalaraIntegration?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_17442936803327ymv9v7ecv0' : 'text_174429360927806xa8sxsreg',
      )}
      onClose={formikProps.resetForm}
      actions={({ closeDialog }) => (
        <div
          className={tw('flex flex-row items-center justify-between gap-3', isEdition && 'w-full')}
        >
          {isEdition && (
            <Button
              danger
              variant="quaternary"
              onClick={() => {
                closeDialog()
                openDeleteAvalaraIntegrationDialog({
                  provider: avalaraIntegration,
                  callback: localData?.deleteDialogCallback,
                })
              }}
            >
              {translate('text_65845f35d7d69c3ab4793dad')}
            </Button>
          )}
          <div className="flex items-center gap-3">
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_62b1edddbf5f461ab971276d')}
            </Button>
            <Button
              variant="primary"
              disabled={!formikProps.isValid || !formikProps.dirty}
              onClick={formikProps.submitForm}
            >
              {translate(
                isEdition ? 'text_664c732c264d7eed1c74fdaa' : 'text_174429360927877m0kmo6gmm',
              )}
            </Button>
          </div>
        </div>
      )}
    >
      <div className="mb-8 flex flex-col gap-6">
        {!!showGlobalError && (
          <Alert type="danger">{translate('text_1749562792335fy21gc3sxn0')}</Alert>
        )}

        <div className="flex flex-row items-start gap-6">
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
          name="accountId"
          disabled={isEdition}
          label={translate('text_1744293609278tzbixvdszc6')}
          placeholder={translate('text_1744293635186p3wseb9b7hl')}
          formikProps={formikProps}
        />

        <TextInputField
          name="licenseKey"
          disabled={isEdition}
          label={translate('text_1744293635187073v2g6xw0o')}
          placeholder={translate('text_1744293635187idjlrbzbv21')}
          formikProps={formikProps}
        />

        <TextInputField
          name="companyCode"
          disabled={isEdition}
          label={translate('text_1744293635187hxvz11n5bq3')}
          placeholder={translate('text_1744293635187q00705sjtf8')}
          formikProps={formikProps}
        />
      </div>
    </Dialog>
  )
})

AddAvalaraDialog.displayName = 'AddAvalaraDialog'
