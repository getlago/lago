import { generatePath } from 'react-router-dom'

import {
  CUSTOMER_INVOICE_REGENERATE_ROUTE,
  VOID_CREATE_INVOICE_ROUTE,
  VOID_CREATE_WALLET_TOP_UP_ROUTE,
} from '~/core/router'
import { isOneOff, isPrepaidCredit } from '~/core/utils/invoiceUtils'
import { Invoice } from '~/generated/graphql'
import { CREATE_ACTIVE_WALLET_TOP_UP_ID } from '~/pages/wallet/CreateWalletTopUp'

export const regeneratePath = (invoice: Pick<Invoice, 'id' | 'invoiceType' | 'customer'>) => {
  if (isPrepaidCredit(invoice)) {
    return generatePath(VOID_CREATE_WALLET_TOP_UP_ROUTE, {
      walletId: CREATE_ACTIVE_WALLET_TOP_UP_ID,
      customerId: invoice?.customer?.id as string,
      voidedInvoiceId: invoice?.id,
    })
  }

  if (isOneOff(invoice)) {
    return generatePath(VOID_CREATE_INVOICE_ROUTE, {
      customerId: invoice?.customer?.id as string,
      voidedInvoiceId: invoice?.id,
    })
  }

  return generatePath(CUSTOMER_INVOICE_REGENERATE_ROUTE, {
    customerId: invoice?.customer?.id,
    invoiceId: invoice.id,
  })
}
