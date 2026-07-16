import { InvoceCustomFooter } from '~/components/invoceCustomFooter/InvoceCustomFooter'
import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { getFieldPath, getFieldValue } from '~/core/form/fieldPathUtils'

import { SettingsComponentProps, ViewTypeEnum } from './types'

// Standalone invoice custom-section settings: renders only when the customer has
// an id. Owns the `invoiceCustomSection` form field via the optional
// `formFieldBasePath` adapter.
export const InvoiceCustomSectionSettings = <T extends ViewTypeEnum>({
  customer,
  form,
  viewType,
  formFieldBasePath,
}: SettingsComponentProps<T>) => {
  const id = customer?.id

  if (!id) return null

  return (
    <InvoceCustomFooter
      customerId={id}
      viewType={viewType}
      invoiceCustomSection={
        getFieldValue<InvoiceCustomSectionInput>(
          'invoiceCustomSection',
          form.values,
          formFieldBasePath,
        ) ?? undefined
      }
      setInvoiceCustomSection={(item) => {
        form.setFieldValue(getFieldPath('invoiceCustomSection', formFieldBasePath), item)
      }}
    />
  )
}
