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
import { NETSUITE_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  CreateNetsuiteIntegrationInput,
  NetsuiteForCreateDialogDialogFragment,
  useCreateNetsuiteIntegrationMutation,
  useUpdateNetsuiteIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { NetsuiteIntegrationDetailsTabs } from '~/pages/settings/NetsuiteIntegrationDetails'

gql`
  fragment NetsuiteForCreateDialogDialog on NetsuiteIntegration {
    id
    accountId
    clientId
    clientSecret
    code
    name
    scriptEndpointUrl
    syncCreditNotes
    syncInvoices
    syncPayments
    tokenId
    tokenSecret
  }

  mutation createNetsuiteIntegration($input: CreateNetsuiteIntegrationInput!) {
    createNetsuiteIntegration(input: $input) {
      ...NetsuiteForCreateDialogDialog
    }
  }

  mutation updateNetsuiteIntegration($input: UpdateNetsuiteIntegrationInput!) {
    updateNetsuiteIntegration(input: $input) {
      ...NetsuiteForCreateDialogDialog
    }
  }
`

type TAddNetsuiteDialogProps = Partial<{
  onDelete: (provider: NetsuiteForCreateDialogDialogFragment) => void
  provider: NetsuiteForCreateDialogDialogFragment
}>

export interface AddNetsuiteDialogRef {
  openDialog: (props?: TAddNetsuiteDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddNetsuiteDialog = forwardRef<AddNetsuiteDialogRef>((_, ref) => {
  const componentId = useId()
  const { nangoPublicKey } = envGlobalVar()

  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<TAddNetsuiteDialogProps | undefined>(undefined)
  const [showGlobalError, setShowGlobalError] = useState(false)
  const netsuiteProvider = localData?.provider
  const isEdition = !!netsuiteProvider

  const [createIntegration] = useCreateNetsuiteIntegrationMutation({
    onCompleted({ createNetsuiteIntegration }) {
      if (createNetsuiteIntegration?.id) {
        navigate(
          generatePath(NETSUITE_INTEGRATION_DETAILS_ROUTE, {
            integrationId: createNetsuiteIntegration.id,
            tab: NetsuiteIntegrationDetailsTabs.Settings,
            integrationGroup: IntegrationsTabsOptionsEnum.Lago,
          }),
        )

        addToast({
          message: translate('text_661ff6e56ef7e1b7c542b2c4'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getNetsuiteIntegrationsList'],
  })

  const [updateIntegration] = useUpdateNetsuiteIntegrationMutation({
    onCompleted({ updateNetsuiteIntegration }) {
      if (updateNetsuiteIntegration?.id) {
        addToast({
          message: translate('text_661ff6e56ef7e1b7c542b2cc'),
          severity: 'success',
        })
      }
    },
  })

  const formikProps = useFormik<Omit<CreateNetsuiteIntegrationInput, 'connectionId'>>({
    initialValues: {
      name: netsuiteProvider?.name || '',
      code: netsuiteProvider?.code || '',
      accountId: netsuiteProvider?.accountId || '',
      clientId: netsuiteProvider?.clientId || '',
      clientSecret: netsuiteProvider?.clientSecret || '',
      tokenId: netsuiteProvider?.tokenId || '',
      tokenSecret: netsuiteProvider?.tokenSecret || '',
      scriptEndpointUrl: netsuiteProvider?.scriptEndpointUrl || '',
      syncCreditNotes: !!netsuiteProvider?.syncCreditNotes,
      syncInvoices: !!netsuiteProvider?.syncInvoices,
      syncPayments: !!netsuiteProvider?.syncPayments,
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      accountId: string().required(''),
      clientId: string().required(''),
      clientSecret: string().required(''),
      tokenId: string().required(''),
      tokenSecret: string().required(''),
      scriptEndpointUrl: string().url('').required(''),
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
              id: netsuiteProvider?.id || '',
            },
          },
        })

        if (res.errors) {
          return handleError(res.errors)
        }
      } else {
        const connectionId = `netsuite-tba-${componentId.replaceAll(':', '')}-${Date.now()}`

        const nango = new Nango({ publicKey: nangoPublicKey })

        try {
          const nangoAuthResult = await nango.auth('netsuite-tba', connectionId, {
            params: { accountId: values.accountId },
            credentials: {
              token_id: values.tokenId,
              token_secret: values.tokenSecret,
              oauth_client_id_override: values.clientId,
              oauth_client_secret_override: values.clientSecret,
            },
          })

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
        isEdition ? 'text_661ff6e56ef7e1b7c542b1d0' : 'text_661ff6e56ef7e1b7c542b326',
        {
          name: netsuiteProvider?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_661ff6e56ef7e1b7c542b1da' : 'text_661ff6e56ef7e1b7c542b1d6',
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
                localData?.onDelete?.(netsuiteProvider)
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
                isEdition ? 'text_65845f35d7d69c3ab4793dac' : 'text_661ff6e56ef7e1b7c542b326',
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

          <TextInputField
            name="accountId"
            beforeChangeFormatter={['lowercase', 'trim', 'dashSeparator']}
            disabled={isEdition}
            label={translate('text_661ff6e56ef7e1b7c542b216')}
            placeholder={translate('text_661ff6e56ef7e1b7c542b224')}
            formikProps={formikProps}
          />
          <TextInputField
            name="clientId"
            disabled={isEdition}
            label={translate('text_661ff6e56ef7e1b7c542b230')}
            placeholder={translate('text_661ff6e56ef7e1b7c542b23b')}
            formikProps={formikProps}
          />
          <TextInputField
            name="clientSecret"
            disabled={isEdition}
            label={translate('text_661ff6e56ef7e1b7c542b247')}
            placeholder={translate('text_661ff6e56ef7e1b7c542b251')}
            formikProps={formikProps}
          />
          <TextInputField
            name="tokenId"
            disabled={isEdition}
            label={translate('text_6683cd0bab4ac0007e913af7')}
            placeholder={translate('text_6683cd1bb93b060070e9a596')}
            formikProps={formikProps}
          />
          <TextInputField
            name="tokenSecret"
            disabled={isEdition}
            label={translate('text_6683cd29cfb79500e588ee47')}
            placeholder={translate('text_6683cd3f33ac8f005b67345c')}
            formikProps={formikProps}
          />
        </Stack>

        <Stack spacing={6}>
          <div>
            <Typography variant="bodyHl" color="grey700">
              {translate('text_661ff6e56ef7e1b7c542b25b')}
            </Typography>
            <Typography variant="caption" color="grey600">
              {translate('text_661ff6e56ef7e1b7c542b267')}
            </Typography>
          </div>

          <TextInputField
            name="scriptEndpointUrl"
            label={translate('text_661ff6e56ef7e1b7c542b271')}
            placeholder={translate('text_661ff6e56ef7e1b7c542b27d')}
            formikProps={formikProps}
            error={undefined} // Make sure to remove yup default error
          />
        </Stack>

        <Stack spacing={6}>
          <div>
            <Typography variant="bodyHl" color="grey700">
              {translate('text_661ff6e56ef7e1b7c542b286')}
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
                    {translate('text_661ff6e56ef7e1b7c542b296')}
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
            <CheckboxField
              name="syncCreditNotes"
              label={
                <Stack spacing={1} direction="row" alignItems="center" flexWrap="wrap">
                  <Typography variant="body" color="grey700">
                    {translate('text_661ff6e56ef7e1b7c542b296')}
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
                    {translate('text_661ff6e56ef7e1b7c542b296')}
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
                    {translate('text_661ff6e56ef7e1b7c542b296')}
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

AddNetsuiteDialog.displayName = 'AddNetsuiteDialog'
