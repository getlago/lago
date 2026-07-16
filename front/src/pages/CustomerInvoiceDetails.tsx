import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { useCallback, useMemo, useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { createCreditNoteForInvoiceButtonProps } from '~/components/creditNote/utils'
import { Alert } from '~/components/designSystem/Alert'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { buildInvoiceDocumentData } from '~/components/emails/buildDocumentData'
import { AddMetadataDrawer, AddMetadataDrawerRef } from '~/components/invoices/AddMetadataDrawer'
import { useDisputeInvoiceDialog } from '~/components/invoices/DisputeInvoiceDialog'
import { useUpdateInvoicePaymentStatusDialog } from '~/components/invoices/EditInvoicePaymentStatusDialog'
import {
  FinalizeInvoiceDialog,
  FinalizeInvoiceDialogRef,
} from '~/components/invoices/FinalizeInvoiceDialog'
import { InvoiceActivityLogs } from '~/components/invoices/InvoiceActivityLogs'
import { InvoiceCreditNoteList } from '~/components/invoices/InvoiceCreditNoteList'
import { InvoicePaymentList } from '~/components/invoices/InvoicePaymentList'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { addToast, LagoGQLError } from '~/core/apolloClient'
import { invoiceStatusMapping, paymentStatusMapping } from '~/core/constants/statusInvoiceMapping'
import {
  CustomerDetailsTabsOptions,
  CustomerInvoiceDetailsTabsOptionsEnum,
} from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  CREATE_INVOICE_PAYMENT_ROUTE,
  CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE,
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_VOID_ROUTE,
  INVOICES_ROUTE,
  useNavigate,
} from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { regeneratePath } from '~/core/utils/regenerateUtils'
import {
  AllInvoiceDetailsForCustomerInvoiceDetailsFragment,
  AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc,
  AvalaraIntegration,
  AvalaraIntegrationInfosForInvoiceOverviewFragmentDoc,
  BillingEntityEmailSettingsEnum,
  CurrencyEnum,
  CustomerForInvoiceOverviewFragmentDoc,
  FeeDetailsForInvoiceOverviewFragmentDoc,
  FeeForInvoiceDetailsTableFooterFragmentDoc,
  HubspotIntegration,
  HubspotIntegrationInfosForInvoiceOverviewFragmentDoc,
  Invoice,
  InvoiceDetailsForInvoiceOverviewFragmentDoc,
  InvoiceForDetailsTableFragmentDoc,
  InvoiceForFinalizeInvoiceFragmentDoc,
  InvoiceForFormatInvoiceItemMapFragmentDoc,
  InvoiceForInvoiceInfosFragmentDoc,
  InvoiceForUpdateInvoicePaymentStatusFragmentDoc,
  InvoiceStatusTypeEnum,
  InvoiceTaxStatusTypeEnum,
  LagoApiError,
  NetsuiteIntegration,
  NetsuiteIntegrationInfosForInvoiceOverviewFragmentDoc,
  SalesforceIntegration,
  SalesforceIntegrationInfosForInvoiceOverviewFragmentDoc,
  useGetInvoiceCustomerQuery,
  useGetInvoiceDetailsQuery,
  useGetInvoiceFeesQuery,
  useIntegrationsListForCustomerInvoiceDetailsQuery,
  useRefreshInvoiceMutation,
  useRetryInvoiceMutation,
  useRetryTaxProviderVoidingMutation,
  useSyncHubspotIntegrationInvoiceMutation,
  useSyncIntegrationInvoiceMutation,
  useSyncSalesforceInvoiceMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useGeneratePaymentUrl } from '~/hooks/useGeneratePaymentUrl'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'
import { useResendEmailDialog } from '~/hooks/useResendEmailDialog'
import { useDownloadInvoice } from '~/pages/invoiceDetails/common/useDownloadInvoice'
import { useInvoiceAuthorizations } from '~/pages/invoiceDetails/common/useInvoiceAuthorizations'
import InvoiceOverview from '~/pages/InvoiceOverview'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  fragment AllInvoiceDetailsForCustomerInvoiceDetails on Invoice {
    id
    invoiceType
    number
    paymentStatus
    status
    taxStatus
    totalAmountCents
    currency
    purchaseOrderNumber
    refundableAmountCents
    creditableAmountCents
    offsettableAmountCents
    voidable
    paymentDisputeLostAt
    integrationSyncable
    externalIntegrationId
    taxProviderVoidable
    integrationHubspotSyncable
    associatedActiveWalletPresent
    voidedAt
    voidedInvoiceId
    regeneratedInvoiceId
    errorDetails {
      errorCode
      errorDetails
    }
    customer {
      id
      email
    }

    ...InvoiceDetailsForInvoiceOverview
    ...InvoiceForDetailsTable
    ...InvoiceForInvoiceInfos
    ...InvoiceForFinalizeInvoice
    ...InvoiceForUpdateInvoicePaymentStatus
  }

  fragment FeeAppliedTaxesForInvoiceDetails on Fee {
    appliedTaxes {
      id
      taxCode
      taxRate
      tax {
        id
        code
        name
        rate
      }
    }
  }

  fragment CustomerForInvoiceDetails on Customer {
    id
    name
    paymentProvider
    deletedAt
    avalaraCustomer {
      id
      integrationId
    }
    netsuiteCustomer {
      id
      integrationId
      externalCustomerId
    }
    xeroCustomer {
      id
      integrationId
    }
    hubspotCustomer {
      id
      integrationId
    }
    salesforceCustomer {
      id
      integrationId
    }
  }

  query getInvoiceDetails($id: ID!) {
    invoice(id: $id) {
      id
      ...AllInvoiceDetailsForCustomerInvoiceDetails
      fees {
        id
        ...FeeAppliedTaxesForInvoiceDetails
      }
    }
  }

  query getInvoiceFees($id: ID!) {
    invoice(id: $id) {
      id
      ...InvoiceForInvoiceDetailsTable
      ...InvoiceForFormatInvoiceItemMap

      fees {
        ...FeeDetailsForInvoiceOverview
        ...FeeForInvoiceDetailsTable
        ...FeeForInvoiceDetailsTableFooter
        ...FeeAppliedTaxesForInvoiceDetails
      }
    }
  }

  query getInvoiceCustomer($id: ID!) {
    customer(id: $id) {
      id
      ...CustomerForInvoiceDetails
      ...CustomerForInvoiceOverview
    }
  }

  query getInvoiceNumber($id: ID!) {
    invoice(id: $id) {
      id
      number
    }
  }

  query getInvoiceStatus($id: ID!) {
    invoice(id: $id) {
      id
      status
    }
  }

  query integrationsListForCustomerInvoiceDetails($limit: Int) {
    integrations(limit: $limit) {
      collection {
        ... on NetsuiteIntegration {
          __typename
          id
          ...NetsuiteIntegrationInfosForInvoiceOverview
        }

        ... on HubspotIntegration {
          __typename
          id
          ...HubspotIntegrationInfosForInvoiceOverview
        }

        ... on SalesforceIntegration {
          __typename
          id
          ...SalesforceIntegrationInfosForInvoiceOverview
        }

        ... on AvalaraIntegration {
          __typename
          id
          ...AvalaraIntegrationInfosForInvoiceOverview
        }
      }
    }
  }

  mutation refreshInvoice($input: RefreshInvoiceInput!) {
    refreshInvoice(input: $input) {
      id
      fees {
        ...FeeForInvoiceDetailsTable
      }
    }
  }

  mutation syncIntegrationInvoice($input: SyncIntegrationInvoiceInput!) {
    syncIntegrationInvoice(input: $input) {
      invoiceId
    }
  }

  mutation syncHubspotIntegrationInvoice($input: SyncHubspotIntegrationInvoiceInput!) {
    syncHubspotIntegrationInvoice(input: $input) {
      invoiceId
    }
  }

  mutation syncSalesforceInvoice($input: SyncSalesforceInvoiceInput!) {
    syncSalesforceInvoice(input: $input) {
      invoiceId
    }
  }

  mutation retryInvoice($input: RetryInvoiceInput!) {
    retryInvoice(input: $input) {
      id
    }
  }

  mutation retryTaxProviderVoiding($input: RetryTaxProviderVoidingInput!) {
    retryTaxProviderVoiding(input: $input) {
      id
    }
  }

  ${InvoiceForDetailsTableFragmentDoc}
  ${InvoiceForInvoiceInfosFragmentDoc}
  ${InvoiceDetailsForInvoiceOverviewFragmentDoc}
  ${AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc}
  ${InvoiceForFinalizeInvoiceFragmentDoc}
  ${InvoiceForUpdateInvoicePaymentStatusFragmentDoc}
  ${NetsuiteIntegrationInfosForInvoiceOverviewFragmentDoc}
  ${HubspotIntegrationInfosForInvoiceOverviewFragmentDoc}
  ${SalesforceIntegrationInfosForInvoiceOverviewFragmentDoc}
  ${AvalaraIntegrationInfosForInvoiceOverviewFragmentDoc}
  ${CustomerForInvoiceOverviewFragmentDoc}
  ${InvoiceForFormatInvoiceItemMapFragmentDoc}
  ${FeeDetailsForInvoiceOverviewFragmentDoc}
  ${FeeForInvoiceDetailsTableFooterFragmentDoc}
`

const CustomerInvoiceDetails = () => {
  const { translate } = useInternationalization()
  const { customerId, invoiceId } = useParams()
  const navigate = useNavigate()
  const { goBack } = useLocationHistory()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()
  const finalizeInvoiceRef = useRef<FinalizeInvoiceDialogRef>(null)
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
  const { openUpdateInvoicePaymentStatusDialog } = useUpdateInvoicePaymentStatusDialog()
  const addMetadataDrawerDialogRef = useRef<AddMetadataDrawerRef>(null)
  const { openDisputeInvoiceDialog } = useDisputeInvoiceDialog()
  const activeTabContent = useMainHeaderTabContent()

  const { data, loading, error, refetch } = useGetInvoiceDetailsQuery({
    variables: { id: invoiceId as string },
    skip: !invoiceId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
    fetchPolicy: 'cache-and-network',
    notifyOnNetworkStatusChange: true,
  })

  useNotFoundRedirect({
    error,
    loading,
    redirectTo: INVOICES_ROUTE,
    translateKey: 'text_1777995443788zg01psy967w',
  })
  const {
    data: feesData,
    loading: feesLoading,
    error: feesError,
  } = useGetInvoiceFeesQuery({
    variables: { id: invoiceId as string },
    skip: !invoiceId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
    fetchPolicy: 'cache-and-network',
    notifyOnNetworkStatusChange: true,
  })
  const invoice = data?.invoice
  const invoiceFees = feesData?.invoice?.fees

  const { data: customerData, loading: customerLoading } = useGetInvoiceCustomerQuery({
    variables: { id: invoice?.customer?.id as string },
    skip: !invoice?.customer?.id,
    context: {
      // NOTE: This call is not critical, it aims to get the customer infos for display purpose.
      // It can happen the customer have been deleted meanwhile hence having a not found error.
      // We just don't want to display an error in this case.
      silentErrorCodes: [LagoApiError.NotFound],
    },
  })

  const { showResendEmailDialog } = useResendEmailDialog()

  const customer = customerData?.customer

  const { authorizations, hasTaxProviderError, errorMessage, canRecordPayment } =
    useInvoiceAuthorizations({ invoice, customer })

  const [refreshInvoice, { loading: loadingRefreshInvoice }] = useRefreshInvoiceMutation({
    variables: { input: { id: invoiceId || '' } },
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity, LagoApiError.InternalError],
    },
    onError: ({ graphQLErrors }) => {
      graphQLErrors.forEach((graphQLError) => {
        const { extensions } = graphQLError as LagoGQLError

        if (extensions.details?.taxError?.length) {
          addToast({
            severity: 'danger',
            translateKey: 'text_1724438705077s7oxv5be87m',
          })
        }
      })
    },
  })
  const [retryInvoice, { loading: loadingRetryInvoice }] = useRetryInvoiceMutation({
    variables: { input: { id: invoiceId || '' } },
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity, LagoApiError.InternalError],
    },
    onCompleted: async ({ retryInvoice: retryInvoiceResult }) => {
      if (retryInvoiceResult?.id) {
        await refetch()
      }
    },
    onError: ({ graphQLErrors }) => {
      graphQLErrors.forEach((graphQLError) => {
        const { extensions } = graphQLError as LagoGQLError

        if (extensions.details?.taxError?.length) {
          addToast({
            severity: 'danger',
            translateKey: 'text_1724438705077s7oxv5be87m',
          })
        }
      })
    },
  })

  const { generatePaymentUrl } = useGeneratePaymentUrl()

  const [retryTaxProviderVoiding, { loading: loadingRetryTaxProviderVoiding }] =
    useRetryTaxProviderVoidingMutation({
      variables: { input: { id: invoiceId || '' } },
      context: {
        silentErrorCodes: [LagoApiError.UnprocessableEntity, LagoApiError.InternalError],
      },
      onCompleted({ retryTaxProviderVoiding: retryTaxProviderVoidingResult }) {
        if (retryTaxProviderVoidingResult?.id) {
          addToast({
            severity: 'success',
            translateKey: 'text_172535279177716n7p2svtdb',
          })
        }
      },
    })

  const [syncIntegrationInvoice, { loading: loadingSyncIntegrationInvoice }] =
    useSyncIntegrationInvoiceMutation({
      variables: { input: { invoiceId: invoiceId || '' } },
      onCompleted({ syncIntegrationInvoice: syncIntegrationInvoiceResult }) {
        if (syncIntegrationInvoiceResult?.invoiceId) {
          addToast({
            severity: 'success',
            translateKey: !!customer?.netsuiteCustomer
              ? 'text_6655a88569eed300ee8c4d44'
              : 'text_17268445285571pwim3q27vl',
          })
        }
      },
    })

  const [syncHubspotIntegrationInvoice, { loading: loadingSyncHubspotIntegrationInvoice }] =
    useSyncHubspotIntegrationInvoiceMutation({
      variables: { input: { invoiceId: invoiceId || '' } },
      onCompleted({ syncHubspotIntegrationInvoice: syncHubspotIntegrationInvoiceResult }) {
        if (syncHubspotIntegrationInvoiceResult?.invoiceId) {
          addToast({
            severity: 'success',
            translateKey: 'text_1729756690073w4jrdeesayy',
          })
        }
      },
    })

  const [syncSalesforceIntegrationInvoice, { loading: loadingSyncSalesforceIntegrationInvoice }] =
    useSyncSalesforceInvoiceMutation({
      variables: { input: { invoiceId: invoiceId || '' } },
      onCompleted({ syncSalesforceInvoice: syncSalesforceInvoiceResult }) {
        if (syncSalesforceInvoiceResult?.invoiceId) {
          addToast({
            severity: 'success',
            translateKey: 'text_17316853046485zk7ibjnwbb',
          })
        }
      },
    })

  const { downloadInvoice, loadingInvoiceDownload, downloadInvoiceXml, loadingInvoiceXmlDownload } =
    useDownloadInvoice()

  const { data: integrationsData } = useIntegrationsListForCustomerInvoiceDetailsQuery({
    variables: { limit: 1000 },
    skip:
      !customer?.netsuiteCustomer?.integrationId &&
      !customer?.xeroCustomer?.integrationId &&
      !customer?.hubspotCustomer?.integrationId &&
      !customer?.salesforceCustomer?.integrationId &&
      !customer?.avalaraCustomer?.integrationId,
  })

  const allNetsuiteIntegrations = integrationsData?.integrations?.collection.filter(
    (i) => i.__typename === 'NetsuiteIntegration',
  ) as NetsuiteIntegration[] | undefined

  const allHubspotIntegrations = integrationsData?.integrations?.collection.filter(
    (i) => i.__typename === 'HubspotIntegration',
  ) as HubspotIntegration[] | undefined

  const allSalesforceIntegration = integrationsData?.integrations?.collection.filter(
    (i) => i.__typename === 'SalesforceIntegration',
  ) as SalesforceIntegration[] | undefined

  const allAvalaraIntegration = integrationsData?.integrations?.collection.filter(
    (i) => i.__typename === 'AvalaraIntegration',
  ) as AvalaraIntegration[] | undefined

  const connectedNetsuiteIntegration = allNetsuiteIntegrations?.find(
    (integration) => integration?.id === customer?.netsuiteCustomer?.integrationId,
  ) as NetsuiteIntegration

  const connectedHubspotIntegration = allHubspotIntegrations?.find(
    (integration) => integration?.id === customer?.hubspotCustomer?.integrationId,
  ) as HubspotIntegration

  const connectedSalesforceIntegration = allSalesforceIntegration?.find(
    (integration) => integration?.id === customer?.salesforceCustomer?.integrationId,
  ) as SalesforceIntegration

  const connectedAvalaraIntegration = allAvalaraIntegration?.find(
    (integration) => integration?.id === customer?.avalaraCustomer?.integrationId,
  ) as AvalaraIntegration

  const {
    invoiceType,
    number,
    paymentStatus,
    totalAmountCents,
    currency,
    status,
    taxStatus,
    creditableAmountCents,
    refundableAmountCents,
    offsettableAmountCents,
    taxProviderVoidable,
    associatedActiveWalletPresent,
    paymentDisputeLostAt,
    errorDetails,
  } = (invoice as AllInvoiceDetailsForCustomerInvoiceDetailsFragment) || {}

  const isLoading = loading || customerLoading || feesLoading
  const hasError = (!!error || !!feesError || !data?.invoice) && !isLoading

  const { disabledIssueCreditNoteButton, disabledIssueCreditNoteButtonLabel } =
    createCreditNoteForInvoiceButtonProps({
      invoiceType,
      creditableAmountCents,
      refundableAmountCents,
      offsettableAmountCents,
      associatedActiveWalletPresent,
    })

  const goToPreviousRoute = useCallback(
    () =>
      goBack(
        generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
          customerId: customerId as string,
          tab: CustomerDetailsTabsOptions.invoices,
        }),
        {
          exclude: [
            CUSTOMER_INVOICE_DETAILS_ROUTE,
            CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE,
            CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE,
            CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
          ],
        },
      ),
    [customerId, goBack],
  )

  const tabsOptions = useMemo(() => {
    const tabs = [
      {
        title: translate('text_634687079be251fdb43833b7'),
        link: generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
        }),
        match: [
          generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
            customerId: customerId as string,
            invoiceId: invoiceId as string,
            tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
          }),
        ],
        content: (
          <InvoiceOverview
            downloadInvoice={downloadInvoice}
            downloadInvoiceXml={downloadInvoiceXml}
            hasError={hasError}
            hasTaxProviderError={!!hasTaxProviderError}
            invoice={data?.invoice}
            loading={isLoading}
            customer={customer}
            fees={invoiceFees}
            loadingInvoiceDownload={loadingInvoiceDownload}
            loadingInvoiceXmlDownload={loadingInvoiceXmlDownload}
            loadingRefreshInvoice={loadingRefreshInvoice}
            loadingRetryInvoice={loadingRetryInvoice}
            loadingRetryTaxProviderVoiding={loadingRetryTaxProviderVoiding}
            refreshInvoice={refreshInvoice}
            retryInvoice={retryInvoice}
            retryTaxProviderVoiding={retryTaxProviderVoiding}
            connectedNetsuiteIntegration={connectedNetsuiteIntegration}
            connectedHubspotIntegration={connectedHubspotIntegration}
            connectedSalesforceIntegration={connectedSalesforceIntegration}
            connectedAvalaraIntegration={connectedAvalaraIntegration}
            goToPreviousRoute={goToPreviousRoute}
            syncHubspotIntegrationInvoice={syncHubspotIntegrationInvoice}
            syncSalesforceIntegrationInvoice={syncSalesforceIntegrationInvoice}
            loadingSyncHubspotIntegrationInvoice={loadingSyncHubspotIntegrationInvoice}
            loadingSyncSalesforceIntegrationInvoice={loadingSyncSalesforceIntegrationInvoice}
          />
        ),
      },
    ]

    if (status === InvoiceStatusTypeEnum.Pending || status === InvoiceStatusTypeEnum.Finalized) {
      tabs.push({
        title: translate('text_6672ebb8b1b50be550eccbed'),
        link: generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          tab: CustomerInvoiceDetailsTabsOptionsEnum.payments,
        }),
        match: [
          generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
            customerId: customerId as string,
            invoiceId: invoiceId as string,
            tab: CustomerInvoiceDetailsTabsOptionsEnum.payments,
          }),
        ],
        content: <InvoicePaymentList canRecordPayment={canRecordPayment} />,
      })
    }

    if (
      ![
        InvoiceStatusTypeEnum.Draft,
        InvoiceStatusTypeEnum.Failed,
        InvoiceStatusTypeEnum.Pending,
      ].includes(status) &&
      taxStatus !== InvoiceTaxStatusTypeEnum.Pending &&
      hasPermissions(['creditNotesView'])
    ) {
      tabs.push({
        title: translate('text_636bdef6565341dcb9cfb125'),
        link: generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          tab: CustomerInvoiceDetailsTabsOptionsEnum.creditNotes,
        }),
        match: [
          generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
            customerId: customerId as string,
            invoiceId: invoiceId as string,
            tab: CustomerInvoiceDetailsTabsOptionsEnum.creditNotes,
          }),
        ],
        content: <InvoiceCreditNoteList />,
      })
    }

    if (isPremium && hasPermissions(['auditLogsView'])) {
      tabs.push({
        title: translate('text_1747314141347qq6rasuxisl'),
        link: generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          tab: CustomerInvoiceDetailsTabsOptionsEnum.activityLogs,
        }),
        match: [
          generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
            customerId: customerId as string,
            invoiceId: invoiceId as string,
            tab: CustomerInvoiceDetailsTabsOptionsEnum.activityLogs,
          }),
        ],
        content: (
          <div className="pt-5">
            <InvoiceActivityLogs invoiceId={invoiceId as string} />
          </div>
        ),
      })
    }

    return tabs
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    translate,
    customerId,
    invoiceId,
    downloadInvoice,
    hasError,
    hasTaxProviderError,
    data?.invoice,
    isLoading,
    customer,
    invoiceFees,
    loadingInvoiceDownload,
    loadingRefreshInvoice,
    loadingRetryInvoice,
    loadingRetryTaxProviderVoiding,
    refreshInvoice,
    retryInvoice,
    retryTaxProviderVoiding,
    connectedNetsuiteIntegration,
    connectedHubspotIntegration,
    connectedSalesforceIntegration,
    connectedAvalaraIntegration,
    goToPreviousRoute,
    syncHubspotIntegrationInvoice,
    syncSalesforceIntegrationInvoice,
    loadingSyncHubspotIntegrationInvoice,
    loadingSyncSalesforceIntegrationInvoice,
    status,
    taxStatus,
    isPremium,
    hasPermissions,
    canRecordPayment,
  ])

  const resendEmail = () => {
    showResendEmailDialog({
      subject: translate('text_17706311399878xdnudpnjtt', {
        organization: invoice?.billingEntity.name,
        invoiceNumber: invoice?.number,
      }),
      type: BillingEntityEmailSettingsEnum.InvoiceFinalized,
      billingEntity: invoice?.billingEntity,
      documentId: invoice?.id,
      customerEmail: invoice?.customer?.email,
      documentData: buildInvoiceDocumentData(invoice),
    })
  }

  const hasWarningIcon =
    !!paymentDisputeLostAt ||
    (!!errorDetails?.length && status !== InvoiceStatusTypeEnum.Failed) ||
    !!taxProviderVoidable

  const headerEntity = {
    viewName: number || '',
    viewNameLoading: isLoading,
    metadata: `${translate('text_634687079be251fdb43833ad', {
      totalAmount: intlFormatNumber(
        deserializeAmount(totalAmountCents || 0, currency || CurrencyEnum.Usd),
        {
          currencyDisplay: 'symbol',
          currency: currency || CurrencyEnum.Usd,
        },
      ),
    })} • ${invoiceId}`,
    metadataLoading: isLoading,
    badges: status
      ? [
          {
            ...(status === InvoiceStatusTypeEnum.Finalized
              ? paymentStatusMapping({ status, paymentStatus })
              : invoiceStatusMapping({ status })),
            endIcon: hasWarningIcon ? ('warning-unfilled' as const) : undefined,
          },
        ]
      : [],
  }

  const headerActions = [
    {
      type: 'dropdown' as const,
      label: translate('text_634687079be251fdb438338f'),
      items: [
        {
          label: translate('text_1724164767403kyknbaw13mg'),
          hidden: !authorizations.canRetryInvoice,
          disabled: !!loadingRetryInvoice,
          onClick: async (closePopper: () => void) => {
            await retryInvoice()
            closePopper()
          },
        },
        {
          label: translate('text_63a41a8eabb9ae67047c1c08'),
          hidden: !authorizations.canFinalizeInvoice,
          onClick: (closePopper: () => void) => {
            finalizeInvoiceRef.current?.openDialog(data?.invoice)
            closePopper()
          },
        },
        {
          label: translate('text_63a41a8eabb9ae67047c1c06'),
          hidden: !authorizations.canFinalizeInvoice,
          disabled: !!loadingRefreshInvoice,
          onClick: (closePopper: () => void) => {
            refreshInvoice()
            closePopper()
          },
        },
        {
          label: translate('text_634687079be251fdb4383395'),
          hidden: !authorizations.canDownloadOnlyPdf,
          disabled: !!loadingInvoiceDownload,
          onClick: async (closePopper: () => void) => {
            await downloadInvoice({
              variables: { input: { id: invoiceId || '' } },
            })
            closePopper()
          },
        },
        {
          label: translate('text_1760447853022ebd47gmqjmp'),
          hidden: !authorizations.canDownloadPdfAndXml,
          disabled: !!loadingInvoiceDownload,
          onClick: async (closePopper: () => void) => {
            await downloadInvoice({
              variables: { input: { id: invoiceId || '' } },
            })
            closePopper()
          },
        },
        {
          label: translate('text_1760447853022hb1hdiprvet'),
          hidden: !authorizations.canDownloadPdfAndXml,
          disabled: !!loadingInvoiceXmlDownload,
          onClick: async (closePopper: () => void) => {
            await downloadInvoiceXml({
              variables: { input: { id: invoiceId || '' } },
            })
            closePopper()
          },
        },
        {
          label: translate('text_1770392315728uyw3zhs7kzh'),
          hidden: !authorizations.canResendEmail,
          onClick: (closePopper: () => void) => {
            resendEmail()
            closePopper()
          },
        },
        {
          label: translate('text_636bdef6565341dcb9cfb127'),
          hidden: !authorizations.canIssueCreditNote,
          disabled: isPremium ? disabledIssueCreditNoteButton : false,
          endIcon: isPremium ? undefined : ('sparkles' as const),
          tooltip:
            isPremium && disabledIssueCreditNoteButtonLabel
              ? translate(disabledIssueCreditNoteButtonLabel)
              : undefined,
          onClick: (closePopper: () => void) => {
            if (isPremium) {
              navigate(
                generatePath(CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE, {
                  customerId: customerId as string,
                  invoiceId: invoiceId as string,
                }),
              )
            } else {
              openPremiumWarningDialog()
            }
            closePopper()
          },
        },
        {
          label: translate('text_1737471851634wpeojigr27w'),
          hidden: !authorizations.canRecordPayment,
          endIcon: isPremium ? undefined : ('sparkles' as const),
          onClick: (closePopper: () => void) => {
            if (isPremium) {
              navigate(
                generatePath(CREATE_INVOICE_PAYMENT_ROUTE, {
                  invoiceId: invoiceId as string,
                }),
              )
            } else {
              openPremiumWarningDialog()
            }
            closePopper()
          },
        },
        {
          label: translate('text_634687079be251fdb438339b'),
          onClick: (closePopper: () => void) => {
            copyToClipboard(invoiceId || '')

            addToast({
              severity: 'info',
              translateKey: 'text_6253f11816f710014600ba1f',
            })
            closePopper()
          },
        },
        {
          label: translate('text_1753384709668qrxbzpbskn8'),
          hidden: !authorizations.canGeneratePaymentUrl,
          onClick: async (closePopper: () => void) => {
            await generatePaymentUrl({
              variables: { input: { invoiceId: invoiceId as string } },
            })
            closePopper()
          },
        },
        {
          label: translate('text_63eba8c65a6c8043feee2a01'),
          hidden: !authorizations.canUpdatePaymentStatus,
          onClick: (closePopper: () => void) => {
            if (invoice) {
              openUpdateInvoicePaymentStatusDialog(invoice)
            }
            closePopper()
          },
        },
        {
          label: translate('text_1739289860782ljvy21lcake'),
          hidden: !authorizations.canUpdatePaymentStatus,
          onClick: (closePopper: () => void) => {
            addMetadataDrawerDialogRef.current?.openDrawer()
            closePopper()
          },
        },
        {
          label: translate(
            customer?.netsuiteCustomer
              ? 'text_6650b36fc702a4014c8788fd'
              : 'text_6690ef918777230093114d90',
          ),
          hidden: !authorizations.canSyncAccountingIntegration,
          disabled: loadingSyncIntegrationInvoice,
          onClick: async (closePopper: () => void) => {
            await syncIntegrationInvoice()
            closePopper()
          },
        },
        {
          label: translate('text_1729611609136sul07rowhfi'),
          hidden: !authorizations.canSyncCRMIntegration,
          disabled: loadingSyncHubspotIntegrationInvoice,
          onClick: async (closePopper: () => void) => {
            await syncHubspotIntegrationInvoice()
            closePopper()
          },
        },
        {
          label: translate('text_66141e30699a0631f0b2ec71'),
          hidden: !authorizations.canDispute,
          onClick: (closePopper: () => void) => {
            openDisputeInvoiceDialog({
              id: data?.invoice?.id || '',
            })
            closePopper()
          },
        },
        {
          label: invoice?.customer?.deletedAt
            ? translate('text_65269b43d4d2b15dd929a259')
            : translate('text_1750678506388d4fr5etxbhh'),
          hidden: !authorizations.canVoid,
          onClick: (closePopper: () => void) => {
            if (customerId && invoiceId) {
              navigate(
                generatePath(CUSTOMER_INVOICE_VOID_ROUTE, {
                  customerId,
                  invoiceId,
                }),
              )
            }
            closePopper()
          },
        },
        {
          label: translate('text_1750678506388oynw9hd01l9'),
          hidden: !authorizations.canRegenerate,
          onClick: (closePopper: () => void) => {
            if (customerId && invoiceId) {
              navigate(regeneratePath(data?.invoice as Invoice))
            }
            closePopper()
          },
        },
        {
          label: translate(
            !!customer?.avalaraCustomer
              ? 'text_17476469985998lthq87gwaq'
              : 'text_1724702284063xef0c9kyhyl',
          ),
          hidden: !authorizations.canSyncTaxIntegration,
          disabled: loadingRetryTaxProviderVoiding,
          onClick: async (closePopper: () => void) => {
            await retryTaxProviderVoiding()
            closePopper()
          },
        },
      ],
    },
  ]

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[{ label: translate('text_63ac86d797f728a87b2f9f85'), path: INVOICES_ROUTE }]}
        entity={headerEntity}
        actions={{ items: headerActions, loading: isLoading }}
        tabs={tabsOptions}
      />

      {!!errorMessage && (
        <Alert fullWidth className="md:px-12" type="warning">
          <Stack>
            <Typography variant="body" color="grey700">
              {translate('text_1724165657161stcilcabm7x')}
            </Typography>

            <Typography variant="caption">{translate(errorMessage)}</Typography>
          </Stack>
        </Alert>
      )}
      {!errorMessage && taxStatus === InvoiceTaxStatusTypeEnum.Pending && (
        <Alert fullWidth className="md:px-12" type="info">
          <div className="flex flex-col">
            <Typography variant="body" color="grey700">
              {translate('text_1735045451930tezr0et3e6l')}
            </Typography>

            <Typography variant="caption" color="grey600">
              {translate('text_1735045451931zfgc6yvvcfm')}
            </Typography>
          </div>
        </Alert>
      )}
      {hasError ? (
        <GenericPlaceholder
          title={translate('text_634812d6f16b31ce5cbf4111')}
          subtitle={translate('text_634812d6f16b31ce5cbf411f')}
          buttonTitle={translate('text_634812d6f16b31ce5cbf4123')}
          buttonVariant="primary"
          buttonAction={() => location.reload()}
          image={<ErrorImage width="136" height="104" />}
        />
      ) : (
        <DetailsPage.Container>{activeTabContent}</DetailsPage.Container>
      )}

      <FinalizeInvoiceDialog ref={finalizeInvoiceRef} />
      {!!invoice && <AddMetadataDrawer ref={addMetadataDrawerDialogRef} invoiceId={invoice.id} />}
    </>
  )
}

export default CustomerInvoiceDetails
