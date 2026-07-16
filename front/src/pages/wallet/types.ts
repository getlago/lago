import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import {
  CreateCustomerWalletInput,
  UpdateCustomerWalletInput,
  WalletForScopeSectionFragment,
} from '~/generated/graphql'

export type TWalletDataForm = Omit<CreateCustomerWalletInput, 'customerId'> &
  Omit<UpdateCustomerWalletInput, 'id'> & {
    appliesTo?: WalletForScopeSectionFragment['appliesTo']
    paymentMethod?: SelectedPaymentMethod
    invoiceCustomSection?: InvoiceCustomSectionInput
  }
