import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { CreateInvoiceInput, FeeInput, TaxInfosForCreateInvoiceFragment } from '~/generated/graphql'

export type LocalFeeInput = FeeInput & {
  // NOTE: this is used for display purpose but will be replaced by taxCodes[] on save
  taxes?: TaxInfosForCreateInvoiceFragment[] | null
}

export type InvoiceFormInput = Omit<
  CreateInvoiceInput,
  'clientMutationId' | 'paymentMethod' | 'fees'
> & {
  fees: LocalFeeInput[]
  paymentMethod?: SelectedPaymentMethod
  invoiceCustomSection?: InvoiceCustomSectionInput
  purchaseOrderNumber?: string | null
}
