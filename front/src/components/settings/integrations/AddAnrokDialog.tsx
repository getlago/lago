import { FetchResult, gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { useFormik } from 'formik'
import { forwardRef, useId, useImperativeHandle, useRef, useState } from 'react'
import { generatePath } from 'react-router-dom'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { TextInputField } from '~/components/form'
import { addToast, envGlobalVar, hasDefinedGQLError } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { ANROK_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  AddAnrokIntegrationDialogFragment,
  AnrokIntegrationDetailsFragmentDoc,
  CreateAnrokIntegrationInput,
  CreateAnrokIntegrationMutation,
  LagoApiError,
  UpdateAnrokIntegrationMutation,
  useCreateAnrokIntegrationMutation,
  useUpdateAnrokIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { AnrokIntegrationDetailsTabs } from '~/pages/settings/AnrokIntegrationDetails'

gql`
  fragment AddAnrokIntegrationDialog on AnrokIntegration {
    id
    name
    code
    apiKey
  }

  mutation createAnrokIntegration($input: CreateAnrokIntegrationInput!) {
    createAnrokIntegration(input: $input) {
      id
      ...AddAnrokIntegrationDialog
      ...AnrokIntegrationDetails
    }
  }

  mutation updateAnrokIntegration($input: UpdateAnrokIntegrationInput!) {
    updateAnrokIntegration(input: $input) {
      id
      ...AddAnrokIntegrationDialog
      ...AnrokIntegrationDetails
    }
  }

  ${AnrokIntegrationDetailsFragmentDoc}
`

type TAddAnrokDialogProps = Partial<{
  onDelete: (provider: AddAnrokIntegrationDialogFragment) => void
  integration: AddAnrokIntegrationDialogFragment
}>

export interface AddAnrokDialogRef {
  openDialog: (props?: TAddAnrokDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddAnrokDialog = forwardRef<AddAnrokDialogRef>((_, ref) => {
  const componentId = useId()
  const { nangoPublicKey } = envGlobalVar()
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const { translate } = useInternationalization()
  const [localData, setLocalData] = useState<TAddAnrokDialogProps | undefined>(undefined)
  const anrokIntegration = localData?.integration
  const isEdition = !!anrokIntegration

  const [addAnrok] = useCreateAnrokIntegrationMutation({
    onCompleted({ createAnrokIntegration }) {
      if (createAnrokIntegration?.id) {
        navigate(
          generatePath(ANROK_INTEGRATION_DETAILS_ROUTE, {
            integrationId: createAnrokIntegration.id,
            tab: AnrokIntegrationDetailsTabs.Settings,
            integrationGroup: IntegrationsTabsOptionsEnum.Lago,
          }),
        )

        addToast({
          message: translate('text_6668821d94e4da4dfd8b38e9'),
          severity: 'success',
        })
      }
    },
  })

  const [updateApiKey] = useUpdateAnrokIntegrationMutation({
    onCompleted({ updateAnrokIntegration }) {
      if (updateAnrokIntegration?.id) {
        addToast({
          message: translate('text_6668821d94e4da4dfd8b38f3'),
          severity: 'success',
        })

        dialogRef.current?.closeDialog()
      }
    },
  })

  const formikProps = useFormik<Omit<CreateAnrokIntegrationInput, 'connectionId'>>({
    initialValues: {
      apiKey: anrokIntegration?.apiKey || '',
      code: anrokIntegration?.code || '',
      name: anrokIntegration?.name || '',
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      apiKey: string().required(''),
    }),
    onSubmit: async ({ apiKey, ...values }, formikBag) => {
      let res

      if (isEdition) {
        res = await updateApiKey({
          variables: {
            input: {
              id: anrokIntegration?.id || '',
              ...values,
            },
          },
          context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
        })
      } else {
        const Nango = (await import('@nangohq/frontend')).default
        const connectionId = `anrok-${componentId.replaceAll(':', '')}-${Date.now()}`
        const nango = new Nango({ publicKey: nangoPublicKey })

        try {
          const nangoApiKeyConnection = await nango.auth('anrok', connectionId, {
            credentials: {
              apiKey,
            },
          })

          res = await addAnrok({
            variables: {
              input: { ...values, apiKey, connectionId: nangoApiKeyConnection?.connectionId || '' },
            },
            context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
          })
        } catch {
          // Nothing is supposed to happen here
        }
      }

      const { errors } = res as
        FetchResult<UpdateAnrokIntegrationMutation> | FetchResult<CreateAnrokIntegrationMutation>

      if (!errors) dialogRef.current?.closeDialog()

      if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
        formikBag.setErrors({
          code: translate('text_632a2d437e341dcc76817556'),
        })
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
        isEdition ? 'text_658461066530343fe1808cd9' : 'text_666887f6c4d092aa1e1a8477',
        {
          name: anrokIntegration?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_666889d43a2ea34eb2aa3e55' : 'text_666887f6c4d092aa1e1a8478',
      )}
      onClose={formikProps.resetForm}
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
                localData?.onDelete?.(anrokIntegration)
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
                isEdition ? 'text_664c732c264d7eed1c74fdaa' : 'text_666887f6c4d092aa1e1a8477',
              )}
            </Button>
          </Stack>
        </Stack>
      )}
    >
      <div className="mb-8 flex flex-col gap-6">
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
          name="apiKey"
          disabled={isEdition}
          label={translate('text_6668821d94e4da4dfd8b38d5')}
          placeholder={translate('text_666887f6c4d092aa1e1a847e')}
          formikProps={formikProps}
        />
      </div>
    </Dialog>
  )
})

AddAnrokDialog.displayName = 'AddAnrokDialog'
