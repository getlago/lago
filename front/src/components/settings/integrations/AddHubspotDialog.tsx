import { gql } from '@apollo/client'
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
import { Checkbox, CheckboxField, ComboBoxField, TextInputField } from '~/components/form'
import { useDeleteHubspotIntegrationDialog } from '~/components/settings/integrations/DeleteHubspotIntegrationDialog'
import { addToast, envGlobalVar, hasDefinedGQLError } from '~/core/apolloClient'
import { getHubspotTargetedObjectTranslationKey } from '~/core/constants/form'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { HUBSPOT_INTEGRATION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import {
  CreateHubspotIntegrationInput,
  DeleteHubspotIntegrationDialogFragmentDoc,
  HubspotForCreateDialogFragment,
  HubspotTargetedObjectsEnum,
  useCreateHubspotIntegrationMutation,
  useUpdateHubspotIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

gql`
  fragment HubspotForCreateDialog on HubspotIntegration {
    id
    name
    code
    defaultTargetedObject
    syncInvoices
    syncSubscriptions
    ...DeleteHubspotIntegrationDialog
  }

  mutation createHubspotIntegration($input: CreateHubspotIntegrationInput!) {
    createHubspotIntegration(input: $input) {
      ...HubspotForCreateDialog
    }
  }

  mutation updateHubspotIntegration($input: UpdateHubspotIntegrationInput!) {
    updateHubspotIntegration(input: $input) {
      ...HubspotForCreateDialog
    }
  }

  ${DeleteHubspotIntegrationDialogFragmentDoc}
`

type TAddHubspotDialogProps = Partial<{
  provider: HubspotForCreateDialogFragment
  deleteDialogCallback: () => void
}>

export interface AddHubspotDialogRef {
  openDialog: (props?: TAddHubspotDialogProps) => unknown
  closeDialog: () => unknown
}

export const AddHubspotDialog = forwardRef<AddHubspotDialogRef>((_, ref) => {
  const componentId = useId()
  const { nangoPublicKey } = envGlobalVar()

  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<TAddHubspotDialogProps | undefined>(undefined)
  const [showGlobalError, setShowGlobalError] = useState(false)
  const hubspotProvider = localData?.provider
  const isEdition = !!hubspotProvider
  const { openDeleteHubspotIntegrationDialog } = useDeleteHubspotIntegrationDialog()

  const [createIntegration] = useCreateHubspotIntegrationMutation({
    onCompleted({ createHubspotIntegration }) {
      if (createHubspotIntegration?.id) {
        navigate(
          generatePath(HUBSPOT_INTEGRATION_DETAILS_ROUTE, {
            integrationId: createHubspotIntegration.id,
            integrationGroup: IntegrationsTabsOptionsEnum.Lago,
          }),
        )

        addToast({
          message: translate('text_1727190044775psjhxh09fsq'),
          severity: 'success',
        })
      }
    },
  })

  const [updateIntegration] = useUpdateHubspotIntegrationMutation({
    onCompleted({ updateHubspotIntegration }) {
      if (updateHubspotIntegration?.id) {
        addToast({
          message: translate('text_172719004477535rfq4o0j1s'),
          severity: 'success',
        })
      }
    },
  })

  const formikProps = useFormik<Omit<CreateHubspotIntegrationInput, 'connectionId'>>({
    initialValues: {
      name: hubspotProvider?.name || '',
      code: hubspotProvider?.code || '',
      defaultTargetedObject:
        hubspotProvider?.defaultTargetedObject || HubspotTargetedObjectsEnum.Companies,
      syncInvoices: !!hubspotProvider?.syncInvoices,
      syncSubscriptions: !!hubspotProvider?.syncSubscriptions,
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      defaultTargetedObject: string().required(''),
      syncInvoices: boolean(),
      syncSubscriptions: boolean(),
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
              id: hubspotProvider?.id || '',
            },
          },
        })

        if (res.errors) {
          return handleError(res.errors)
        }
      } else {
        const connectionId = `hubspot-${componentId.replaceAll(':', '')}-${Date.now()}`

        const nango = new Nango({ publicKey: nangoPublicKey })

        try {
          const nangoAuthResult = await nango.auth('hubspot', connectionId)

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
        isEdition ? 'text_661ff6e56ef7e1b7c542b1d0' : 'text_1727189568053ifu63v2q1gf',
        {
          name: hubspotProvider?.name,
        },
      )}
      description={translate(
        isEdition ? 'text_1727189568053fu2g4sonout' : 'text_1727189568054z4qhm7flfgh',
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
                openDeleteHubspotIntegrationDialog({
                  provider: hubspotProvider,
                  callback: localData?.deleteDialogCallback,
                })
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
                isEdition ? 'text_65845f35d7d69c3ab4793dac' : 'text_1727189568053ifu63v2q1gf',
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

        <div className="flex flex-col gap-12">
          <ComboBoxField
            name="defaultTargetedObject"
            label={translate('text_17271895680545qv3cvwk1jx')}
            formikProps={formikProps}
            data={[
              {
                label: translate(
                  getHubspotTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Companies],
                ),
                value: HubspotTargetedObjectsEnum.Companies,
              },
              {
                label: translate(
                  getHubspotTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Contacts],
                ),
                value: HubspotTargetedObjectsEnum.Contacts,
              },
            ]}
            PopperProps={{ displayInDialog: true }}
          />

          <div className="flex flex-col gap-4">
            <div>
              <Typography variant="bodyHl" color="grey700">
                {translate('text_1727190044775k62adpax08b')}
              </Typography>
              <Typography variant="caption" color="grey600">
                {translate('text_661ff6e56ef7e1b7c542b28e')}
              </Typography>
            </div>

            <Checkbox
              disabled
              label={
                <CheckboxLabelWithCode
                  firstPart={translate('text_1727190044775yssj1flnpe9')}
                  code={translate('text_1727281892403bkjbojs75t7')}
                  lastPart={translate('text_1727190044775p6mbfwbzv36')}
                />
              }
              value={true}
            />

            <Checkbox
              disabled
              label={
                <CheckboxLabelWithCode
                  firstPart={translate('text_1727190044775yssj1flnpe9')}
                  code={translate('text_1727281892403m7aoqothh7r')}
                  lastPart={translate('text_1727190044775p6mbfwbzv36')}
                />
              }
              value={true}
            />

            <CheckboxField
              name="syncInvoices"
              formikProps={formikProps}
              label={
                <CheckboxLabelWithCode
                  firstPart={translate('text_1727190044775yssj1flnpe9')}
                  code={translate('text_1727281892403ljelfgyyupg')}
                  lastPart={translate('text_172719004477572tu71psqqt')}
                />
              }
            />
            <CheckboxField
              name="syncSubscriptions"
              formikProps={formikProps}
              label={
                <CheckboxLabelWithCode
                  firstPart={translate('text_1727190044775yssj1flnpe9')}
                  code={translate('text_1727281892403w0qjgmdf8n4')}
                  lastPart={translate('text_172719004477572tu71psqqt')}
                />
              }
            />
          </div>
        </div>
      </div>
    </Dialog>
  )
})

const CheckboxLabelWithCode = ({
  firstPart,
  code,
  lastPart,
}: {
  firstPart: string
  code: string
  lastPart: string
}) => {
  return (
    <div className="flex flex-row flex-wrap items-center gap-1">
      <Typography variant="body" color="grey700">
        {firstPart}
      </Typography>
      <Chip size="small" label={code} color="danger600" />
      <Typography variant="body" color="grey700">
        {lastPart}
      </Typography>
    </div>
  )
}

AddHubspotDialog.displayName = 'AddHubspotDialog'
