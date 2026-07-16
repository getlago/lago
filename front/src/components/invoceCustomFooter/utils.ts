import { InvoiceCustomSectionsReferenceInput } from '~/generated/graphql'

import { InvoiceCustomSectionInput } from './types'

/**
 * Converts InvoiceCustomSectionInput (with names) to InvoiceCustomSectionsReferenceInput (IDs only) for GraphQL
 */
export const toInvoiceCustomSectionReference = (
  input?: InvoiceCustomSectionInput | null,
): InvoiceCustomSectionsReferenceInput | undefined => {
  if (!input) return undefined

  return {
    invoiceCustomSectionIds: input.invoiceCustomSections?.map((s) => s.id) || [],
    skipInvoiceCustomSections: input.skipInvoiceCustomSections,
  }
}
