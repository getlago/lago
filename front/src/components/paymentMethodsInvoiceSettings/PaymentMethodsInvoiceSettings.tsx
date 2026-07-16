import { InvoiceCustomSectionSettings } from './InvoiceCustomSectionSettings'
import { PaymentMethodSettings } from './PaymentMethodSettings'
import { SettingsComponentProps, ViewTypeEnum } from './types'

// Thin composite of the two single-purpose settings components. Each child owns
// its own customer guard (externalId for payment method, id for custom section)
// and form-field adapter, so the rendered output is identical to inlining both.
// Consumers that need only one half should use the single-purpose component directly.
export const PaymentMethodsInvoiceSettings = <T extends ViewTypeEnum>(
  props: SettingsComponentProps<T>,
) => (
  <>
    <PaymentMethodSettings {...props} />
    <InvoiceCustomSectionSettings {...props} />
  </>
)
