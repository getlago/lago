import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { GraphQLFormattedError } from 'graphql'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { generatePath } from 'react-router-dom'
import { object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { TextInputField } from '~/components/form'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { SALESFORCE_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  CreateSalesforceIntegrationInput,
  DeleteSalesforceIntegrationDialogFragmentDoc,
  SalesforceForCreateDialogFragment,
  useCreateSalesforceIntegrationMutation,
  useUpdateSalesforceIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

gql`
  fragment SalesforceForCreateDialog on SalesforceIntegration {
    id
    name
    code
    instanceId
    ...DeleteSalesforceIntegrationDialog
  }

  mutation createSalesforceIntegration($input: CreateSalesforceIntegrationInput!) {
    createSalesforceIntegration(input: $input) {
      ...SalesforceForCreateDialog
    }
  }

  mutation updateSalesforceIntegration($input: UpdateSalesforceIntegrationInput!) {
    updateSalesforceIntegration(input: $input) {
      ...SalesforceForCreateDialog
    }
  }

  ${DeleteSalesforceIntegrationDialogFragmentDoc}
`

type TAddSalesforceDialogProps = Partial<{
  onDelete: (provider: SalesforceForCreateDialogFragment) => void
  provider: SalesforceForCreateDialogFragment
}>

export interface AddSalesforceDialogRef {
  openDialog: (props?: TAddSalesforceDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddSalesforceDialog = forwardRef<AddSalesforceDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<TAddSalesforceDialogProps | undefined>(undefined)
  const [showGlobalError, setShowGlobalError] = useState(false)

  const salesforceProvider = localData?.provider
  const isEdition = !!salesforceProvider

  const [createIntegration] = useCreateSalesforceIntegrationMutation({
    onCompleted({ createSalesforceIntegration }) {
      if (createSalesforceIntegration?.id) {
        navigate(
          generatePath(SALESFORCE_INTEGRATION_DETAILS_ROUTE, {
            integrationId: createSalesforceIntegration.id,
            integrationGroup: IntegrationsTabsOptionsEnum.Lago,
          }),
        )

        addToast({
          message: translate('text_1731510123491jw90gdbc5kj'),
          severity: 'success',
        })
      }
    },
  })

  const [updateIntegration] = useUpdateSalesforceIntegrationMutation({
    onCompleted({ updateSalesforceIntegration }) {
      if (updateSalesforceIntegration?.id) {
        addToast({
          message: translate('text_1731510123491t2zwypps84n'),
          severity: 'success',
        })
      }
    },
  })

  const formikProps = useFormik<Omit<CreateSalesforceIntegrationInput, 'connectionId'>>({
    initialValues: {
      name: salesforceProvider?.name || '',
      code: salesforceProvider?.code || '',
      instanceId: salesforceProvider?.instanceId || '',
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      instanceId: string().required(''),
    }),
    onSubmit: async (values, formikBag) => {
      setShowGlobalError(false)

      const handleError = (errors: readonly GraphQLFormattedError[]) => {
        if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
          formikBag.setErrors({
            code: translate('text_632a2d437e341dcc76817556'),
          })

          // Scroll to top of modal container
          const modalContainer = document.getElementsByClassName('MuiDialog-container')[0]

          if (modalContainer) {
            modalContainer.scrollTo({ top: 0 })
          }
        }
      }

      try {
        if (isEdition) {
          const res = await updateIntegration({
            variables: {
              input: {
                ...values,
                id: salesforceProvider?.id || '',
              },
            },
          })

          if (res.errors) {
            return handleError(res.errors)
          }
        } else {
          const res = await createIntegration({
            variables: {
              input: values,
            },
          })

          if (res.errors) {
            return handleError(res.errors)
          }
        }
      } catch {
        setShowGlobalError(true)
      }

      dialogRef.current?.closeDialog()
    },
    validateOnMount: true,
    enableReinitialize: true,
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
        isEdition ? 'text_661ff6e56ef7e1b7c542b1d0' : 'text_1731510123491sksb908hxue',
        {
          name: salesforceProvider?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_1731510123491o9q0fi9aov2' : 'text_1731510123491i56n7tz55bx',
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
                localData?.onDelete?.(salesforceProvider)
              }}
            >
              {translate('text_65845f35d7d69c3ab4793dad')}
            </Button>
          )}
          <div className="flex flex-row items-center gap-3">
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_63eba8c65a6c8043feee2a14')}
            </Button>
            <Button
              variant="primary"
              disabled={!formikProps.isValid || !formikProps.dirty}
              onClick={formikProps.submitForm}
            >
              {translate(
                isEdition ? 'text_65845f35d7d69c3ab4793dac' : 'text_1731510123491sksb908hxue',
              )}
            </Button>
          </div>
        </div>
      )}
    >
      <div className="mb-8 flex w-full flex-col gap-8">
        {!!showGlobalError && (
          <Alert type="danger">{translate('text_1749562792335fy21gc3sxn0')}</Alert>
        )}
        <div className="flex w-full flex-row items-start gap-6 *:flex-1">
          <TextInputField
            // eslint-disable-next-line jsx-a11y/no-autofocus
            autoFocus={!isEdition}
            name="name"
            label={translate('text_6419c64eace749372fc72b0f')}
            placeholder={translate('text_6584550dc4cec7adf861504f')}
            formikProps={formikProps}
          />
          <TextInputField
            name="code"
            beforeChangeFormatter="code"
            label={translate('text_62876e85e32e0300e1803127')}
            placeholder={translate('text_6584550dc4cec7adf8615053')}
            formikProps={formikProps}
          />
        </div>
        <TextInputField
          name="instanceId"
          label={translate('text_1731510123491s8iyc3roglx')}
          placeholder={translate('text_1731510123491bap94avpqyz')}
          formikProps={formikProps}
        />
      </div>
    </Dialog>
  )
})

AddSalesforceDialog.displayName = 'AddSalesforceDialog'
