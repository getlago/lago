import { gql } from '@apollo/client'
import { useMemo, useRef } from 'react'
import { useSearchParams } from 'react-router-dom'

import CreditNotesTable from '~/components/creditNote/CreditNotesTable'
import {
  AvailableFiltersEnum,
  Filters,
  formatFiltersForCreditNotesQuery,
} from '~/components/designSystem/Filters'
import { ExportDialog, ExportDialogRef, ExportValues } from '~/components/exports/ExportDialog'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SearchInput } from '~/components/SearchInput'
import { addToast } from '~/core/apolloClient'
import { CREDIT_NOTE_LIST_FILTER_PREFIX } from '~/core/constants/filters'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CreditNoteExportTypeEnum,
  CreditNotesForTableFragmentDoc,
  CreditNoteTableItemFragmentDoc,
  CurrencyEnum,
  type DataExportCreditNoteFiltersInput,
  PremiumIntegrationTypeEnum,
  useCreateCreditNotesDataExportMutation,
  useGetCreditNotesListLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getCreditNotesList(
    $amountFrom: Int
    $amountTo: Int
    $creditStatus: [CreditNoteCreditStatusEnum!]
    $currency: CurrencyEnum
    $customerExternalId: String
    $invoiceNumber: String
    $issuingDateFrom: ISO8601Date
    $issuingDateTo: ISO8601Date
    $reason: [CreditNoteReasonEnum!]
    $refundStatus: [CreditNoteRefundStatusEnum!]
    $types: [CreditNoteTypeEnum!]
    $limit: Int
    $page: Int
    $searchTerm: String
    $selfBilled: Boolean
    $billingEntityIds: [ID!]
  ) {
    creditNotes(
      amountFrom: $amountFrom
      amountTo: $amountTo
      creditStatus: $creditStatus
      currency: $currency
      customerExternalId: $customerExternalId
      invoiceNumber: $invoiceNumber
      issuingDateFrom: $issuingDateFrom
      issuingDateTo: $issuingDateTo
      reason: $reason
      refundStatus: $refundStatus
      types: $types
      limit: $limit
      page: $page
      searchTerm: $searchTerm
      selfBilled: $selfBilled
      billingEntityIds: $billingEntityIds
    ) {
      ...CreditNotesForTable
    }
  }

  mutation createCreditNotesDataExport($input: CreateDataExportsCreditNotesInput!) {
    createCreditNotesDataExport(input: $input) {
      id
    }
  }

  ${CreditNoteTableItemFragmentDoc}
  ${CreditNotesForTableFragmentDoc}
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

const CreditNotesPage = () => {
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()
  const { organization, hasOrganizationPremiumAddon } = useOrganizationInfos()

  const amountCurrency = organization?.defaultCurrency
  const hasAccessToRevenueShare = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.RevenueShare,
  )

  const exportCreditNotesDialogRef = useRef<ExportDialogRef>(null)

  const filtersForCreditNotesQuery = useMemo(() => {
    return formatFiltersForCreditNotesQuery(searchParams)
  }, [searchParams])

  const [
    getCreditNotes,
    {
      data: dataCreditNotes,
      loading: loadingCreditNotes,
      error: errorCreditNotes,
      fetchMore: fetchMoreCreditNotes,
      variables: variableCreditNotes,
    },
  ] = useGetCreditNotesListLazyQuery({
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
    variables: {
      limit: 20,
      ...formatAmountCurrency(filtersForCreditNotesQuery, amountCurrency),
    },
  })

  const { debouncedSearch: creditNoteDebounceSearch, isLoading: creditNoteIsLoading } =
    useDebouncedSearch(getCreditNotes, loadingCreditNotes)

  const [triggerCreateCreditNotesDataExport] = useCreateCreditNotesDataExportMutation({
    onCompleted({ createCreditNotesDataExport }) {
      if (createCreditNotesDataExport) {
        addToast({
          message: translate('text_66b323b63e76c400f78cd342'),
          severity: 'info',
        })
      }
    },
  })

  const onCreditNotesExport = async (values: ExportValues<CreditNoteExportTypeEnum>) => {
    const filters = {
      ...formatAmountCurrency(formatFiltersForCreditNotesQuery(searchParams), amountCurrency),
      searchTerm: variableCreditNotes?.searchTerm,
    } as DataExportCreditNoteFiltersInput

    const res = await triggerCreateCreditNotesDataExport({
      variables: {
        input: {
          ...values,
          filters,
        },
      },
    })

    if (res.errors) return
  }

  const creditNotesTotalCount = dataCreditNotes?.creditNotes?.metadata?.totalCount

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_66461ada56a84401188e8c63'),
          metadata: formatCountToMetadata(creditNotesTotalCount, translate),
          metadataLoading: creditNoteIsLoading,
        }}
        actions={{
          loading: creditNoteIsLoading,
          items: [
            {
              type: 'action',
              label: translate('text_1773761094529kr57s3qq8j3'),
              variant: 'secondary',
              disabled: !dataCreditNotes?.creditNotes?.metadata.totalCount,
              onClick: () => {
                exportCreditNotesDialogRef.current?.openDialog()
              },
            },
          ],
        }}
        filtersSection={
          <Filters.Provider
            filtersNamePrefix={CREDIT_NOTE_LIST_FILTER_PREFIX}
            availableFilters={[
              AvailableFiltersEnum.amount,
              AvailableFiltersEnum.billingEntityIds,
              AvailableFiltersEnum.creditNoteCreditStatus,
              AvailableFiltersEnum.creditNoteType,
              AvailableFiltersEnum.currency,
              AvailableFiltersEnum.customerExternalId,
              AvailableFiltersEnum.invoiceNumber,
              AvailableFiltersEnum.issuingDate,
              AvailableFiltersEnum.creditNoteReason,
              AvailableFiltersEnum.creditNoteRefundStatus,
              ...(hasAccessToRevenueShare ? [AvailableFiltersEnum.selfBilled] : []),
            ]}
          >
            <div className="flex flex-col gap-3 md:flex-row md:items-center">
              <SearchInput
                onChange={creditNoteDebounceSearch}
                placeholder={translate('text_63c6edd80c57d0dfaae3898e')}
              />
              <Filters.Component />
            </div>
          </Filters.Provider>
        }
      />

      <CreditNotesTable
        creditNotes={dataCreditNotes?.creditNotes?.collection}
        error={errorCreditNotes}
        fetchMore={fetchMoreCreditNotes}
        isLoading={creditNoteIsLoading}
        metadata={dataCreditNotes?.creditNotes?.metadata}
        variables={variableCreditNotes}
        tableContainerSize={{
          default: 16,
          md: 48,
        }}
      />

      <ExportDialog
        ref={exportCreditNotesDialogRef}
        totalCountLabel={translate(
          'text_17346987416277yx1mf6nau2',
          { creditNotesTotalCount },
          creditNotesTotalCount,
        )}
        onExport={onCreditNotesExport}
        disableExport={creditNotesTotalCount === 0}
        resourceTypeOptions={[
          {
            label: translate('text_1734698741627bges5xz01la'),
            sublabel: translate('text_173469874162761dxr57rvw7'),
            value: CreditNoteExportTypeEnum.CreditNotes,
          },
          {
            label: translate('text_1734698741627449t5wdghef'),
            sublabel: translate('text_1734698875217ppgrrmd10q2'),
            value: CreditNoteExportTypeEnum.CreditNoteItems,
          },
        ]}
      />
    </>
  )
}

export default CreditNotesPage
