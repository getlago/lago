import { InvoiceCustomSection } from '~/generated/graphql'

export type InvoiceCustomSectionBasic = Pick<InvoiceCustomSection, 'id' | 'name'>

// The three ways a billing object can resolve its invoice custom sections.
// Lives here (not in a component) so both the inline fields and the dialog
// shell can import it without a circular dependency.
export enum InvoiceCustomSectionBehavior {
  FALLBACK = 'fallback',
  APPLY = 'apply',
  NONE = 'none',
}

/**
 * Represents the input structure for invoice custom sections.
 * This type is reusable across different contexts (subscriptions, one-off invoices, etc.)
 */
export interface InvoiceCustomSectionInput {
  invoiceCustomSections: InvoiceCustomSectionBasic[]
  skipInvoiceCustomSections: boolean
}

// Behavior cannot be fully derived from the value alone (an empty "apply"
// selection is indistinguishable from "fallback"), so callers that must tell
// them apart track behavior separately. This resolves the unambiguous cases.
export const deriveInvoiceCustomSectionBehavior = (
  value?: InvoiceCustomSectionInput | null,
): InvoiceCustomSectionBehavior => {
  if (value?.skipInvoiceCustomSections) return InvoiceCustomSectionBehavior.NONE
  if (value?.invoiceCustomSections?.length) return InvoiceCustomSectionBehavior.APPLY

  return InvoiceCustomSectionBehavior.FALLBACK
}
