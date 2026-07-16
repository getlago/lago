import { InvoiceCustomSection } from '~/generated/graphql'

interface CreateInvoiceCustomSectionParams {
  id?: string
  name?: string
  code?: string
}

export const createInvoiceCustomSection = ({
  id = 'section-1',
  name = 'Section 1',
  code = 'SECTION_1',
}: CreateInvoiceCustomSectionParams = {}): InvoiceCustomSection => {
  return {
    __typename: 'InvoiceCustomSection',
    id,
    name,
    code,
  }
}
