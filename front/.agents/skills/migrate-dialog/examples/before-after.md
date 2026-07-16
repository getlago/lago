# Migration Example: EditInviteRoleDialog

This example shows the complete migration of `EditInviteRoleDialog` from the legacy imperative ref-based system to the new hook-based NiceModal system.

## Dialog File

### BEFORE (Imperative Ref-Based)

```typescript
import Stack from '@mui/material/Stack'
import { revalidateLogic } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { z } from 'zod'

import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { InviteForEditRoleForDialogFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import RolePicker from './RolePicker'

import { UpdateInviteSingleRole } from '../common/inviteTypes'
import { useInviteActions } from '../hooks/useInviteActions'

export const EDIT_INVITE_ROLE_FORM_ID = 'form-edit-invite-role'
export interface EditInviteRoleDialogRef {
  openDialog: (localData: InviteForEditRoleForDialogImperativeProps) => unknown
  closeDialog: () => unknown
}

type InviteForEditRoleForDialogImperativeProps = {
  invite: InviteForEditRoleForDialogFragment | null
}

export const EditInviteRoleDialog = forwardRef<EditInviteRoleDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const { updateInviteRole } = useInviteActions()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<InviteForEditRoleForDialogImperativeProps | null>(null)

  const validationSchema = z.object({
    role: z.string(),
  })

  const initialValues: UpdateInviteSingleRole = {
    role: localData?.invite?.roles[0] || '',
  }

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value }) => {
      await updateInviteRole({
        variables: {
          input: {
            roles: [value.role],
            id: localData?.invite?.id as string,
          },
        },
      })

      setLocalData(null)
      dialogRef.current?.closeDialog()
    },
  })

  useImperativeHandle(ref, () => ({
    openDialog: (data) => {
      setLocalData(data)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => {
      dialogRef.current?.closeDialog()
    },
  }))

  const handleClose = () => {
    form.reset()
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  const getActions = ({ closeDialog }: { closeDialog: () => void }) => {
    return (
      <>
        <Button variant="quaternary" onClick={closeDialog}>
          {translate('text_62bb10ad2a10bd182d002031')}
        </Button>
        <form.AppForm>
          <form.SubmitButton>{translate('text_664f035a68227f00e261b7f6')}</form.SubmitButton>
        </form.AppForm>
      </>
    )
  }

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_664f035a68227f00e261b7e9')}
      onClose={handleClose}
      actions={getActions}
      formId={EDIT_INVITE_ROLE_FORM_ID}
      formSubmit={handleSubmit}
    >
      <div className="mb-8 flex flex-col gap-8">
        <Stack gap={3} direction="row" alignItems="center">
          <Avatar
            variant="user"
            identifier={(localData?.invite?.email || '').charAt(0)}
            size="big"
          />
          <Typography variant="body" color="grey700">
            {localData?.invite?.email}
          </Typography>
        </Stack>

        <RolePicker form={form} fields={{ role: 'role' }} />
      </div>
    </Dialog>
  )
})

EditInviteRoleDialog.displayName = 'forwardRef'
```

### AFTER (Hook-Based NiceModal)

```typescript
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
              <Avatar
                variant="user"
                identifier={(invite.email || '').charAt(0)}
                size="big"
              />
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
```

---

## Parent Component

### BEFORE

```typescript
import { useRef } from 'react'
import { EditInviteRoleDialog, EditInviteRoleDialogRef } from './dialogs/EditInviteRoleDialog'

const ParentComponent = () => {
  const editInviteRoleDialogRef = useRef<EditInviteRoleDialogRef>(null)

  const handleEdit = (invite) => {
    editInviteRoleDialogRef.current?.openDialog({ invite })
  }

  return (
    <>
      {/* ... other content */}
      <EditInviteRoleDialog ref={editInviteRoleDialogRef} />
    </>
  )
}
```

### AFTER

```typescript
import { useEditInviteRoleDialog } from './dialogs/EditInviteRoleDialog'

const ParentComponent = () => {
  const { openEditInviteRoleDialog } = useEditInviteRoleDialog()

  const handleEdit = (invite) => {
    openEditInviteRoleDialog(invite)
  }

  return (
    <>
      {/* ... other content */}
      {/* No dialog component needed in JSX */}
    </>
  )
}
```

---

## Key Differences Summary

| Aspect | Old (Imperative Ref) | New (Hook-Based NiceModal) |
| --- | --- | --- |
| Component type | `forwardRef` component | Custom hook (`useMyDialog`) |
| Opening dialog | `ref.current?.openDialog(data)` | `openMyDialog(data)` |
| Data storage | `useState(localData)` | `useRef(data)` |
| Dialog rendering | `<Dialog ref={dialogRef}>` in JSX | `formDialog.open({ children })` |
| Form submission | `handleSubmit(e)` calls `e.preventDefault()` | `handleSubmit()` returns `Promise<DialogResult>` |
| Closing dialog | `dialogRef.current?.closeDialog()` | Auto-closes on success; `.then()` for cleanup |
| Actions | `getActions({ closeDialog })` render function | `mainAction` prop (just the submit button) |
| Cancel button | Manually rendered in `actions` | Automatically rendered by FormDialog |
| Parent usage | `useRef` + render `<Dialog>` in JSX | `useHook()` + call open function |
| Parent cleanup | Remove `<Dialog>` from JSX | Nothing to render |
