import { useMemo } from 'react'

import { LocalTaxProviderErrorsEnum } from '~/core/constants/form'
import {
  AllInvoiceDetailsForCustomerInvoiceDetailsFragment,
  Customer,
  CustomerForInvoiceDetailsFragment,
  ErrorCodesEnum,
  LagoApiError,
} from '~/generated/graphql'
import { useCustomerHasActiveWallet } from '~/hooks/customer/useCustomerHasActiveWallet'
import { usePermissionsInvoiceActions } from '~/hooks/usePermissionsInvoiceActions'

const getErrorMessageFromErrorDetails = (
  errors: AllInvoiceDetailsForCustomerInvoiceDetailsFragment['errorDetails'],
): string | undefined => {
  if (!errors || errors.length === 0) {
    return undefined
  }

  const [{ errorCode, errorDetails }] = errors

  if (errorCode === ErrorCodesEnum.TaxError) {
    if (
      // Anrok
      errorDetails === LagoApiError.CurrencyCodeNotSupported ||
      // Avalara
      errorDetails === LagoApiError.InvalidEnumValue
    ) {
      return LocalTaxProviderErrorsEnum.CurrencyCodeNotSupported
    }

    if (
      // Anrok
      errorDetails === LagoApiError.CustomerAddressCouldNotResolve ||
      errorDetails === LagoApiError.CustomerAddressCountryNotSupported ||
      // Avalara
      errorDetails === LagoApiError.MissingAddress ||
      errorDetails === LagoApiError.NotEnoughAddressesInfo ||
      errorDetails === LagoApiError.InvalidAddress ||
      errorDetails === LagoApiError.InvalidPostalCode ||
      errorDetails === LagoApiError.AddressLocationNotFound
    ) {
      return LocalTaxProviderErrorsEnum.CustomerAddressError
    }

    if (
      // Anrok
      errorDetails === LagoApiError.ProductExternalIdUnknown ||
      // Avalara
      errorDetails === LagoApiError.TaxCodeAssociatedWithItemCodeNotFound ||
      errorDetails === LagoApiError.EntityNotFoundError
    ) {
      return LocalTaxProviderErrorsEnum.ProductExternalIdUnknown
    }

    return LocalTaxProviderErrorsEnum.GenericErrorMessage
  }
}

type UseInvoiceAuthorizationsParams = {
  invoice: AllInvoiceDetailsForCustomerInvoiceDetailsFragment | undefined | null
  customer: CustomerForInvoiceDetailsFragment | undefined | null
}

type InvoiceAuthorizations = {
  canRetryInvoice: boolean
  canFinalizeInvoice: boolean
  canDownloadOnlyPdf: boolean
  canDownloadPdfAndXml: boolean
  canIssueCreditNote: boolean
  canRecordPayment: boolean
  canGeneratePaymentUrl: boolean
  canUpdatePaymentStatus: boolean
  canSyncAccountingIntegration: boolean
  canSyncCRMIntegration: boolean
  canDispute: boolean
  canVoid: boolean
  canRegenerate: boolean
  canSyncTaxIntegration: boolean
  canResendEmail: boolean
}

type UseInvoiceAuthorizationsReturn = {
  authorizations: InvoiceAuthorizations
  hasTaxProviderError: boolean
  errorMessage: string | undefined
  hasActiveWallet: boolean
  canRecordPayment: boolean
}

export const useInvoiceAuthorizations = ({
  invoice,
  customer,
}: UseInvoiceAuthorizationsParams): UseInvoiceAuthorizationsReturn => {
  const actions = usePermissionsInvoiceActions()
  const hasActiveWallet = useCustomerHasActiveWallet({
    customerId: customer?.id,
  })

  const {
    status,
    taxStatus,
    paymentStatus,
    invoiceType,
    errorDetails,
    taxProviderVoidable,
    paymentDisputeLostAt,
    integrationSyncable,
    integrationHubspotSyncable,
    regeneratedInvoiceId,
    billingEntity,
  } = (invoice || {}) as AllInvoiceDetailsForCustomerInvoiceDetailsFragment

  const canRecordPayment = !!invoice && actions.canRecordPayment(invoice)

  const hasTaxProviderError = !!errorDetails?.find(
    ({ errorCode }) => errorCode === ErrorCodesEnum.TaxError,
  )

  const errorMessage = getErrorMessageFromErrorDetails(errorDetails)

  const canFinalize = useMemo(() => actions.canFinalize({ status }), [actions, status])
  const canDownload = useMemo(
    () => actions.canDownload({ status, taxStatus }),
    [actions, status, taxStatus],
  )

  const canDownloadXmlFile = useMemo(() => {
    return invoice?.billingEntity.einvoicing || !!invoice?.xmlUrl
  }, [invoice])

  const authorizations = useMemo((): InvoiceAuthorizations => {
    return {
      canRetryInvoice: hasTaxProviderError,
      canFinalizeInvoice: !hasTaxProviderError && canFinalize,
      canDownloadOnlyPdf:
        !hasTaxProviderError && !canFinalize && canDownload && !canDownloadXmlFile,
      canDownloadPdfAndXml:
        !hasTaxProviderError && !canFinalize && canDownload && !!canDownloadXmlFile,
      canIssueCreditNote: actions.canIssueCreditNote({ status }),
      canRecordPayment: canRecordPayment,
      canGeneratePaymentUrl: actions.canGeneratePaymentUrl({
        status,
        paymentStatus,
        customer: customer as Pick<Customer, 'paymentProvider'>,
      }),
      canUpdatePaymentStatus: actions.canUpdatePaymentStatus({ status, taxStatus }),
      canSyncAccountingIntegration: actions.canSyncAccountingIntegration({ integrationSyncable }),
      canSyncCRMIntegration: actions.canSyncCRMIntegration({ integrationHubspotSyncable }),
      canDispute: actions.canDispute({ status, paymentDisputeLostAt }),
      canVoid: actions.canVoid({ status }),
      canRegenerate: actions.canRegenerate(
        { customer, status, regeneratedInvoiceId, invoiceType },
        hasActiveWallet,
      ),
      canSyncTaxIntegration: actions.canSyncTaxIntegration({ taxProviderVoidable }),
      canResendEmail: actions.canResendEmail({ status, billingEntity }),
    }
  }, [
    hasTaxProviderError,
    canFinalize,
    canDownload,
    canDownloadXmlFile,
    actions,
    status,
    taxStatus,
    canRecordPayment,
    paymentStatus,
    customer,
    integrationSyncable,
    integrationHubspotSyncable,
    paymentDisputeLostAt,
    regeneratedInvoiceId,
    invoiceType,
    hasActiveWallet,
    taxProviderVoidable,
    billingEntity,
  ])

  return {
    authorizations,
    hasTaxProviderError,
    errorMessage,
    hasActiveWallet,
    canRecordPayment,
  }
}
