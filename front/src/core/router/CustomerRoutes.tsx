import { CustomRouteObject } from './types'
import { lazyLoad } from './utils'

// ----------- Pages -----------
const CustomersList = lazyLoad(() => import('~/pages/CustomersList'))
const CustomerDetails = lazyLoad(() => import('~/pages/CustomerDetails'))
const CustomerDraftInvoicesList = lazyLoad(() => import('~/pages/CustomerDraftInvoicesList'))
const CustomerInvoiceDetails = lazyLoad(() => import('~/pages/CustomerInvoiceDetails'))

const CustomerRequestOverduePayment = lazyLoad(
  () => import('~/pages/CustomerRequestOverduePayment/index'),
)

const CustomerInvoiceVoid = lazyLoad(() => import(`~/pages/CustomerInvoiceVoid`))
const CustomerInvoiceRegenerate = lazyLoad(() => import('~/pages/CustomerInvoiceRegenerate'))

// Credit note related
const CreateCreditNote = lazyLoad(() => import('~/pages/createCreditNote/CreateCreditNote'))
const CreditNoteDetails = lazyLoad(() => import('~/pages/creditNoteDetails/CreditNoteDetails'))

// ----------- Routes -----------
export const CUSTOMERS_LIST_ROUTE = '/customers'
export const CUSTOMER_DETAILS_ROUTE = '/customer/:customerId'
export const CUSTOMER_DETAILS_TAB_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/:tab`
export const CUSTOMER_DRAFT_INVOICES_LIST_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/draft-invoices`
export const CUSTOMER_INVOICE_DETAILS_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/invoice/:invoiceId/:tab`
export const CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/request-overdue-payment`
export const CUSTOMER_INVOICE_VOID_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/invoice/void/:invoiceId`
export const CUSTOMER_INVOICE_REGENERATE_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/invoice/regenerate/:invoiceId`

// Credit note related
export const CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/invoice/:invoiceId/credit-notes/:creditNoteId`
export const CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/credit-notes/:creditNoteId`
export const CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE = `${CUSTOMER_DETAILS_ROUTE}/invoice/:invoiceId/create/credit-notes`
export const CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE = `${CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE}/:tab`

export const customerRoutes: CustomRouteObject[] = [
  {
    path: CUSTOMERS_LIST_ROUTE,
    private: true,
    element: <CustomersList />,
    permissions: ['customersView'],
  },
  {
    path: [CUSTOMER_DETAILS_ROUTE, CUSTOMER_DETAILS_TAB_ROUTE],
    private: true,
    element: <CustomerDetails />,
    permissions: ['customersView'],
  },
  {
    path: CUSTOMER_DRAFT_INVOICES_LIST_ROUTE,
    private: true,
    element: <CustomerDraftInvoicesList />,
    permissions: ['invoicesView'],
  },
  {
    path: [CUSTOMER_INVOICE_DETAILS_ROUTE],
    private: true,
    element: <CustomerInvoiceDetails />,
    permissions: ['invoicesView'],
  },
  {
    path: [
      CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
      CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE,
      CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE,
    ],
    private: true,
    element: <CreditNoteDetails />,
    permissions: ['creditNotesView'],
  },
]

export const customerVoidRoutes: CustomRouteObject[] = [
  {
    path: [CUSTOMER_INVOICE_VOID_ROUTE],
    private: true,
    element: <CustomerInvoiceVoid />,
    permissions: ['invoicesVoid'],
  },
  {
    path: [CUSTOMER_INVOICE_REGENERATE_ROUTE],
    private: true,
    element: <CustomerInvoiceRegenerate />,
    permissions: ['invoicesVoid'],
  },
]

export const customerObjectCreationRoutes: CustomRouteObject[] = [
  {
    path: CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE,
    private: true,
    element: <CreateCreditNote />,
    permissions: ['creditNotesCreate'],
  },
  {
    path: CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE,
    private: true,
    element: <CustomerRequestOverduePayment />,
    permissions: ['analyticsView'],
  },
]
