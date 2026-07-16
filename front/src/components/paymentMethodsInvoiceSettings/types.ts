import { InvoiceFormInput } from '~/components/invoices/types'
import { CreateCustomerWalletTransactionInput, Customer } from '~/generated/graphql'
import { SubscriptionFormInput } from '~/pages/subscriptions/types'
import { TWalletDataForm } from '~/pages/wallet/types'

export enum ViewTypeEnum {
  Subscription = 'subscription',
  WalletTopUp = 'walletTopUp',
  WalletRecurringTopUp = 'walletRecurringTopUp',
  WalletTransactionTopUp = 'walletTransactionTopUp',
  OneOffInvoice = 'oneOffInvoice',
}

export const VIEW_TYPE_TRANSLATION_KEYS: Record<ViewTypeEnum, string> = {
  [ViewTypeEnum.Subscription]: 'text_1764327933607nrezuuiheuc',
  [ViewTypeEnum.WalletTopUp]: 'text_1765895170354ovelm7g07o4',
  [ViewTypeEnum.WalletRecurringTopUp]: 'text_1765959116589recur1ngrul',
  [ViewTypeEnum.WalletTransactionTopUp]: 'text_17659678187872em8xoix499',
  [ViewTypeEnum.OneOffInvoice]: 'text_1766405484863ts63ubynxt3',
}

type FormTypeMap = {
  [ViewTypeEnum.Subscription]: SubscriptionFormInput
  [ViewTypeEnum.WalletTopUp]: TWalletDataForm
  [ViewTypeEnum.WalletRecurringTopUp]: TWalletDataForm
  [ViewTypeEnum.WalletTransactionTopUp]: Omit<CreateCustomerWalletTransactionInput, 'walletId'>
  [ViewTypeEnum.OneOffInvoice]: InvoiceFormInput
}

type CustomerForPaymentMethods = Partial<Pick<Customer, 'id' | 'externalId'>> | null | undefined

export interface PaymentMethodsForm<T extends ViewTypeEnum = ViewTypeEnum> {
  values: Partial<FormTypeMap[T]>
  setFieldValue(field: string, value: unknown): unknown
}

// Shared by both single-purpose settings components and the composite — they
// only differ in which child (and customer field) they render.
export interface SettingsComponentProps<T extends ViewTypeEnum = ViewTypeEnum> {
  customer: CustomerForPaymentMethods
  form: PaymentMethodsForm<T>
  viewType: T
  formFieldBasePath?: string
}
