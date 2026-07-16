import Stack from '@mui/material/Stack'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'
import { z } from 'zod'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { scrollToFirstInputError } from '~/core/form/scrollToFirstInputError'
import { INVITATION_ROUTE } from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { zodRequiredEmail } from '~/formValidation/zodCustoms'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import CopyInviteLink from './CopyInviteLink'
import RolePicker from './RolePicker'

import { CreateInviteSingleRole } from '../common/inviteTypes'
import { useInviteActions } from '../hooks/useInviteActions'

export const SUBMIT_INVITE_DATA_TEST = 'submit-invite-button'
export const FORM_CREATE_INVITE_ID = 'form-create-invite'
export const INVITE_URL_DATA_TEST = 'invitation-url'
const FORM_INVALID_ERROR_MESSAGE = 'form.invalid'

const initialValues: CreateInviteSingleRole = {
  email: '',
  role: '',
}

const generateInvitationUrl = (inviteToken: string) => {
  return `${globalThis.location.origin}${generatePath(INVITATION_ROUTE, {
    token: inviteToken,
  })}`
}

const CreateInviteForm = withForm({
  defaultValues: initialValues,
  render: function Render({ form }) {
    const { translate } = useInternationalization()

    return (
      <div className="p-8">
        <Stack gap={8}>
          <form.AppField name="email">
            {(field) => (
              <field.TextInputField
                beforeChangeFormatter={['lowercase']}
                label={translate('text_63208c701ce25db7814074ab')}
                placeholder={translate('text_63208c711ce25db7814074c1')}
              />
            )}
          </form.AppField>
          <RolePicker form={form} fields={{ role: 'role' }} />
        </Stack>
      </div>
    )
  },
})

export const useCreateInviteDialog = () => {
  const formDialog = useFormDialog()
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const { createInvite } = useInviteActions()
  const inviteTokenRef = useRef('')

  const validationSchema = z.object({
    email: zodRequiredEmail,
    role: z.string().min(1, 'text_1768219065391kkeiaebav23'),
  })

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value, formApi }) => {
      const result = await createInvite({
        variables: {
          input: {
            email: value.email.trim(),
            roles: [value.role],
          },
        },
      })

      const { errors } = result

      if (
        hasDefinedGQLError('InviteAlreadyExists', errors) ||
        hasDefinedGQLError('EmailAlreadyUsed', errors)
      ) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              email: {
                message: 'text_63208c701ce25db781407456',
                path: ['email'],
              },
            },
          },
        })

        return
      }

      inviteTokenRef.current = result.data?.createInvite?.token ?? ''
    },
    onSubmitInvalid({ formApi }) {
      scrollToFirstInputError(FORM_CREATE_INVITE_ID, formApi.state.errorMap.onDynamic || {})
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    inviteTokenRef.current = ''
    await form.handleSubmit()

    if (!inviteTokenRef.current) {
      throw new Error(FORM_INVALID_ERROR_MESSAGE)
    }

    return { reason: 'success', params: { inviteToken: inviteTokenRef.current } }
  }

  const title = translate('text_63208c701ce25db78140748f')

  const resetForm = () => {
    inviteTokenRef.current = ''
    form.reset()
  }
  const { organization } = useOrganizationInfos()

  const onError = (e: Error) => {
    if (e.message === FORM_INVALID_ERROR_MESSAGE) return

    addToast({
      severity: 'danger',
      message: translate('text_63208c701ce25db781407485'),
    })
  }

  const openCopyInviteLinkDialog = (inviteToken: string) => {
    const invitationUrl = generateInvitationUrl(inviteToken)

    centralizedDialog
      .open({
        title,
        description: translate('text_63208c701ce25db78140743a', {
          organizationName: organization?.name,
        }),
        actionText: translate('text_63208c701ce25db7814074a3'),
        children: (
          <CopyInviteLink
            email={form.state.values.email}
            role={form.state.values.role}
            inviteToken={inviteToken}
          />
        ),
        onAction: () => {
          copyToClipboard(invitationUrl)

          addToast({
            severity: 'info',
            translateKey: 'text_63208c711ce25db781407536',
          })
        },
      })
      .then((response) => {
        if (response.reason === 'close') resetForm()
      })
  }

  const openCreateInviteDialog = () => {
    formDialog
      .open({
        title,
        description: translate('text_63208c701ce25db78140749b'),
        children: <CreateInviteForm form={form} />,
        closeOnError: false,
        onError,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton dataTest={SUBMIT_INVITE_DATA_TEST}>
              {translate('text_63208c711ce25db7814074d9')}
            </form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: FORM_CREATE_INVITE_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') resetForm()
        if (response.reason === 'success') {
          const { inviteToken } = (response.params ?? {}) as { inviteToken: string }

          openCopyInviteLinkDialog(inviteToken)
        }
      })
  }

  return {
    openCreateInviteDialog,
  }
}
