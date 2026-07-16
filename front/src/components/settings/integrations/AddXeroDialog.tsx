import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import Nango from '@nangohq/frontend'
import { useFormik } from 'formik'
import { GraphQLFormattedError } from 'graphql'
import { forwardRef, useId, useImperativeHandle, useRef, useState } from 'react'
import { generatePath } from 'react-router-dom'
import { boolean, object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { Checkbox, CheckboxField, TextInputField } from '~/components/form'
import { addToast, envGlobalVar, hasDefinedGQLError } from '~/core/apolloClient'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { useNavigate, XERO_INTEGRATION_DETAILS_ROUTE } from '~/core/router'
import {
  CreateXeroIntegrationInput,
  useCreateXeroIntegrationMutation,
  useUpdateXeroIntegrationMutation,
  XeroForCreateDialogDialogFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { XeroIntegrationDetailsTabs } from '~/pages/settings/XeroIntegrationDetails'

gql`
  fragment XeroForCreateDialogDialog on XeroIntegration {
    id
    code
    connectionId
    hasMappingsConfigured
    name
    syncCreditNotes
    syncInvoices
    syncPayments
  }

  mutation createXeroIntegration($input: CreateXeroIntegrationInput!) {
    createXeroIntegration(input: $input) {
      ...XeroForCreateDialogDialog
    }
  }

  mutation updateXeroIntegration($input: UpdateXeroIntegrationInput!) {
    updateXeroIntegration(input: $input) {
      ...XeroForCreateDialogDialog
    }
  }
`

type TAddXeroDialogProps = Partial<{
  onDelete: (provider: XeroForCreateDialogDialogFragment) => void
  provider: XeroForCreateDialogDialogFragment
}>

export interface AddXeroDialogRef {
  openDialog: (props?: TAddXeroDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddXeroDialog = forwardRef<AddXeroDialogRef>((_, ref) => {
  const componentId = useId()
  const { nangoPublicKey } = envGlobalVar()

  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<TAddXeroDialogProps | undefined>(undefined)
  const [showGlobalError, setShowGlobalError] = useState(false)
  const xeroProvider = localData?.provider
  const isEdition = !!xeroProvider

  const [createIntegration] = useCreateXeroIntegrationMutation({
    onCompleted({ createXeroIntegration }) {
      if (createXeroIntegration?.id) {
        navigate(
          generatePath(XERO_INTEGRATION_DETAILS_ROUTE, {
            integrationId: createXeroIntegration.id,
            tab: XeroIntegrationDetailsTabs.Settings,
            integrationGroup: IntegrationsTabsOptionsEnum.Lago,
          }),
        )

        addToast({
          message: translate('text_6672ebb8b1b50be550eccb00'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getXeroIntegrationsList'],
  })

  const [updateIntegration] = useUpdateXeroIntegrationMutation({
    onCompleted({ updateXeroIntegration }) {
      if (updateXeroIntegration?.id) {
        addToast({
          message: translate('text_6672ebb8b1b50be550eccb0b'),
          severity: 'success',
        })
      }
    },
  })

  const formikProps = useFormik<Omit<CreateXeroIntegrationInput, 'connectionId'>>({
    initialValues: {
      code: xeroProvider?.code || '',
      name: xeroProvider?.name || '',
      syncCreditNotes: !!xeroProvider?.syncCreditNotes,
      syncInvoices: !!xeroProvider?.syncInvoices,
      syncPayments: !!xeroProvider?.syncPayments,
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      syncCreditNotes: boolean(),
      syncInvoices: boolean(),
      syncPayments: boolean(),
    }),
    onSubmit: async ({ ...values }, formikBag) => {
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

      if (isEdition) {
        const res = await updateIntegration({
          variables: {
            input: {
              ...values,
              id: xeroProvider?.id || '',
            },
          },
        })

        if (res.errors) {
          return handleError(res.errors)
        }
      } else {
        const connectionId = `xero-${componentId.replaceAll(':', '')}-${Date.now()}`
        const nango = new Nango({ publicKey: nangoPublicKey })

        try {
          const nangoAuthResult = await nango.auth('xero', connectionId)

          if (!!nangoAuthResult) {
            const res = await createIntegration({
              variables: {
                input: { ...values, connectionId },
              },
            })

            if (res.errors) {
              return handleError(res.errors)
            }
          }
        } catch {
          setShowGlobalError(true)
          return
        }
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
        isEdition ? 'text_661ff6e56ef7e1b7c542b1d0' : 'text_6672ebb8b1b50be550ecca9e',
        {
          name: xeroProvider?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_6672ee6c7b6cb300d6cc31f3' : 'text_6672ebb8b1b50be550eccaa6',
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
                localData?.onDelete?.(xeroProvider)
              }}
            >
              {translate('text_65845f35d7d69c3ab4793dad')}
            </Button>
          )}
          <Stack direction="row" spacing={3} alignItems="center">
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_63eba8c65a6c8043feee2a14')}
            </Button>
            <Button
              variant="primary"
              disabled={!formikProps.isValid || !formikProps.dirty}
              onClick={formikProps.submitForm}
            >
              {translate(
                isEdition ? 'text_65845f35d7d69c3ab4793dac' : 'text_6672ebb8b1b50be550ecca9e',
              )}
            </Button>
          </Stack>
        </Stack>
      )}
    >
      <Stack spacing={8} marginBottom={8}>
        {!!showGlobalError && (
          <Alert type="danger">{translate('text_1749562792335fy21gc3sxn0')}</Alert>
        )}

        <Stack spacing={6}>
          <div className="flex flex-row items-start gap-6">
            <TextInputField
              className="flex-1"
              // eslint-disable-next-line jsx-a11y/no-autofocus
              autoFocus={!isEdition}
              name="name"
              label={translate('text_6419c64eace749372fc72b0f')}
              placeholder={translate('text_6584550dc4cec7adf861504f')}
              formikProps={formikProps}
            />
            <TextInputField
              className="flex-1"
              name="code"
              beforeChangeFormatter="code"
              label={translate('text_62876e85e32e0300e1803127')}
              placeholder={translate('text_6584550dc4cec7adf8615053')}
              formikProps={formikProps}
            />
          </div>
        </Stack>

        <Stack spacing={6}>
          <div>
            <Typography variant="bodyHl" color="grey700">
              {translate('text_6672ebb8b1b50be550eccad6')}
            </Typography>
            <Typography variant="caption" color="grey600">
              {translate('text_661ff6e56ef7e1b7c542b28e')}
            </Typography>
          </div>

          <Stack spacing={4}>
            <Checkbox
              disabled
              label={
                <Stack spacing={1} direction="row" alignItems="center" flexWrap="wrap">
                  <Typography variant="body" color="grey700">
                    {translate('text_6672ebb8b1b50be550eccaee')}
                  </Typography>
                  <Chip
                    size="small"
                    label={translate('text_661ff6e56ef7e1b7c542b2a6')}
                    color="danger600"
                  />
                  <Typography variant="body" color="grey700">
                    {translate('text_661ff6e56ef7e1b7c542b29e')}
                  </Typography>
                </Stack>
              }
              value={true}
            />
            <Checkbox
              disabled
              label={
                <Stack spacing={1} direction="row" alignItems="center" flexWrap="wrap">
                  <Typography variant="body" color="grey700">
                    {translate('text_6672ebb8b1b50be550eccaee')}
                  </Typography>
                  <Chip
                    size="small"
                    label={translate('text_661ff6e56ef7e1b7c542b2c2')}
                    color="danger600"
                  />
                  <Typography variant="body" color="grey700">
                    {translate('text_661ff6e56ef7e1b7c542b29e')}
                  </Typography>
                </Stack>
              }
              value={true}
            />
            <Checkbox
              disabled
              label={
                <Stack spacing={1} direction="row" alignItems="center" flexWrap="wrap">
                  <Typography variant="body" color="grey700">
                    {translate('text_6672ebb8b1b50be550eccaee')}
                  </Typography>
                  <Chip
                    size="small"
                    label={translate('text_661ff6e56ef7e1b7c542b2d7')}
                    color="danger600"
                  />
                  <Typography variant="body" color="grey700">
                    {translate('text_661ff6e56ef7e1b7c542b29e')}
                  </Typography>
                </Stack>
              }
              value={true}
            />
            <CheckboxField
              name="syncCreditNotes"
              label={
                <Stack spacing={1} direction="row" alignItems="center" flexWrap="wrap">
                  <Typography variant="body" color="grey700">
                    {translate('text_6672ebb8b1b50be550eccaee')}
                  </Typography>
                  <Chip
                    size="small"
                    label={translate('text_661ff6e56ef7e1b7c542b2e9')}
                    color="danger600"
                  />
                  <Typography variant="body" color="grey700">
                    {translate('text_661ff6e56ef7e1b7c542b29e')}
                  </Typography>
                </Stack>
              }
              formikProps={formikProps}
            />
            <CheckboxField
              name="syncInvoices"
              label={
                <Stack spacing={1} direction="row" alignItems="center" flexWrap="wrap">
                  <Typography variant="body" color="grey700">
                    {translate('text_6672ebb8b1b50be550eccaee')}
                  </Typography>
                  <Chip
                    size="small"
                    label={translate('text_661ff6e56ef7e1b7c542b2ff')}
                    color="danger600"
                  />
                  <Typography variant="body" color="grey700">
                    {translate('text_661ff6e56ef7e1b7c542b29e')}
                  </Typography>
                </Stack>
              }
              formikProps={formikProps}
            />
            <CheckboxField
              name="syncPayments"
              label={
                <Stack spacing={1} direction="row" alignItems="center" flexWrap="wrap">
                  <Typography variant="body" color="grey700">
                    {translate('text_6672ebb8b1b50be550eccaee')}
                  </Typography>
                  <Chip
                    size="small"
                    label={translate('text_661ff6e56ef7e1b7c542b311')}
                    color="danger600"
                  />
                  <Typography variant="body" color="grey700">
                    {translate('text_661ff6e56ef7e1b7c542b29e')}
                  </Typography>
                </Stack>
              }
              formikProps={formikProps}
            />
          </Stack>
        </Stack>
      </Stack>
    </Dialog>
  )
})

AddXeroDialog.displayName = 'AddXeroDialog'
