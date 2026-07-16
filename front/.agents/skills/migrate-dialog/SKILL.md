---
name: migrate-dialog
description: Migrate a dialog component from the legacy imperative ref-based Dialog system to the new hook-based NiceModal dialog system (FormDialog, CentralizedDialog, or FormDialogOpeningDialog). This skill focuses only on the migration — testing is handled separately.
user-invocable: true
argument-hint: '<path-to-dialog>'
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, AskUserQuestion
---

# Dialog Migration Skill

**Target dialog to migrate:** `$ARGUMENTS`

> **Important:** If no path was provided above (empty or missing), use the AskUserQuestion tool to ask the user for the path to the dialog they want to migrate before proceeding.

This skill guides the migration of dialog components from the legacy imperative ref-based system (`forwardRef` + `useImperativeHandle` + `Dialog` from design system) to the new hook-based NiceModal system (`useFormDialog` / `useCentralizedDialog` / `useFormDialogOpeningDialog`).

> **Note:** This skill only handles the migration of the dialog and its parent component(s). Tests should be updated separately using a dedicated testing skill.

## Prerequisites

Before starting, gather context by reading these reference files:

### New Dialog System

1. **FormDialog**: `src/components/dialogs/FormDialog.tsx` - Dialog with form support
2. **CentralizedDialog**: `src/components/dialogs/CentralizedDialog.tsx` - Simple action/confirmation dialog
3. **FormDialogOpeningDialog**: `src/components/dialogs/FormDialogOpeningDialog.tsx` - Form dialog that can also open a secondary CentralizedDialog (e.g., delete from within edit)
4. **BaseDialog**: `src/components/dialogs/BaseDialog.tsx` - Underlying dialog component
5. **Dialog Types**: `src/components/dialogs/types.ts` - `DialogResult`, `HookDialogReturnType`, `FormProps`
6. **Dialog Constants**: `src/components/dialogs/const.ts` - Dialog names and test IDs
7. **Registered Dialogs**: `src/core/dialogs/registeredDialogs.ts` - NiceModal registration

### Migration Examples

7. **FormDialog Example**: `src/pages/settings/teamAndSecurity/members/dialogs/CreateInviteDialog.tsx` - Hook-based FormDialog
8. **FormDialog Example 2**: `src/pages/settings/teamAndSecurity/members/dialogs/EditInviteRoleDialog.tsx` - Hook-based FormDialog (simpler)
9. **CentralizedDialog Example**: `src/pages/settings/teamAndSecurity/members/dialogs/RevokeInviteDialog.tsx` - Hook-based CentralizedDialog
10. **CentralizedDialog Example 2**: `src/pages/settings/teamAndSecurity/members/dialogs/RevokeMembershipDialog.tsx` - CentralizedDialog with conditional behavior
11. **FormDialogOpeningDialog Example**: `src/pages/settings/teamAndSecurity/authentication/dialogs/AddOktaDialog.tsx` - Form dialog with optional secondary action (delete from within edit)

---

## Migration Steps

### Phase 1: Pre-Migration Analysis

#### Step 1.1: Analyze the Current Dialog

1. Read the target dialog file completely
2. Identify:
   - Whether it's a **form dialog** (has form fields + submit) or a **simple dialog** (just actions/display)
   - Whether it's a **deletion dialog** (mutation destroys a resource). If so, see [Deletion dialogs: cache eviction](#deletion-dialogs-cache-eviction) - the migration must also fix cache handling, not just the dialog system. This is especially common for integration delete dialogs (`destroyPaymentProvider`, etc.).
   - The imperative ref interface (`openDialog`, `closeDialog`)
   - Internal state managed via `useState` (typically `localData`)
   - Form setup (if any): `useAppForm`, validation schema, `onSubmit` handler
   - What data is passed via `openDialog(data)`
   - The dialog's JSX content (children)
   - The dialog's actions (submit button, cancel button)

#### Step 1.2: Determine Target Dialog Type

| Old Dialog Pattern                             | New Dialog Type                                     | When to Use                                             |
| ---------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------- |
| Has form fields + submit button                | `useFormDialog`                                     | Dialog contains a form with validation                  |
| Has a single action button (confirm/copy/etc.) | `useCentralizedDialog`                              | Dialog is for confirmation or simple action             |
| Uses `useCentralizedDialog`                    | Confirmation/warning dialogs with danger/info modes |
| Chains to another dialog after success         | Both                                                | Use FormDialog for the form, chain to CentralizedDialog |
| Form dialog + optional secondary action button (e.g., delete from edit) | `useFormDialogOpeningDialog` | Form dialog with a danger/action button that opens a CentralizedDialog |

#### Step 1.3: Find All Usages

Search for all places where the dialog is used:

```bash
grep -r "DialogName\|DialogNameRef" src/ --include="*.tsx" --include="*.ts"
```

Identify:

- Parent components that create refs and render the dialog
- How `openDialog` is called and what data is passed
- Any props passed to the dialog component (these need to be moved to the open function data or computed in the parent)

---

### Phase 2: Implementation

#### Step 2.1: Rewrite the Dialog as a Custom Hook

**Old Pattern (imperative ref-based):**

```typescript
export interface MyDialogRef {
  openDialog: (data: MyDialogData) => unknown
  closeDialog: () => unknown
}

export const MyDialog = forwardRef<MyDialogRef>((_, ref) => {
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<MyDialogData | null>(null)

  useImperativeHandle(ref, () => ({
    openDialog: (data) => {
      setLocalData(data)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  return (
    <Dialog ref={dialogRef} title={...} actions={...} formId={...} formSubmit={...}>
      {/* content using localData */}
    </Dialog>
  )
})
```

**New Pattern (hook-based with FormDialog):**

```typescript
export const useMyDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  // ... other hooks (mutations, etc.)
  const dataRef = useRef<MyData | null>(null)
  const successRef = useRef(false)

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: { onDynamic: validationSchema },
    onSubmit: async ({ value }) => {
      const result = await myMutation({
        variables: { input: { ...value, id: dataRef.current?.id as string } },
      })

      if (result.data?.myMutation) {
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

  const openMyDialog = (data: MyData) => {
    dataRef.current = data
    form.reset()
    // Set form values from data if editing
    form.setFieldValue('fieldName', data.fieldValue || '')

    formDialog
      .open({
        title: translate('...'),
        children: (
          <div className="...">
            {/* Dialog content */}
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('...')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: MY_FORM_ID,
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

  return { openMyDialog }
}
```

**Which success signal to use in `handleSubmit`:**

`FormDialog` only keeps the dialog open when `handleSubmit` **throws** (with `closeOnError: false`); returning any value closes it. So `handleSubmit` must throw on failure — the question is how it detects failure:

- **`onSubmit` runs an operation that can fail _without throwing_** (e.g. a mutation that returns GraphQL errors instead of rejecting) → track success with a manual flag (`successRef`) set inside `onSubmit` only on real success, as shown above. `form.state.isSubmitSuccessful` can't see a soft failure — it's `true` whenever `onSubmit` didn't throw, even if the mutation returned errors.
- **`onSubmit` has no failure mode beyond validation** (e.g. it just calls a callback — no mutation) → drop the `successRef` and read the built-in **`form.state.isSubmitSuccessful`** directly:

```typescript
const handleSubmit = async (): Promise<DialogResult> => {
  await form.handleSubmit()

  // isSubmitSuccessful: reset to false at the start of each submit, stays false if
  // validation fails (onSubmit never runs), true only after onSubmit resolves
  // without throwing. Throw to keep the dialog open (closeOnError: false).
  if (!form.state.isSubmitSuccessful) {
    throw new Error('Submit failed')
  }

  return { reason: 'success' }
}
```

Do **not** drop `validationLogic` to "simplify" — without `revalidateLogic()` the `onDynamic` validator never runs and the schema is silently skipped. Keep `revalidateLogic()` (the default, submit-first); do not use `revalidateLogic({ mode: 'change' })` unless a field genuinely needs live validation feedback.

**New Pattern (hook-based with CentralizedDialog):**

```typescript
export const useMyDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const openMyDialog = (data: MyData) => {
    centralizedDialog.open({
      title: translate('...'),
      description: translate('...'),
      actionText: translate('...'),
      colorVariant: 'danger', // or 'info'
      onAction: async () => {
        // Perform action (e.g., mutation, copy to clipboard)
        await myMutation({ variables: { input: { id: data.id } } })
      },
    })
  }

  return { openMyDialog }
}
```

#### Deletion dialogs: cache eviction

If the dialog's mutation **destroys a resource** (delete customer, delete an integration/payment provider, etc.), the migration must also fix Apollo cache handling. Do **not** carry over a legacy `refetchQueries` + bare `cache.evict()` combo.

**Why:** a bare `cache.evict()` broadcasts to **all** active `watchQuery` subscriptions. A still-mounted (or Apollo-retained `cache-and-network`) detail-page query then refires, gets a **404** for the just-deleted entity, and the global error link shows a danger toast. `refetchQueries` with named queries makes it worse by refetching every cached query that referenced the dead entity. This is a recurring bug, especially for **integration delete dialogs**.

**Use the `evictFromCache` helper** (`src/core/apolloClient/evictFromCache.ts`). It removes the entity from paginated list fields, nulls single-reference root fields (keeps retained detail queries' cache diff complete so they don't refetch), and suppresses all watchers except the named list query - then evicts + `gc()`.

```typescript
import { gql, useApolloClient } from '@apollo/client'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import { GetMyListDocument, useDeleteMyEntityMutation } from '~/generated/graphql'

export const useDeleteMyEntityDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  // No refetchQueries, no inline update/evict here
  const [deleteMyEntity] = useDeleteMyEntityMutation()

  const openDeleteMyEntityDialog = (data: { entity: MyEntity | null; callback?: () => void }) => {
    centralizedDialog.open({
      title: translate('...'),
      description: translate('...'),
      actionText: translate('...'),
      colorVariant: 'danger',
      onAction: async () => {
        const res = await deleteMyEntity({
          variables: { input: { id: data.entity?.id as string } },
        })

        const destroyedId = res.data?.destroyMyEntity?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'MyEntity',
            listFieldName: 'myEntities', // root query field with { collection, metadata }
            listQueryDocument: GetMyListDocument,
          })

          data.callback?.()
          addToast({ message: translate('...'), severity: 'success' })
        }
      },
    })
  }

  return { openDeleteMyEntityDialog }
}
```

**Canonical example:** `src/components/settings/integrations/DeleteAdyenIntegrationDialog.tsx`. The `__typename` (e.g. `CashfreeProvider`), `listFieldName` (e.g. `paymentProviders`), and `listQueryDocument` come from the list page's query. For entities in multiple lists, pass arrays to `listFieldName`/`listQueryDocument` (see the helper's JSDoc).

**New Pattern (hook-based with FormDialogOpeningDialog):**

Use this when a form dialog also needs a secondary action button (typically a danger button like "Delete") that opens a CentralizedDialog. This combines FormDialog behavior (form fields, validation, submit) with the ability to open another dialog from within.

```typescript
export const useMyFormDialog = () => {
  const formDialogOpeningDialog = useFormDialogOpeningDialog()
  const { translate } = useInternationalization()
  // ... other hooks (mutations for both form submit AND secondary action)
  const dataRef = useRef<MyData | null>(null)
  const successRef = useRef(false)

  // Mutation for the form submit
  const [updateItem] = useUpdateItemMutation({
    onCompleted: (res) => {
      if (!res.updateItem) return
      successRef.current = true
      dataRef.current?.callback?.(res.updateItem.id)
      addToast({ severity: 'success', message: translate('...') })
    },
  })

  // Mutation for the secondary action (e.g., delete)
  const [deleteItem] = useDeleteItemMutation()

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: { onDynamic: validationSchema },
    onSubmit: async ({ value }) => {
      await updateItem({
        variables: { input: { ...value, id: dataRef.current?.id as string } },
      })
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

  const openMyFormDialog = (data: MyData) => {
    dataRef.current = data
    const isEdition = !!data.existingItem

    form.reset()
    if (data.existingItem) {
      form.setFieldValue('fieldName', data.existingItem.fieldValue || '')
    }

    formDialogOpeningDialog
      .open({
        title: translate(isEdition ? '...' : '...'),
        description: translate('...'),
        children: (
          <div className="...">
            <form.AppField name="fieldName">
              {(field) => <field.TextInputField label={translate('...')} />}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('...')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: MY_FORM_ID,
          submit: handleSubmit,
        },
        // Secondary action button (conditionally shown)
        canOpenDialog: isEdition && !!data.deleteCallback && someCondition,
        openDialogText: translate('...'), // e.g., "Delete integration"
        otherDialogProps: {
          title: translate('...'),
          description: translate('...'),
          colorVariant: 'danger',
          actionText: translate('...'),
          onAction: async () => {
            const result = await deleteItem({
              variables: { input: { id: data.existingItem?.id ?? '' } },
            })

            if (result.data?.deleteItem) {
              data.deleteCallback?.()
              addToast({ severity: 'success', message: translate('...') })
            }
          },
        },
      })
      .then((response) => {
        if (response.reason === 'close' || response.reason === 'open-other-dialog') {
          form.reset()
          dataRef.current = null
        }
      })
  }

  return { openMyFormDialog }
}
```

**Key differences from FormDialog:**

- Uses `useFormDialogOpeningDialog()` instead of `useFormDialog()`
- Adds `canOpenDialog`, `openDialogText`, and `otherDialogProps` to the open call
- `canOpenDialog` controls whether the secondary danger button is visible
- `otherDialogProps` is a `CentralizedDialogProps` object (title, description, actionText, onAction, colorVariant)
- The `.then()` handler should also check for `response.reason === 'open-other-dialog'` for cleanup
- The secondary action's mutation (e.g., delete) is instantiated in the same hook, alongside the form's mutation

**When to use FormDialogOpeningDialog vs FormDialog:**

- Use `FormDialog` when the dialog only has form fields and a submit button
- Use `FormDialogOpeningDialog` when the dialog has form fields AND a secondary action button (typically danger/delete) that should open a confirmation dialog
- The secondary action button appears at the left side of the dialog actions bar (opposite the cancel/submit buttons)

#### Step 2.2: Key Migration Decisions

**Handling `localData` state:**

- Old: `useState` to store data passed via `openDialog`
- New: Use a `useRef` to store data passed to the hook's open function. The ref is captured in closures for `onSubmit` and `children`.

**Handling form initial values when editing:**

- Old: `initialValues` depended on `localData` state, re-rendered on state change
- New: Call `form.reset()` then `form.setFieldValue(...)` before opening the dialog. The form values are set synchronously before `formDialog.open()` is called.

**Handling form submission:**

- Old: `handleSubmit` called `e.preventDefault()` + `form.handleSubmit()`; dialog closed by calling `dialogRef.current?.closeDialog()` inside `onSubmit`
- New: `handleSubmit` returns a `Promise<DialogResult>`. Use a `successRef` to track whether the mutation succeeded. The dialog auto-closes on success (when the promise resolves). Throw an error to keep the dialog open on failure.

**Handling dialog close/cleanup:**

- Old: `onClose` callback reset the form
- New: Use `.then()` on the promise returned by `formDialog.open()`. Check `response.reason === 'close'` to reset form and clear refs.

**Handling component props (like `admins` list):**

- Old: Props passed to the dialog component `<MyDialog admins={admins} />`
- New: Compute derived values (like `isDeletingLastAdmin`) in the parent and pass them as part of the open function data.

#### Step 2.3: Update Imports in the Dialog File

Remove:

```typescript
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { WarningDialog } from '~/components/designSystem/WarningDialog'
```

Add (for FormDialog):

```typescript
import { useRef } from 'react'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
```

Or (for CentralizedDialog):

```typescript
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
```

Or (for FormDialogOpeningDialog):

```typescript
import { useRef } from 'react'
import { useFormDialogOpeningDialog } from '~/components/dialogs/FormDialogOpeningDialog'
import { DialogResult } from '~/components/dialogs/types'
```

#### Step 2.4: Remove Old Exports

Remove:

```typescript
export interface MyDialogRef {
  openDialog: (data: ...) => unknown
  closeDialog: () => unknown
}
export const MyDialog = forwardRef<MyDialogRef>(...)
MyDialog.displayName = 'forwardRef'
```

Replace with:

```typescript
export const useMyDialog = () => { ... }
```

#### Step 2.5: Update Parent Components

**Old usage:**

```typescript
import { MyDialog, MyDialogRef } from './dialogs/MyDialog'

const parentComponent = () => {
  const myDialogRef = useRef<MyDialogRef>(null)

  const handleAction = () => {
    myDialogRef.current?.openDialog({ /* data */ })
  }

  return (
    <>
      {/* ... */}
      <MyDialog ref={myDialogRef} />
    </>
  )
}
```

**New usage:**

```typescript
import { useMyDialog } from './dialogs/MyDialog'

const parentComponent = () => {
  const { openMyDialog } = useMyDialog()

  const handleAction = () => {
    openMyDialog(/* data */)
  }

  return (
    <>
      {/* ... */}
      {/* No need to render MyDialog in JSX anymore */}
    </>
  )
}
```

Key changes in parent:

1. Remove `useRef<MyDialogRef>` import and usage
2. Import the new hook instead of the component + ref type
3. Call the hook's open function directly (no `.current?.openDialog()`)
4. Remove `<MyDialog ref={...} />` from JSX (the dialog is now rendered via NiceModal)
5. Clean up `useRef` import from React if no longer needed

---

### Phase 3: Verification

#### Step 3.1: Type Check

```bash
npx tsc --noEmit
```

#### Step 3.2: Lint

```bash
pnpm lint
```

Ensure there are no TypeScript errors or lint violations before considering the migration complete.

---

## Dialog Type Reference

### DialogResult (discriminated union)

```typescript
type DialogResult =
  | { reason: 'close' }
  | { reason: 'open-other-dialog'; otherDialog: Promise<DialogResult> }
  | { reason: 'success'; params?: unknown }
  | { reason: 'error'; error: Error }
```

### FormDialogProps

```typescript
type FormDialogProps = {
  title: ReactNode
  description?: ReactNode
  headerContent?: ReactNode
  children?: ReactNode
  mainAction?: ReactNode
  cancelOrCloseText?: 'close' | 'cancel'
  closeOnError?: boolean
  onError?: (error: Error) => void
  form: FormProps  // { id: string; submit: (e: React.FormEvent) => void }
}
```

### CentralizedDialogProps

```typescript
type CentralizedDialogProps = {
  title: ReactNode
  description?: ReactNode
  headerContent?: ReactNode
  children?: ReactNode
  onAction: () => DialogResult | Promise<DialogResult> | void | Promise<void>
  actionText: string
  colorVariant?: 'info' | 'danger'
  disableOnContinue?: boolean
  cancelOrCloseText?: 'close' | 'cancel'
  closeOnError?: boolean
  onError?: (error: Error) => void
}
```

### FormDialogOpeningDialogProps

```typescript
type FormDialogOpeningDialogProps = FormDialogProps & {
  canOpenDialog?: boolean         // Controls visibility of the secondary action button
  openDialogText: string          // Label for the secondary action button (e.g., "Delete integration")
  otherDialogProps: CentralizedDialogProps  // Props passed to the CentralizedDialog that opens
}
```

---

## Checklist

### Phase 1: Analysis

- [ ] Read the target dialog file completely
- [ ] Determine dialog type (FormDialog vs CentralizedDialog vs FormDialogOpeningDialog)
- [ ] Find all usages of the dialog (parent components)
- [ ] Identify data passed via `openDialog`
- [ ] Identify any props passed to the dialog component
- [ ] Identify if it's a **deletion dialog** (destroy mutation) - if so, plan the `evictFromCache` migration
- [ ] (FormDialogOpeningDialog) Identify if the dialog has a secondary action button (e.g., delete from edit) that opens another dialog

### Phase 2: Implementation

- [ ] Convert `forwardRef` component to custom hook (`useMyDialog`)
- [ ] Replace `useState(localData)` with `useRef` (for FormDialog/FormDialogOpeningDialog) or function parameter (for CentralizedDialog)
- [ ] Replace `Dialog`/`WarningDialog` with `useFormDialog()`, `useCentralizedDialog()`, or `useFormDialogOpeningDialog()`
- [ ] Implement `handleSubmit` returning `Promise<DialogResult>` (for FormDialog/FormDialogOpeningDialog)
- [ ] Handle form reset and cleanup in `.then()` callback (for FormDialog/FormDialogOpeningDialog)
- [ ] Remove old exports (`forwardRef`, `DialogRef` interface, `displayName`)
- [ ] (Deletion dialog) Replace `refetchQueries` / bare `cache.evict()` with the `evictFromCache` helper
- [ ] Update parent components (replace ref with hook, remove JSX rendering)
- [ ] Move any component props to open function data
- [ ] (FormDialogOpeningDialog) Configure `canOpenDialog`, `openDialogText`, and `otherDialogProps`
- [ ] (FormDialogOpeningDialog) Handle `response.reason === 'open-other-dialog'` in `.then()` for cleanup

### Phase 3: Verification

- [ ] Type check passes (`npx tsc --noEmit`)
- [ ] Lint passes (`pnpm lint`)

## Usage

Invoke this skill with:

```
/migrate-dialog <path-to-dialog>
```

Where `<path-to-dialog>` is the path to the existing imperative ref-based dialog file.

Example:

```
/migrate-dialog src/pages/settings/teamAndSecurity/members/dialogs/RevokeMembershipDialog.tsx
```
