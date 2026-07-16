import Stack from '@mui/material/Stack'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Typography } from '~/components/designSystem/Typography'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { HOME_ROUTE, useNavigate } from '~/core/router'
import {
  LagoApiError,
  MemberForEditRoleForDialogFragment,
  PermissionEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useRolesList } from '~/hooks/useRolesList'

import RolePicker from './RolePicker'

import { UpdateInviteSingleRole } from '../common/inviteTypes'
import { useMembershipActions } from '../hooks/useMembershipActions'

export const EDIT_MEMBER_ROLE_FORM_ID = 'form-edit-member-role'

type EditMemberRoleDialogData = {
  member: MemberForEditRoleForDialogFragment | null
  isEditingLastAdmin: boolean
  isEditingMyOwnMembership: boolean
}

const initialValues: UpdateInviteSingleRole = {
  role: '',
}

const validationSchema = z.object({
  role: z.string().min(1),
})

export const useEditMemberRoleDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { updateMembershipRole } = useMembershipActions()
  const { roles } = useRolesList()
  const dataRef = useRef<EditMemberRoleDialogData | null>(null)
  const successRef = useRef(false)

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value }) => {
      const res = await updateMembershipRole({
        variables: {
          input: {
            roles: [value.role],
            id: dataRef.current?.member?.id as string,
          },
        },
        context: { silentErrorCodes: [LagoApiError.LastAdmin] },
      })

      if (hasDefinedGQLError('LastAdmin', res.errors)) {
        addToast({
          severity: 'danger',
          translateKey: 'text_1775139501035rk0gsr7iflr',
        })

        return
      }

      if (res.data?.updateMembership) {
        successRef.current = true

        const newRole = roles.find((role) => role.name === res.data?.updateMembership?.roles[0])

        // If you edit your own memberships role to something else that do not have the right permission,
        // you will get redirected to home page
        if (
          dataRef.current?.isEditingMyOwnMembership &&
          !newRole?.permissions.includes(PermissionEnum.RolesView)
        ) {
          // The redirection have to be retriggered on the next tick to avoid wrong forbidden page display
          setTimeout(() => {
            navigate(HOME_ROUTE)
          }, 1)
        }
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

  const openEditMemberRoleDialog = (data: EditMemberRoleDialogData) => {
    dataRef.current = data
    form.reset()

    const initialRole = roles.find((role) => role.name === data.member?.roles[0])

    form.setFieldValue('role', initialRole?.code || 'admin')

    formDialog
      .open({
        title: translate('text_664f035a68227f00e261b7e9'),
        children: (
          <div className="flex flex-col gap-8 p-8">
            <Stack gap={3} direction="row" alignItems="center">
              <Avatar
                variant="user"
                identifier={(data.member?.user?.email || '').charAt(0)}
                size="big"
              />
              <Typography variant="body" color="grey700">
                {data.member?.user?.email}
              </Typography>
            </Stack>

            <RolePicker form={form} fields={{ role: 'role' }} />

            {data.isEditingLastAdmin && (
              <Alert type="danger">{translate('text_664f035a68227f00e261b7f4')}</Alert>
            )}
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('text_664f035a68227f00e261b7f6')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_MEMBER_ROLE_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          dataRef.current = null
        }
      })
  }

  return { openEditMemberRoleDialog }
}
