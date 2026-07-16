import Stack from '@mui/material/Stack'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { Avatar } from '~/components/designSystem/Avatar'
import { Typography } from '~/components/designSystem/Typography'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { InviteForEditRoleForDialogFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import RolePicker from './RolePicker'

import { UpdateInviteSingleRole } from '../common/inviteTypes'
import { useInviteActions } from '../hooks/useInviteActions'

export const EDIT_INVITE_ROLE_FORM_ID = 'form-edit-invite-role'

const initialValues: UpdateInviteSingleRole = {
  role: '',
}

const validationSchema = z.object({
  role: z.string(),
})

export const useEditInviteRoleDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const { updateInviteRole } = useInviteActions()
  const inviteRef = useRef<InviteForEditRoleForDialogFragment | null>(null)
  const successRef = useRef(false)

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value }) => {
      const result = await updateInviteRole({
        variables: {
          input: {
            roles: [value.role],
            id: inviteRef.current?.id as string,
          },
        },
      })

      if (result.data?.updateInvite) {
        successRef.current = true
      }
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    successRef.current = false
    await form.handleSubmit()

    if (!successRef.current) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openEditInviteRoleDialog = (invite: InviteForEditRoleForDialogFragment) => {
    inviteRef.current = invite
    form.reset()
    form.setFieldValue('role', invite.roles[0] || '')

    formDialog
      .open({
        title: translate('text_664f035a68227f00e261b7e9'),
        children: (
          <div className="flex flex-col gap-8 p-8">
            <Stack gap={3} direction="row" alignItems="center">
              <Avatar variant="user" identifier={(invite.email || '').charAt(0)} size="big" />
              <Typography variant="body" color="grey700">
                {invite.email}
              </Typography>
            </Stack>
            <RolePicker form={form} fields={{ role: 'role' }} />
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('text_664f035a68227f00e261b7f6')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_INVITE_ROLE_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          inviteRef.current = null
        }
      })
  }

  return { openEditInviteRoleDialog }
}
