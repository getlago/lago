import { gql } from '@apollo/client'

import {
  FeeForInvoiceDetailsTableBodyLineFragmentDoc,
  InvoiceForDetailsTableFooterFragmentDoc,
  InvoiceForFormatInvoiceItemMapFragmentDoc,
  useGetInvoiceBuildRegenerationPreviewQuery,
} from '~/generated/graphql'

// Fragments are intentionally dedicated to this query rather than reusing page-level
// fragments from CustomerInvoiceDetails or InvoiceOverview. Shared page fragments
// write to the same normalized Apollo cache entities (Invoice:id, Fee:id), so a prior
// page visit can leave stale field values that satisfy cache-first reads here —
// causing CustomerInvoiceRegenerate to render old data without ever hitting the network.
// Dedicated fragments keep the field selection self-contained and make the query's data
// requirements explicit. Component-level fragment docs (footer, format-map, body-line)
// are still imported because those selections are owned by the components that render them.
gql`
  fragment InvoiceForInvoiceBuildRegenerationPreview on Invoice {
    id
    allChargesHaveFees
    allFixedChargesHaveFees
    associatedActiveWalletPresent
    creditableAmountCents
    currency
    expectedFinalizationDate
    externalHubspotIntegrationId
    externalIntegrationId
    externalSalesforceIntegrationId
    integrationHubspotSyncable
    integrationSalesforceSyncable
    integrationSyncable
    invoiceType
    issuingDate
    number
    offsettableAmountCents
    paymentDisputeLostAt
    paymentDueDate
    paymentOverdue
    paymentStatus
    purchaseOrderNumber
    refundableAmountCents
    regeneratedInvoiceId
    status
    taxProviderId
    taxProviderVoidable
    taxStatus
    totalAmountCents
    totalDueAmountCents
    totalPaidAmountCents
    versionNumber
    voidable
    voidedAt
    voidedInvoiceId
    xmlUrl
    billingEntity {
      id
      code
      einvoicing
      email
      emailSettings
      logoUrl
      name
    }
    customer {
      id
      accountType
      addressLine1
      addressLine2
      applicableTimezone
      city
      country
      deletedAt
      displayName
      email
      legalName
      legalNumber
      name
      state
      taxIdentificationNumber
      zipcode
    }
    errorDetails {
      errorCode
      errorDetails
    }
    subscriptions {
      id
      name
      currentBillingPeriodStartedAt
      currentBillingPeriodEndingAt
      plan {
        id
        amountCents
        amountCurrency
        interval
        invoiceDisplayName
        name
      }
    }
    ...InvoiceForDetailsTableFooter
    ...InvoiceForFormatInvoiceItemMap
  }

  fragment FeeForInvoiceBuildRegenerationPreview on Fee {
    id
    amountCents
    currency
    description
    feeType
    groupedBy
    invoiceDisplayName
    invoiceName
    itemName
    preciseUnitAmount
    succeededAt
    units
    addOn {
      id
    }
    appliedTaxes {
      id
      taxCode
    }
    charge {
      id
      minAmountCents
      payInAdvance
      billableMetric {
        id
        aggregationType
        name
      }
    }
    chargeFilter {
      id
      invoiceDisplayName
      values
    }
    properties {
      fromDatetime
      toDatetime
    }
    subscription {
      id
      plan {
        id
        interval
        name
      }
    }
    trueUpParentFee {
      id
    }
    walletTransaction {
      id
      name
      wallet {
        id
        name
      }
    }
    ...FeeForInvoiceDetailsTableBodyLine
  }

  query getInvoiceBuildRegenerationPreview($id: ID!) {
    invoiceBuildRegenerationPreview(id: $id) {
      id
      ...InvoiceForInvoiceBuildRegenerationPreview

      fees {
        ...FeeForInvoiceBuildRegenerationPreview
      }
    }
  }

  ${InvoiceForDetailsTableFooterFragmentDoc}
  ${InvoiceForFormatInvoiceItemMapFragmentDoc}
  ${FeeForInvoiceDetailsTableBodyLineFragmentDoc}
`

export const useInvoiceBuildRegenerationPreview = (invoiceId?: string) => {
  const { data, loading, error } = useGetInvoiceBuildRegenerationPreviewQuery({
    variables: { id: invoiceId as string },
    skip: !invoiceId,
    // cache-and-network returns cached data immediately for a fast first render, then
    // always fires a network request to get the latest preview from the server.
    // notifyOnNetworkStatusChange: true guarantees a re-render when the network response
    // arrives by emitting loading state transitions unconditionally — without it,
    // Apollo only re-renders if it detects a value difference between the cached result
    // and the network result, which can silently skip updates when normalized entities
    // (Invoice:id, Fee:id, FeeAppliedTax:id) already carry matching field values from
    // a prior page visit.
    fetchPolicy: 'cache-and-network',
    notifyOnNetworkStatusChange: true,
  })

  return {
    data,
    error,
    invoiceBuildRegenerationPreview: data?.invoiceBuildRegenerationPreview,
    loading,
  }
}
