import { envGlobalVar } from '~/core/apolloClient'
import { isPrepaidCredit } from '~/core/utils/invoiceUtils'
import {
  BillingEntityEmailSettingsEnum,
  Invoice,
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  InvoiceTaxStatusTypeEnum,
} from '~/generated/graphql'
import { usePermissions } from '~/hooks/usePermissions'

const { disablePdfGeneration } = envGlobalVar()

export const usePermissionsInvoiceActions = () => {
  const { hasPermissions } = usePermissions()

  const canDownload = (invoice: Pick<Invoice, 'status' | 'taxStatus'>): boolean => {
    return (
      ![
        InvoiceStatusTypeEnum.Draft,
        InvoiceStatusTypeEnum.Failed,
        InvoiceStatusTypeEnum.Pending,
      ].includes(invoice.status) &&
      invoice.taxStatus !== InvoiceTaxStatusTypeEnum.Pending &&
      hasPermissions(['invoicesView']) &&
      !disablePdfGeneration
    )
  }

  const canFinalize = (invoice: Pick<Invoice, 'status'>): boolean => {
    return invoice.status === InvoiceStatusTypeEnum.Draft && hasPermissions(['invoicesUpdate'])
  }

  const canGeneratePaymentUrl = (
    invoice: Pick<Invoice, 'status' | 'paymentStatus'> & {
      customer: Pick<Invoice['customer'], 'paymentProvider'>
    },
  ): boolean => {
    return (
      !!invoice.customer?.paymentProvider &&
      invoice.status === InvoiceStatusTypeEnum.Finalized &&
      invoice.paymentStatus !== InvoicePaymentStatusTypeEnum.Succeeded
    )
  }

  const canRetryCollect = (invoice: Pick<Invoice, 'status' | 'paymentStatus'>): boolean => {
    return (
      invoice.status === InvoiceStatusTypeEnum.Finalized &&
      [InvoicePaymentStatusTypeEnum.Failed, InvoicePaymentStatusTypeEnum.Pending].includes(
        invoice.paymentStatus,
      ) &&
      hasPermissions(['invoicesSend'])
    )
  }

  const canUpdatePaymentStatus = (invoice: Pick<Invoice, 'status' | 'taxStatus'>): boolean => {
    return (
      ![
        InvoiceStatusTypeEnum.Draft,
        InvoiceStatusTypeEnum.Voided,
        InvoiceStatusTypeEnum.Failed,
        InvoiceStatusTypeEnum.Pending,
      ].includes(invoice.status) &&
      invoice.taxStatus !== InvoiceTaxStatusTypeEnum.Pending &&
      hasPermissions(['invoicesUpdate'])
    )
  }

  const canVoid = (invoice: Pick<Invoice, 'status'>): boolean => {
    return invoice.status === InvoiceStatusTypeEnum.Finalized && hasPermissions(['invoicesVoid'])
  }

  const canRegenerate = (
    invoice: Pick<Invoice, 'status' | 'regeneratedInvoiceId' | 'invoiceType'> & {
      customer?: {
        deletedAt?: string
      } | null
    },
    hasActiveWallet: boolean,
  ): boolean => {
    const isRegenerable =
      !invoice?.customer?.deletedAt &&
      invoice.status === InvoiceStatusTypeEnum.Voided &&
      !invoice.regeneratedInvoiceId &&
      hasPermissions(['invoicesVoid'])

    if (isPrepaidCredit(invoice)) {
      return isRegenerable && hasActiveWallet
    }

    return isRegenerable
  }

  const canIssueCreditNote = (invoice: Pick<Invoice, 'status'>): boolean => {
    return (
      [InvoiceStatusTypeEnum.Finalized].includes(invoice.status) &&
      hasPermissions(['creditNotesCreate'])
    )
  }

  const canRecordPayment = (
    invoice: Pick<
      Invoice,
      'totalDueAmountCents' | 'totalPaidAmountCents' | 'totalAmountCents' | 'status'
    >,
  ): boolean => {
    return (
      invoice.status === InvoiceStatusTypeEnum.Finalized &&
      Number(invoice.totalDueAmountCents) > 0 &&
      hasPermissions(['paymentsCreate']) &&
      Number(invoice.totalPaidAmountCents) < Number(invoice.totalAmountCents)
    )
  }

  const canDispute = (invoice: Pick<Invoice, 'status' | 'paymentDisputeLostAt'>): boolean => {
    return (
      invoice.status === InvoiceStatusTypeEnum.Finalized &&
      !invoice.paymentDisputeLostAt &&
      hasPermissions(['invoicesUpdate'])
    )
  }

  const canSyncAccountingIntegration = (invoice: Pick<Invoice, 'integrationSyncable'>): boolean => {
    return !!invoice.integrationSyncable
  }

  const canSyncCRMIntegration = (invoice: Pick<Invoice, 'integrationHubspotSyncable'>): boolean => {
    return !!invoice.integrationHubspotSyncable
  }

  const canSyncTaxIntegration = (invoice: Pick<Invoice, 'taxProviderVoidable'>): boolean => {
    return !!invoice.taxProviderVoidable
  }

  const canResendEmail = (
    invoice: Pick<Invoice, 'status'> & {
      billingEntity: Pick<Invoice['billingEntity'], 'emailSettings'>
    },
  ): boolean => {
    return (
      invoice.status === InvoiceStatusTypeEnum.Finalized &&
      hasPermissions(['invoicesSend']) &&
      !!invoice?.billingEntity?.emailSettings?.includes(
        BillingEntityEmailSettingsEnum.InvoiceFinalized,
      )
    )
  }

  return {
    canDownload,
    canFinalize,
    canRetryCollect,
    canGeneratePaymentUrl,
    canUpdatePaymentStatus,
    canVoid,
    canRegenerate,
    canIssueCreditNote,
    canRecordPayment,
    canDispute,
    canSyncAccountingIntegration,
    canSyncCRMIntegration,
    canSyncTaxIntegration,
    canResendEmail,
  }
}
