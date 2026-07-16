---
name: extract-section-to-drawer
description: Extract a Formik form section into a TanStack Form drawer with Zod validation, following the plan form migration pattern. Use this skill when the user wants to extract a plan form section (or similar Formik section) into an independent TanStack Form drawer.
user-invocable: true
argument-hint: '<path-to-section-component>'
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, AskUserQuestion
---

# Extract Formik Section to TanStack Drawer Skill

**Target section to extract:** `$ARGUMENTS`

> **Important:** If no path was provided above (empty or missing), use the AskUserQuestion tool to ask the user for the path to the section component they want to extract into a drawer.

This skill extracts a Formik-based form section into an independent TanStack Form inside a ref-based Drawer, bridging data back to the parent Formik form via a callback. Both the existing Formik section and the new drawer coexist during migration.

## Reference Files

Before starting, read these files to understand existing patterns:

### TanStack Form Infrastructure
1. **useAppForm hook**: `src/hooks/forms/useAppForm.ts` — registered field components
2. **Field context**: `src/hooks/forms/formContext.ts` — `useFieldContext` for TanStack fields
3. **Zod validation example**: `src/pages/settings/teamAndSecurity/members/dialogs/CreateInviteDialog.tsx`

### Drawer Pattern
4. **Drawer component**: `src/components/designSystem/Drawer.tsx` — ref-based `DrawerRef` with `openDrawer`/`closeDrawer`

### Existing Implementation (reference)
5. **SubscriptionFeeDrawer**: `src/components/plans/drawers/SubscriptionFeeDrawer.tsx` — first completed extraction
6. **SubscriptionFeeSection**: `src/components/plans/SubscriptionFeeSection.tsx` — section that hosts its drawer internally
7. **PlanFormContext**: `src/contexts/PlanFormContext.tsx` — shared read-only context for currency/interval

### TanStack Field Components
8. **TextInputField**: `src/components/form/TextInput/TextInputFieldForTanstack.tsx`
9. **AmountInputField**: `src/components/form/AmountInput/AmountInputFieldForTanstack.tsx`
10. **SwitchField**: `src/components/form/Switch/SwitchFieldForTanstack.tsx`
11. **RadioGroupField**: `src/components/form/Radio/RadioGroupFieldForTanstack.tsx`

## Migration Steps

### Phase 1: Analyze the Section

1. Read the target section component completely
2. Identify:
   - All form fields and their Formik names/types
   - Which fields are editable vs read-only/disabled
   - Any shared context needed (currency, interval, etc.)
   - The parent component(s) that render this section

### Phase 2: Define the Form Values Type

Create an interface for the drawer's form values. The field names **must match** the Formik field names exactly so the parent can spread them back with `setValues`:

```ts
interface SectionNameFormValues {
  fieldA: string
  fieldB: boolean
  fieldC: number | null
}
```

**Critical rule:** The keys in this type must be a subset of the parent Formik form's type (`PlanFormInput` or equivalent). This enables the spread pattern:

```ts
formikProps.setValues({ ...formikProps.values, ...drawerValues })
```

### Phase 3: Create the Zod Schema

Define a Zod schema that validates exactly the form values shape:

```ts
const sectionNameSchema = z.object({
  fieldA: z.string().min(1, 'text_translationKeyForError'),
  fieldB: z.boolean(),
  fieldC: z.number().positive().nullable(),
})
```

**Important:**
- Use `z.enum(MyEnum)` for GraphQL/TS string enums. `z.nativeEnum()` is deprecated in Zod v4.
- Pass **translation keys** (not translated strings) as Zod error messages. The TanStack field components translate them via `useInternationalization`.

### Phase 4: Create the Drawer Component

Create the drawer file at `src/components/plans/drawers/SectionNameDrawer.tsx` following this structure:

```tsx
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle, useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
// ... other imports

export interface SectionNameFormValues { /* ... */ }

const sectionNameSchema = z.object({ /* ... */ })

const DEFAULT_VALUES: SectionNameFormValues = { /* ... */ }

const SECTION_NAME_FORM_ID = 'section-name-drawer-form'

export interface SectionNameDrawerRef {
  openDrawer: (values: SectionNameFormValues) => void
  closeDrawer: () => void
}

interface SectionNameDrawerProps {
  onSave: (values: SectionNameFormValues) => void
}

export const SectionNameDrawer = forwardRef<SectionNameDrawerRef, SectionNameDrawerProps>(
  ({ onSave }, ref) => {
    const drawerRef = useRef<DrawerRef>(null)

    const form = useAppForm({
      defaultValues: DEFAULT_VALUES,
      validationLogic: revalidateLogic(),
      validators: { onDynamic: sectionNameSchema },
      onSubmit: async ({ value }) => {
        onSave(value)
        drawerRef.current?.closeDrawer()
      },
    })

    useImperativeHandle(ref, () => ({
      openDrawer: (values) => {
        // keepDefaultValues: true prevents the React adapter's formApi.update()
        // from overwriting values — it compares opts.defaultValues against
        // this.options.defaultValues, and since we keep DEFAULT_VALUES as both,
        // they match and no overwrite occurs. isDirty starts as false because
        // reset() clears all field meta.
        form.reset(values, { keepDefaultValues: true })
        drawerRef.current?.openDrawer()
      },
      closeDrawer: () => drawerRef.current?.closeDrawer(),
    }))

    // IMPORTANT: subscribe to isDirty via useStore — reading form.state.isDirty
    // directly is a passive read that does NOT trigger re-renders.
    const isDirty = useStore(form.store, (state) => state.isDirty)

    const handleFormSubmit = (event: React.FormEvent) => {
      event.preventDefault()
      form.handleSubmit()
    }

    return (
      <Drawer
        ref={drawerRef}
        title="..."
        showCloseWarningDialog={isDirty}
        onClose={() => form.reset()}
        stickyBottomBar={({ closeDrawer }) => (
          <div className="flex justify-end gap-3">
            <Button variant="quaternary" onClick={closeDrawer}>Cancel</Button>
            {/* form.SubmitButton uses type="submit" which requires being inside <form>.
                In drawers, stickyBottomBar is outside <form> in the DOM, so use
                form.Subscribe + programmatic form.handleSubmit() instead. */}
            <form.Subscribe selector={(state) => ({ canSubmit: state.canSubmit })}>
              {({ canSubmit }) => (
                <Button disabled={!canSubmit} onClick={() => form.handleSubmit()}>
                  Save
                </Button>
              )}
            </form.Subscribe>
          </div>
        )}
      >
        <form id={SECTION_NAME_FORM_ID} onSubmit={handleFormSubmit}>
          {/* Hidden submit button enables Enter-key submission.
              The visible SubmitButton is in stickyBottomBar, outside the <form> in the DOM. */}
          <button type="submit" hidden aria-hidden="true" />
          {/* form.AppField for each field */}
        </form>
      </Drawer>
    )
  },
)
```

### Key patterns:

- **`<form>` wrapper**: Always wrap drawer content in a `<form>` element with an id and `onSubmit` handler. Add a `<button type="submit" hidden aria-hidden="true" />` inside the form — the visible `SubmitButton` is in `stickyBottomBar` (outside `<form>` in the DOM), so the hidden button is needed for Enter-key submission to work.
- **`onSubmit` on useAppForm**: The save logic lives in the form's `onSubmit` config, not in a manual handler. This ensures Zod validation runs via `form.handleSubmit()` before saving.
- **Programmatic submit in drawers**: `form.SubmitButton` uses `type="submit"` which only works inside a `<form>` element. In drawers, the `stickyBottomBar` is rendered outside the `<form>` in the DOM, so use `form.Subscribe` + `form.handleSubmit()` instead: `<form.Subscribe selector={(state) => ({ canSubmit: state.canSubmit })}>{({ canSubmit }) => (<Button disabled={!canSubmit} onClick={() => form.handleSubmit()}>Save</Button>)}</form.Subscribe>`. This gives you the same `canSubmit` gating as `SubmitButton` with programmatic submission.
- **`reset(values, { keepDefaultValues: true })`**: On `openDrawer`, reset the form to the provided values while keeping `DEFAULT_VALUES` as the internal defaultValues. This prevents the React adapter's `formApi.update()` from overwriting values on re-render, without needing a `useState` workaround.
- **Enhanced ref**: `openDrawer(values)` accepts initial values from Formik, not just `openDrawer()`
- **Dirty detection**: Subscribe via `useStore(form.store, (state) => state.isDirty)` — reading `form.state.isDirty` directly is a passive read that does NOT trigger re-renders.
- **onSave callback**: Does NOT write to Formik directly — the parent handles that via the callback
- **Form reset on close**: `onClose={() => form.reset()}` cleans up when drawer closes

### Phase 5: Integrate into the Section Component

The drawer lives **inside** the section component, not at the page level:

1. Add a `useRef<SectionNameDrawerRef>` inside the section component
2. Add an `onDrawerSave` prop (required, not optional) to the section's props interface
3. Add a trigger element (e.g., `Selector` component) that calls `drawerRef.current?.openDrawer(currentValues)`
4. Render `<SectionNameDrawer ref={drawerRef} onSave={onDrawerSave} />` inside the section

```tsx
interface SectionProps {
  formikProps: FormikProps<PlanFormInput>
  onDrawerSave: (values: SectionNameFormValues) => void
  // ... other existing props
}
```

#### Single Drawer Instance for List/Loop Sections

**Critical rule for sections that render items in a loop** (e.g., fixed charges, usage charges, where each charge is an accordion item):

The drawer must be rendered **once** at the section level, NOT inside each loop item. Only the **drawerRef** is passed down to each item as a prop. This prevents N drawer instances in the DOM (one per item).

```tsx
// ✅ Correct: ONE drawer at the section level, ref passed to items
const ChargesSection = ({ formikProps, onDrawerSave }: ChargesSectionProps) => {
  const drawerRef = useRef<ChargeDrawerRef>(null)

  return (
    <>
      {formikProps.values.charges.map((charge, index) => (
        <ChargeAccordionItem
          key={charge.id}
          charge={charge}
          drawerRef={drawerRef}  // ← pass only the ref
        />
      ))}
      <ChargeDrawer ref={drawerRef} onSave={onDrawerSave} />
    </>
  )
}

// Each item calls drawerRef.current?.openDrawer(itsValues)
const ChargeAccordionItem = ({ charge, drawerRef }: ChargeAccordionItemProps) => {
  return (
    <Selector
      onClick={() => drawerRef.current?.openDrawer(charge)}
      // ...
    />
  )
}
```

```tsx
// ❌ Wrong: drawer rendered inside each loop item = N drawers in DOM
{formikProps.values.charges.map((charge, index) => (
  <ChargeAccordionItem key={charge.id} charge={charge}>
    <ChargeDrawer onSave={onDrawerSave} />  {/* duplicated per item! */}
  </ChargeAccordionItem>
))}
```

### Phase 6: Wire Up the Parent Page

In the parent page (e.g., `CreatePlan.tsx`, `CreateSubscription.tsx`):

1. Pass `onDrawerSave` using the spread pattern:

```tsx
<SectionComponent
  formikProps={formikProps}
  onDrawerSave={(values) => {
    formikProps.setValues({ ...formikProps.values, ...values })
  }}
/>
```

2. Ensure `PlanFormProvider` wraps the section (provides currency/interval to the drawer):

```tsx
<PlanFormProvider
  currency={formikProps.values.amountCurrency || CurrencyEnum.Usd}
  interval={formikProps.values.interval || PlanInterval.Monthly}
>
  {/* ... section components ... */}
</PlanFormProvider>
```

### Phase 7: Check for Missing TanStack Field Components

If the section uses a Formik field component that doesn't have a TanStack equivalent yet:

1. Check `src/hooks/forms/useAppForm.ts` for the `fieldComponents` map
2. If missing, create a `*ForTanstack.tsx` file following the pattern of existing ones (e.g., `SwitchFieldForTanstack.tsx`)
3. Register it in `useAppForm.ts`

The TanStack field pattern:
```tsx
const FieldName = (props: Omit<OriginalProps, 'name' | 'value' | 'onChange'>) => {
  const field = useFieldContext<FieldType>()
  return (
    <OriginalComponent
      {...props}
      name={field.name}
      value={field.state.value}
      onChange={(value) => field.handleChange(value)}
    />
  )
}
```

### Phase 8: Add Translation Keys

**Never manually create translation keys.** Always use the script to generate properly formatted keys:

```bash
pnpm translations:add <count>
```

This generates `<count>` keys with the format `text_<timestamp><random>` and appends them with empty values to `translations/base.json`. Then fill in the values for each generated key.

For example, if you need 2 new strings ("Pricing settings" and "Open drawer"):
1. Run `pnpm translations:add 2`
2. Find the new empty keys at the bottom of `translations/base.json`
3. Fill in the values: `"text_1771963033466...": "Pricing settings"`
4. Use the generated keys in code: `translate('text_1771963033466...')`

## Verification Checklist

After completing the extraction:

1. **TypeScript**: Run `pnpm tsc --noEmit` — zero errors
2. **Lint**: Run `pnpm eslint` on changed files — zero new errors
3. **Existing section**: The original Formik-based accordion/section still works unchanged
4. **Drawer trigger**: Clicking the trigger opens the drawer with current Formik values pre-filled
5. **Field rendering**: All TanStack fields render correctly with proper labels and validation
6. **Save flow**: Saving copies values back to Formik (verify in the existing section's display)
7. **Dirty detection**: Closing the drawer with unsaved changes shows a warning dialog
8. **All parent pages**: Every page that renders the section passes `onDrawerSave` and is wrapped with `PlanFormProvider`

## Common Pitfalls

- **Missing `<form>` wrapper**: Always wrap drawer content in a `<form>` element. Without it, `form.handleSubmit()` won't trigger the validation → submit lifecycle, and Zod validation is never enforced.
- **Manual value reading instead of `form.handleSubmit()`**: Never read `form.state.values` directly and pass to `onSave`. Always use `form.handleSubmit()` which runs validation first, then calls the `onSubmit` handler only if valid.
- **`useState` for defaultValues**: Don't use `useState` to track defaultValues. Use `form.reset(values, { keepDefaultValues: true })` instead — this prevents the React adapter's `formApi.update()` from overwriting values while keeping `isDirty` correct.
- **`z.nativeEnum()` usage**: Deprecated in Zod v4. Use `z.enum(MyEnum)` for GraphQL/TS string enums.
- **Optional `onDrawerSave`**: Keep it required. If a parent doesn't need the drawer, it still passes a handler. This avoids conditional rendering bugs.
- **Field name mismatch**: The drawer's form values type keys MUST match Formik field names exactly for the spread pattern to work.
- **Missing PlanFormProvider**: The drawer uses `usePlanFormContext()` for currency/interval. Every parent that renders the section must be wrapped.
- **Import path**: `useAppForm` is imported from `~/hooks/forms/useAppform` (lowercase 'f').
- **Revalidation logic**: Always pass `validationLogic: revalidateLogic()` from `@tanstack/react-form`.
- **Drawer in a loop**: When the section renders items in a loop (charges, thresholds, etc.), render the drawer **once** at the section level and pass the `drawerRef` to each item. Never render a drawer inside each loop iteration.
- **Manual translation keys**: Never hand-craft translation keys. Always run `pnpm translations:add <count>` to generate them with the correct format.
- **TanStack field error handling**: Ensure all TanStack field wrappers (`*ForTanstack.tsx`) wire up error state via `useStore(field.store, (state) => state.meta.errors)` and `getErrorToDisplay()`. If the underlying component accepts an `error` prop, it must be connected.
