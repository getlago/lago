# Advanced Patterns: Complex Forms

This document shows patterns from `CreateCustomer`, a complex form with sub-components, mappers, and advanced validation.

## Reference Files

- Main form: `src/pages/createCustomers/CreateCustomer.tsx`
- Validation: `src/pages/createCustomers/formInitialization/validationSchema.ts`
- Sub-component: `src/pages/createCustomers/customerInformation/CustomerInformation.tsx`
- Coupon form (medium complexity): `src/pages/CreateCoupon.tsx`
- Dialog with form: `src/pages/createCoupon/dialogs/AddBillableMetricToCouponDialog.tsx`
- Reusable field group: `src/components/form/NameAndCodeGroup/NameAndCodeGroup.tsx`

---

## Pattern 1: Complex Zod Schema with Refinements

**File: `validationSchema.ts`**

```typescript
import { z } from 'zod'
import { CountryCode, CurrencyEnum, TimezoneEnum } from '~/generated/graphql'

// Reusable nested schema
const addressSchema = z.object({
  addressLine1: z.string().optional(),
  addressLine2: z.string().optional(),
  city: z.string().optional(),
  zipcode: z.string().optional(),
  state: z.string().optional(),
  country: z.nativeEnum(CountryCode).optional(),
})

// Main schema with refinements
export const createCustomerValidationSchema = z
  .object({
    // Required fields
    name: z.string().min(1, 'Name is required'),
    externalId: z.string().min(1, 'External ID is required'),

    // Optional fields with enums
    currency: z.nativeEnum(CurrencyEnum).optional(),
    timezone: z.nativeEnum(TimezoneEnum).optional(),

    // Nested objects
    billingConfiguration: z.object({
      documentLocale: z.string().optional(),
      invoiceGracePeriod: z.number().optional(),
    }),

    // Reuse address schema
    shippingAddress: addressSchema,

    // Array of nested objects
    metadata: z.array(
      z.object({
        key: z.string(),
        value: z.string(),
        displayInInvoice: z.boolean(),
      })
    ),
  })
  .refine(
    (data) => {
      // Cross-field validation example
      if (data.billingConfiguration.invoiceGracePeriod !== undefined) {
        return data.billingConfiguration.invoiceGracePeriod >= 0
      }
      return true
    },
    {
      message: 'Grace period must be positive',
      path: ['billingConfiguration', 'invoiceGracePeriod'],
    }
  )

// Export type for form values
export type CreateCustomerFormValues = z.infer<typeof createCustomerValidationSchema>

// Export empty defaults for typing and initial state
export const emptyCreateCustomerDefaultValues: CreateCustomerFormValues = {
  name: '',
  externalId: '',
  currency: undefined,
  timezone: undefined,
  billingConfiguration: {
    documentLocale: undefined,
    invoiceGracePeriod: undefined,
  },
  shippingAddress: {
    addressLine1: undefined,
    addressLine2: undefined,
    city: undefined,
    zipcode: undefined,
    state: undefined,
    country: undefined,
  },
  metadata: [],
}
```

---

## Pattern 2: Mappers for API ↔ Form

**File: `mappers.ts`**

```typescript
import type { CustomerDetailsFragment, CreateCustomerInput } from '~/generated/graphql'
import type { CreateCustomerFormValues } from './validationSchema'

/**
 * Transform API response to form values
 */
export const mapFromApiToForm = (
  customer: CustomerDetailsFragment
): CreateCustomerFormValues => ({
  name: customer.name || '',
  externalId: customer.externalId || '',
  currency: customer.currency || undefined,
  timezone: customer.timezone || undefined,
  billingConfiguration: {
    documentLocale: customer.billingConfiguration?.documentLocale || undefined,
    invoiceGracePeriod: customer.billingConfiguration?.invoiceGracePeriod ?? undefined,
  },
  shippingAddress: {
    addressLine1: customer.shippingAddress?.addressLine1 || undefined,
    addressLine2: customer.shippingAddress?.addressLine2 || undefined,
    city: customer.shippingAddress?.city || undefined,
    zipcode: customer.shippingAddress?.zipcode || undefined,
    state: customer.shippingAddress?.state || undefined,
    country: customer.shippingAddress?.country || undefined,
  },
  metadata: (customer.metadata || []).map((m) => ({
    key: m.key,
    value: m.value,
    displayInInvoice: m.displayInInvoice,
  })),
})

/**
 * Transform form values to API input
 */
export const mapFromFormToApi = (
  values: CreateCustomerFormValues
): CreateCustomerInput => ({
  name: values.name,
  externalId: values.externalId,
  currency: values.currency || null,
  timezone: values.timezone || null,
  billingConfiguration: {
    documentLocale: values.billingConfiguration.documentLocale || null,
    invoiceGracePeriod: values.billingConfiguration.invoiceGracePeriod ?? null,
  },
  shippingAddress: values.shippingAddress.addressLine1
    ? {
        addressLine1: values.shippingAddress.addressLine1,
        addressLine2: values.shippingAddress.addressLine2 || null,
        city: values.shippingAddress.city || null,
        zipcode: values.shippingAddress.zipcode || null,
        state: values.shippingAddress.state || null,
        country: values.shippingAddress.country || null,
      }
    : null,
  metadata: values.metadata.map((m) => ({
    key: m.key,
    value: m.value,
    displayInInvoice: m.displayInInvoice,
  })),
})
```

---

## Pattern 3: withForm HOC for Sub-Components

**File: `CustomerInformation.tsx`**

```typescript
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '../formInitialization/validationSchema'

// 1. Define props interface
interface CustomerInformationProps {
  isEdition: boolean
  customer?: CustomerDetailsFragment
  isDisabled?: boolean
}

// 2. Default props (required for withForm)
const defaultProps: CustomerInformationProps = {
  isEdition: false,
}

// 3. Create component with withForm HOC
const CustomerInformation = withForm({
  // Pass default values for typing
  defaultValues: emptyCreateCustomerDefaultValues,
  // Pass default props
  props: defaultProps,
  // Render function receives form and all props
  render: function Render({ form, isEdition, customer, isDisabled }) {
    const { translate } = useInternationalization()

    return (
      <Card>
        <Typography variant="subhead">
          {translate('text_customer_information')}
        </Typography>

        {/* Fields use the form instance passed by parent */}
        <form.AppField name="name">
          {(field) => (
            <field.TextInputField
              label={translate('text_name')}
              disabled={isDisabled}
            />
          )}
        </form.AppField>

        <form.AppField name="externalId">
          {(field) => (
            <field.TextInputField
              label={translate('text_external_id')}
              disabled={isEdition || isDisabled}
            />
          )}
        </form.AppField>

        {/* Access nested fields with dot notation */}
        <form.AppField name="billingConfiguration.documentLocale">
          {(field) => (
            <field.ComboBoxField
              label={translate('text_locale')}
              options={localeOptions}
            />
          )}
        </form.AppField>
      </Card>
    )
  },
})

export default CustomerInformation
```

**Usage in parent form:**

```tsx
// In CreateCustomer.tsx
<CustomerInformation
  form={form}
  isEdition={isEdition}
  customer={customer}
  isDisabled={loading}
/>
```

---

## Pattern 4: Main Form with Sub-Components

**File: `CreateCustomer.tsx`**

```typescript
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useAppForm } from '~/hooks/forms/useAppform'

import { createCustomerValidationSchema, emptyCreateCustomerDefaultValues } from './formInitialization/validationSchema'
import { mapFromApiToForm, mapFromFormToApi } from './formInitialization/mappers'
import CustomerInformation from './customerInformation/CustomerInformation'
import BillingConfiguration from './billingConfiguration/BillingConfiguration'
import MetadataSection from './metadataSection/MetadataSection'

const CreateCustomer: FC = () => {
  const { customerId } = useParams()
  const isEdition = !!customerId

  // Fetch existing customer for edit mode
  const { data: customerData, loading } = useGetCustomerForEditQuery({
    variables: { id: customerId || '' },
    skip: !customerId,
  })
  const customer = customerData?.customer

  // Initialize form with mappers
  const form = useAppForm({
    defaultValues: customer
      ? mapFromApiToForm(customer)
      : emptyCreateCustomerDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: createCustomerValidationSchema,
    },
    // Handle invalid submit (scroll to error)
    onSubmitInvalid: ({ formApi }) => {
      const firstErrorField = Object.keys(formApi.state.fieldMeta).find(
        (key) => formApi.state.fieldMeta[key]?.errors?.length > 0
      )
      if (firstErrorField) {
        document
          .querySelector(`[name="${firstErrorField}"]`)
          ?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    },
    onSubmit: async ({ value, formApi }) => {
      try {
        const input = mapFromFormToApi(value)

        if (isEdition) {
          await updateCustomer({ variables: { id: customerId, input } })
        } else {
          await createCustomer({ variables: { input } })
        }

        addToast({ severity: 'success', message: translate('text_success') })
        navigate('/customers')
      } catch (error) {
        if (error instanceof ApolloError) {
          // Handle server-side validation errors
          const lagoErrors = error.graphQLErrors[0]?.extensions?.lagoCode

          if (lagoErrors?.includes('value_already_exists')) {
            formApi.setErrorMap({
              onSubmit: {
                fields: {
                  externalId: translate('text_external_id_already_exists'),
                },
              },
            })
          }
        }
      }
    },
  })

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    form.handleSubmit()
  }

  return (
    <form onSubmit={handleSubmit}>
      <PageHeader>
        <Typography variant="headline">
          {translate(isEdition ? 'text_edit_customer' : 'text_create_customer')}
        </Typography>
      </PageHeader>

      <PageContent>
        {/* Sub-components receive the form instance */}
        <CustomerInformation
          form={form}
          isEdition={isEdition}
          customer={customer}
          isDisabled={loading}
        />

        <BillingConfiguration
          form={form}
          isDisabled={loading}
        />

        <MetadataSection
          form={form}
        />
      </PageContent>

      <PageFooter>
        <Button variant="quaternary" onClick={() => navigate(-1)}>
          {translate('text_cancel')}
        </Button>
        <form.AppForm>
          <form.SubmitButton disabled={loading}>
            {translate(isEdition ? 'text_update' : 'text_create')}
          </form.SubmitButton>
        </form.AppForm>
      </PageFooter>
    </form>
  )
}
```

---

## Pattern 5: Array Fields with Add/Remove

```typescript
// In MetadataSection.tsx
const MetadataSection = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: {},
  render: function Render({ form }) {
    // Subscribe to array value
    const metadata = useStore(form.store, (state) => state.values.metadata)

    const handleAddMetadata = () => {
      form.setFieldValue('metadata', [
        ...metadata,
        { key: '', value: '', displayInInvoice: false },
      ])
    }

    const handleRemoveMetadata = (index: number) => {
      form.setFieldValue(
        'metadata',
        metadata.filter((_, i) => i !== index)
      )
    }

    return (
      <Card>
        <Typography variant="subhead">Metadata</Typography>

        {metadata.map((_, index) => (
          <div key={index} className="flex gap-4">
            <form.AppField name={`metadata[${index}].key`}>
              {(field) => <field.TextInputField label="Key" />}
            </form.AppField>

            <form.AppField name={`metadata[${index}].value`}>
              {(field) => <field.TextInputField label="Value" />}
            </form.AppField>

            <form.AppField name={`metadata[${index}].displayInInvoice`}>
              {(field) => <field.CheckboxField label="Show in invoice" />}
            </form.AppField>

            <Button variant="quaternary" onClick={() => handleRemoveMetadata(index)}>
              Remove
            </Button>
          </div>
        ))}

        <Button onClick={handleAddMetadata}>Add metadata</Button>
      </Card>
    )
  },
})
```

---

---

## Pattern 6: Field Listeners for Side-Effects

Use `listeners` on `form.AppField` to react to value changes. Preferred over `useStore` + `useEffect`:

**File: `AddBillableMetricToCouponDialog.tsx`**

```tsx
// Propagate combobox selection to parent via callback
<form.AppField
  name="selectedBillableMetric"
  listeners={{
    onChange: ({ value }) => {
      const billableMetric = data?.billableMetrics?.collection.find((b) => b.id === value)
      onSelect(value ? billableMetric : undefined)
    },
  }}
>
  {(field) => (
    <field.ComboBoxField
      data={comboboxBillableMetricsData}
      label={translate('text_select_billable_metric')}
      loading={loading}
      PopperProps={{ displayInDialog: true }}
      searchQuery={getBillableMetrics}
    />
  )}
</form.AppField>
```

**File: `NameAndCodeGroup.tsx`** — Auto-generate code from name:

```tsx
const handleNameChange = ({ value }: { value: string }) => {
  const isCodeBlurred = group.getFieldMeta('code')?.isBlurred
  if (isCodeBlurred || isDisabled) return
  group.setFieldValue('code', formatCodeFromName(value))
}

<group.AppField name="name" listeners={{ onChange: handleNameChange }}>
  {(field) => <field.TextInputField label={translate('text_name')} />}
</group.AppField>
```

**When to use:**

| Use case | Tool |
|----------|------|
| Read value for conditional rendering | `useStore(form.store, ...)` |
| Side-effect on value change | `listeners={{ onChange }}` |
| Derive another field's value | `listeners={{ onChange }}` |

---

## Pattern 7: `withFieldGroup` for Reusable Field Groups

Different from `withForm` — use `withFieldGroup` for groups of fields reusable across multiple forms:

**File: `NameAndCodeGroup.tsx`**

```tsx
import { formatCodeFromName } from '~/core/utils/formatCodeFromName'
import { withFieldGroup } from '~/hooks/forms/useAppform'

export type NameAndCodeGroupValues = {
  code: string
  name: string
}

export type NameAndCodeGroupProps = {
  isDisabled?: boolean
}

const defaultValues: NameAndCodeGroupValues = { code: '', name: '' }
const defaultProps: NameAndCodeGroupProps = { isDisabled: false }

const NameAndCodeGroup = withFieldGroup({
  defaultValues,
  props: defaultProps,
  render: function Render({ group, isDisabled }) {
    const { translate } = useInternationalization()

    const handleNameChange = ({ value }: { value: string }) => {
      const isCodeBlurred = group.getFieldMeta('code')?.isBlurred
      if (isCodeBlurred || isDisabled) return
      group.setFieldValue('code', formatCodeFromName(value))
    }

    return (
      <div className="grid grid-cols-2 gap-6">
        <group.AppField name="name" listeners={{ onChange: handleNameChange }}>
          {(field) => <field.TextInputField label={translate('text_name')} />}
        </group.AppField>
        <group.AppField name="code">
          {(field) => (
            <field.TextInputField
              label={translate('text_code')}
              beforeChangeFormatter="code"
              disabled={isDisabled}
            />
          )}
        </group.AppField>
      </div>
    )
  },
})

export default NameAndCodeGroup
```

**Usage in parent form:**
```tsx
import NameAndCodeGroup from '~/components/form/NameAndCodeGroup/NameAndCodeGroup'

<NameAndCodeGroup group={form} isDisabled={isEdition} />
```

**Key differences: `withForm` vs `withFieldGroup`:**

| Aspect | `withForm` | `withFieldGroup` |
|--------|-----------|-----------------|
| Purpose | Sub-component of a specific form | Reusable field group across forms |
| Receives | `form` prop | `group` prop |
| Usage | `<Section form={form} />` | `<NameAndCodeGroup group={form} />` |
| Scope | Specific to one form | Generic, any form with matching fields |

---

## Pattern 8: Dialog with Independent Form

When a dialog needs a form (e.g., selecting an item), use a separate `useAppForm` inside the dialog. Communicate with the parent via callbacks:

**File: `AddBillableMetricToCouponDialog.tsx`**

```tsx
// Dialog content component — has its own independent form
const AddBillableMetricContent = ({ attachedBillableMetricsIds, onSelect }: Props) => {
  const [getBillableMetrics, { loading, data }] = useGetBillableMetricsForCouponsLazyQuery({
    variables: { limit: 50 },
  })

  // Independent form — NOT the parent form
  const form = useAppForm({
    defaultValues: { selectedBillableMetric: '' },
  })

  useEffect(() => { getBillableMetrics() }, [getBillableMetrics])

  return (
    <div className="p-8">
      <form.AppField
        name="selectedBillableMetric"
        listeners={{
          onChange: ({ value }) => {
            const bm = data?.billableMetrics?.collection.find((b) => b.id === value)
            onSelect(value ? bm : undefined)
          },
        }}
      >
        {(field) => (
          <field.ComboBoxField
            data={comboboxData}
            label="Select billable metric"
            loading={loading}
            PopperProps={{ displayInDialog: true }}
            searchQuery={getBillableMetrics}
          />
        )}
      </form.AppField>
    </div>
  )
}

// Hook to open the dialog
export const useAddBillableMetricToCouponDialog = () => {
  const formDialog = useFormDialog()
  const selectedRef = useRef<BillableMetricsForCouponsFragment | undefined>()
  const setDisabledRef = useSetDisabledRef()

  const open = ({ onSubmit, attachedBillableMetricsIds }: Params) => {
    selectedRef.current = undefined

    formDialog.open({
      title: 'Add billable metric',
      description: 'Select a billable metric to attach',
      children: (
        <AddBillableMetricContent
          attachedBillableMetricsIds={attachedBillableMetricsIds}
          onSelect={(bm) => {
            selectedRef.current = bm
            setDisabledRef.current(!bm)
          }}
        />
      ),
      mainAction: <DialogActionButton label="Add" setDisabledRef={setDisabledRef} />,
      form: {
        id: 'add-billable-metric-form',
        submit: () => {
          if (!selectedRef.current) throw new Error('No item selected')
          onSubmit(selectedRef.current)
        },
      },
    })
  }

  return { open }
}
```

**Key points:**
- Dialog has its own `useAppForm`, fully independent from the parent form
- Data flows to parent via callback (`onSelect`) + `useRef`
- `useFormDialog` + `DialogActionButton` + `useSetDisabledRef` handle dialog UX
- The `form.id` in dialog config links the submit button to the form element

---

## Pattern 9: Derive State Instead of Storing Flags

Prefer deriving boolean state from form values rather than storing separate flags:

```tsx
// AVOID: separate boolean flag
const form = useAppForm({
  defaultValues: {
    hasLimitPlans: false,       // redundant flag
    limitPlansList: [],
  },
})

// PREFER: derive from array length
const limitPlansList = useStore(form.store, (state) => state.values.limitPlansList)
const hasLimitPlans = limitPlansList.length > 0
```

---

## Pattern 10: `<form>` Wrapper CSS Impact

The `<form>` element (required by TanStack) adds a new DOM node. This can break layouts:

```tsx
// Often needed to preserve sticky footer and flex layout:
<form className="flex min-h-full flex-col" onSubmit={handleSubmit}>
  <CenteredPage.Header>{/* ... */}</CenteredPage.Header>
  <CenteredPage.Container>{/* ... */}</CenteredPage.Container>
  <CenteredPage.StickyFooter>{/* ... */}</CenteredPage.StickyFooter>
</form>
```

Common issues:
- Sticky footer height changes → add `flex min-h-full flex-col`
- Datepicker/popover misalignment → check positioned ancestor chain
- Error message spacing shifts → verify margin collapse behavior
- Flex children sizing changes → ensure form fills available space

**Always compare the rendered UI before and after migration.**

---

## Key Differences: Simple vs Complex Forms

| Aspect | Simple Form | Complex Form |
|--------|-------------|--------------|
| Structure | Single file | Multiple sub-components |
| Validation | Flat schema | Nested schemas with `.refine()` |
| Data flow | Direct values | Mappers (API ↔ Form) |
| Sub-components | N/A | `withForm` HOC |
| Reusable field groups | N/A | `withFieldGroup` HOC |
| Side-effects on change | N/A | `listeners={{ onChange }}` |
| Dialogs with forms | N/A | Independent `useAppForm` + callback |
| Error handling | Toast only | `formApi.setErrorMap` + toast |
| Invalid submit | N/A | `onSubmitInvalid` + scroll |
| Default values | Inline | Exported from schema |
| Loading state | N/A or custom | `FormLoadingSkeleton` |
