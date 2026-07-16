import { gql } from '@apollo/client'
import { useMemo, useRef } from 'react'
import { useSearchParams } from 'react-router-dom'

import {
  AvailableFiltersEnum,
  AvailableQuickFilters,
  Filters,
  formatFiltersForInvoiceQuery,
  isOutstandingUrlParams,
} from '~/components/designSystem/Filters'
import { ExportDialog, ExportDialogRef, ExportValues } from '~/components/exports/ExportDialog'
import {
  FinalizeInvoiceDialog,
  FinalizeInvoiceDialogRef,
} from '~/components/invoices/FinalizeInvoiceDialog'
import InvoicesList from '~/components/invoices/InvoicesList'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SearchInput } from '~/components/SearchInput'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { INVOICE_LIST_FILTER_PREFIX } from '~/core/constants/filters'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  type DataExportInvoiceFiltersInput,
  InvoiceExportTypeEnum,
  InvoiceListItemFragmentDoc,
  InvoiceStatusTypeEnum,
  LagoApiError,
  PremiumIntegrationTypeEnum,
  useCreateInvoicesDataExportMutation,
  useGetInvoicesListLazyQuery,
  useRetryAllInvoicePaymentsMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query getInvoicesList(
    $currency: CurrencyEnum
    $customerExternalId: String
    $invoiceType: [InvoiceTypeEnum!]
    $issuingDateFrom: ISO8601Date
    $issuingDateTo: ISO8601Date
    $limit: Int
    $page: Int
    $partiallyPaid: Boolean
    $paymentDisputeLost: Boolean
    $paymentOverdue: Boolean
    $paymentStatus: [InvoicePaymentStatusTypeEnum!]
    $searchTerm: String
    $settlements: [InvoiceSettlementTypeEnum!]
    $status: [InvoiceStatusTypeEnum!]
    $amountFrom: Int
    $amountTo: Int
    $selfBilled: Boolean
    $billingEntityIds: [ID!]
  ) {
    invoices(
      currency: $currency
      customerExternalId: $customerExternalId
      invoiceType: $invoiceType
      issuingDateFrom: $issuingDateFrom
      issuingDateTo: $issuingDateTo
      limit: $limit
      page: $page
      partiallyPaid: $partiallyPaid
      paymentDisputeLost: $paymentDisputeLost
      paymentOverdue: $paymentOverdue
      paymentStatus: $paymentStatus
      searchTerm: $searchTerm
      settlements: $settlements
      status: $status
      amountFrom: $amountFrom
      amountTo: $amountTo
      selfBilled: $selfBilled
      billingEntityIds: $billingEntityIds
    ) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        id
        ...InvoiceListItem
      }
    }
  }

  mutation retryAllInvoicePayments($input: RetryAllInvoicePaymentsInput!) {
    retryAllInvoicePayments(input: $input) {
      metadata {
        totalCount
      }
    }
  }

  mutation createInvoicesDataExport($input: CreateDataExportsInvoicesInput!) {
    createInvoicesDataExport(input: $input) {
      id
    }
  }

  ${InvoiceListItemFragmentDoc}
`

// TODO: This is a temporary workaround
const formatAmountCurrency = <T extends { amountFrom?: unknown; amountTo?: unknown }>(
  filters: T,
  amountCurrency?: CurrencyEnum | null,
): T => {
  const _filters = { ...filters } as T

  if (_filters.amountFrom) {
    _filters.amountFrom = serializeAmount(
      Number(_filters.amountFrom),
      amountCurrency || CurrencyEnum.Usd,
    ) as T['amountFrom']
  }

  if (_filters.amountTo) {
    _filters.amountTo = serializeAmount(
      Number(_filters.amountTo),
      amountCurrency || CurrencyEnum.Usd,
    ) as T['amountTo']
  }

  return _filters
}

const InvoicesPage = () => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { organization, hasOrganizationPremiumAddon } = useOrganizationInfos()
  const [searchParams] = useSearchParams()
  const amountCurrency = organization?.defaultCurrency

  const hasAccessToRevenueShare = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.RevenueShare,
  )

  const finalizeInvoiceRef = useRef<FinalizeInvoiceDialogRef>(null)
  const exportInvoicesDialogRef = useRef<ExportDialogRef>(null)

  const filtersForInvoiceQuery = useMemo(() => {
    return formatFiltersForInvoiceQuery(searchParams)
  }, [searchParams])

  const [getInvoices, { data, loading, error, fetchMore, variables }] = useGetInvoicesListLazyQuery(
    {
      notifyOnNetworkStatusChange: true,
      fetchPolicy: 'network-only',
      nextFetchPolicy: 'network-only',
      variables: {
        limit: 20,
        status: [
          InvoiceStatusTypeEnum.Draft,
          InvoiceStatusTypeEnum.Failed,
          InvoiceStatusTypeEnum.Finalized,
          InvoiceStatusTypeEnum.Voided,
          InvoiceStatusTypeEnum.Pending,
        ],
        ...formatAmountCurrency(filtersForInvoiceQuery, amountCurrency),
      },
    },
  )

  const { debouncedSearch: invoiceDebounceSearch, isLoading: invoiceIsLoading } =
    useDebouncedSearch(getInvoices, loading)

  const [retryAll] = useRetryAllInvoicePaymentsMutation({
    context: { silentErrorCodes: [LagoApiError.PaymentProcessorIsCurrentlyHandlingPayment] },
    onCompleted({ retryAllInvoicePayments }) {
      if (retryAllInvoicePayments) {
        addToast({
          severity: 'success',
          translateKey: 'text_63ac86d897f728a87b2fa0a7',
        })
      }
    },
  })

  const onInvoicesExport = async (values: ExportValues<InvoiceExportTypeEnum>) => {
    const filters = {
      ...formatAmountCurrency(formatFiltersForInvoiceQuery(searchParams), amountCurrency),
      searchTerm: variables?.searchTerm,
    } as DataExportInvoiceFiltersInput

    const res = await triggerCreateInvoicesDataExport({
      variables: {
        input: {
          ...values,
          filters,
        },
      },
    })

    if (res.errors) return
  }

  const [triggerCreateInvoicesDataExport] = useCreateInvoicesDataExportMutation({
    onCompleted({ createInvoicesDataExport }) {
      if (createInvoicesDataExport) {
        addToast({
          message: translate('text_66b323b63e76c400f78cd342'),
          severity: 'info',
        })
      }
    },
  })

  const invoicesTotalCount = data?.invoices?.metadata?.totalCount

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_63ac86d797f728a87b2f9f85'),
          metadata: formatCountToMetadata(invoicesTotalCount, translate),
          metadataLoading: invoiceIsLoading,
        }}
        actions={{
          loading: invoiceIsLoading,
          items: [
            {
              type: 'action',
              label: translate('text_66b21236c939426d07ff98ca'),
              variant: 'secondary',
              disabled: !invoicesTotalCount,
              onClick: () => {
                exportInvoicesDialogRef.current?.openDialog()
              },
            },
            {
              type: 'action',
              label: translate('text_63ac86d797f728a87b2f9fc4'),
              variant: 'primary',
              hidden:
                !isOutstandingUrlParams({ searchParams, prefix: INVOICE_LIST_FILTER_PREFIX }) ||
                !hasPermissions(['invoicesSend']),
              disabled: !invoicesTotalCount,
              onClick: async () => {
                const { errors } = await retryAll({ variables: { input: {} } })

                if (hasDefinedGQLError('PaymentProcessorIsCurrentlyHandlingPayment', errors)) {
                  addToast({
                    severity: 'info',
                    translateKey: 'text_63b6d06df1a53b7e2ad973ad',
                  })
                }
              },
            },
          ],
        }}
        filtersSection={
          <Filters.Provider
            filtersNamePrefix={INVOICE_LIST_FILTER_PREFIX}
            quickFiltersType={AvailableQuickFilters.invoiceStatus}
            availableFilters={[
              AvailableFiltersEnum.amount,
              AvailableFiltersEnum.billingEntityIds,
              AvailableFiltersEnum.status,
              AvailableFiltersEnum.invoiceType,
              AvailableFiltersEnum.paymentStatus,
              AvailableFiltersEnum.currency,
              AvailableFiltersEnum.issuingDate,
              AvailableFiltersEnum.customerExternalId,
              AvailableFiltersEnum.paymentDisputeLost,
              AvailableFiltersEnum.paymentOverdue,
              AvailableFiltersEnum.settlementType,
              ...(hasAccessToRevenueShare ? [AvailableFiltersEnum.selfBilled] : []),
            ]}
          >
            <div className="flex flex-col gap-4">
              <Filters.QuickFilters />
              <div className="flex flex-col gap-3 md:flex-row md:items-center">
                <SearchInput
                  onChange={invoiceDebounceSearch}
                  placeholder={translate('text_63c68131568d582a38233e84')}
                />
                <Filters.Component />
              </div>
            </div>
          </Filters.Provider>
        }
      />

      <InvoicesList
        error={error}
        fetchMore={fetchMore}
        invoices={data?.invoices?.collection}
        isLoading={invoiceIsLoading}
        metadata={data?.invoices?.metadata}
        variables={variables}
      />

      <FinalizeInvoiceDialog ref={finalizeInvoiceRef} />
      <ExportDialog
        ref={exportInvoicesDialogRef}
        totalCountLabel={translate(
          'text_66b21236c939426d07ff9937',
          { invoicesTotalCount },
          invoicesTotalCount,
        )}
        onExport={onInvoicesExport}
        disableExport={invoicesTotalCount === 0}
        resourceTypeOptions={[
          {
            label: translate('text_66b21236c939426d07ff993b'),
            sublabel: translate('text_66b21236c939426d07ff993c'),
            value: InvoiceExportTypeEnum.Invoices,
          },
          {
            label: translate('text_66b21236c939426d07ff993d'),
            sublabel: translate('text_66b21236c939426d07ff993e'),
            value: InvoiceExportTypeEnum.InvoiceFees,
          },
        ]}
      />
    </>
  )
}

export default InvoicesPage
