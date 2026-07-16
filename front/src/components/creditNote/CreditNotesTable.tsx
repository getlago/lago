import { ApolloError, gql, LazyQueryHookOptions } from '@apollo/client'
import { generatePath } from 'react-router-dom'

import CreditNoteBadge from '~/components/creditNote/CreditNoteBadge'
import { useVoidCreditNoteDialog } from '~/components/customers/creditNotes/VoidCreditNoteDialog'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table, TableColumn, TableContainerSize } from '~/components/designSystem/Table/Table'
import { ActionItem } from '~/components/designSystem/Table/types'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { buildCreditNoteDocumentData } from '~/components/emails/buildDocumentData'
import { addToast, envGlobalVar } from '~/core/apolloClient'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { ResponsiveStyleValue } from '~/core/utils/responsiveProps'
import {
  BillingEntityEmailSettingsEnum,
  CreditNoteForVoidCreditNoteDialogFragmentDoc,
  CreditNoteTableItemFragment,
  GetCreditNotesListQuery,
  TimezoneEnum,
  useDownloadCreditNoteMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDownloadFile } from '~/hooks/useDownloadFile'
import { usePermissions } from '~/hooks/usePermissions'
import { useResendEmailDialog } from '~/hooks/useResendEmailDialog'

const { disablePdfGeneration } = envGlobalVar()

gql`
  fragment CreditNoteTableItem on CreditNote {
    id
    number
    totalAmountCents
    refundAmountCents
    creditAmountCents
    offsetAmountCents
    currency
    createdAt
    canBeVoided
    voidedAt
    taxProviderSyncable
    errorDetails {
      id
      errorCode
      errorDetails
    }
    invoice {
      id
      number
      customer {
        id
        name
        displayName
        applicableTimezone
      }
    }
    billingEntity {
      id
      name
      code
      email
      einvoicing
      emailSettings
    }
    customer {
      id
      email
    }
  }

  fragment CreditNotesForTable on CreditNoteCollection {
    metadata {
      currentPage
      totalPages
      totalCount
    }
    collection {
      id
      ...CreditNoteTableItem
    }
  }

  mutation downloadCreditNote($input: DownloadCreditNoteInput!) {
    downloadCreditNote(input: $input) {
      id
      fileUrl
    }
  }

  ${CreditNoteForVoidCreditNoteDialogFragmentDoc}
`

type TCreditNoteTableProps = {
  creditNotes: GetCreditNotesListQuery['creditNotes']['collection'] | undefined
  error: ApolloError | undefined
  fetchMore: (options: {
    variables: { page: number }
  }) => Promise<{ data?: GetCreditNotesListQuery }>
  isLoading: boolean
  metadata: GetCreditNotesListQuery['creditNotes']['metadata'] | undefined
  variables: LazyQueryHookOptions['variables'] | undefined
  customerTimezone?: TimezoneEnum
  tableContainerSize?: ResponsiveStyleValue<TableContainerSize>
}

const CreditNotesTable = ({
  creditNotes,
  fetchMore,
  isLoading,
  metadata,
  variables,
  customerTimezone,
  error,
  tableContainerSize,
}: TCreditNoteTableProps) => {
  const { translate } = useInternationalization()
  const { openVoidCreditNoteDialog } = useVoidCreditNoteDialog()
  const { hasPermissions } = usePermissions()
  const { showResendEmailDialog } = useResendEmailDialog()

  const { handleDownloadFile } = useDownloadFile()

  const [downloadCreditNote, { loading: loadingCreditNoteDownload }] =
    useDownloadCreditNoteMutation({
      onCompleted({ downloadCreditNote: data }) {
        handleDownloadFile(data?.fileUrl)
      },
    })

  const showCustomerName = !customerTimezone

  const hasNonSearchFilter = !!variables?.currency || !!variables?.billingEntityIds?.length

  let emptyState: { title: string; subtitle: string }

  if (variables?.searchTerm) {
    emptyState = {
      title: translate('text_63c6edd80c57d0dfaae389a4'),
      subtitle: translate('text_63c6edd80c57d0dfaae389a8'),
    }
  } else if (hasNonSearchFilter) {
    emptyState = {
      title: translate('text_6663014df0a6be0098264dd9'),
      subtitle: translate('text_66ab48ea4ed9cd01084c60b8'),
    }
  } else {
    emptyState = {
      title: translate('text_6663014df0a6be0098264dd9'),
      subtitle: translate('text_6663014df0a6be0098264dda'),
    }
  }

  return (
    <div className="border-t border-grey-300">
      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } = metadata || {}

          currentPage < totalPages &&
            !isLoading &&
            fetchMore({
              variables: { page: currentPage + 1 },
            })
        }}
      >
        <Table
          name="credit-notes-list"
          data={creditNotes || []}
          containerSize={
            tableContainerSize || {
              default: 0,
            }
          }
          isLoading={isLoading}
          hasError={!!error}
          placeholder={{ emptyState }}
          actionColumnTooltip={(creditNote) =>
            translate(
              creditNote.canBeVoided && hasPermissions(['creditNotesVoid'])
                ? 'text_63728c6434e1344aea76347d'
                : 'text_63728c6434e1344aea76347f',
            )
          }
          actionColumn={(creditNote) => {
            let actions: ActionItem<CreditNoteTableItemFragment>[] = []

            const canDownload = hasPermissions(['creditNotesView']) && !disablePdfGeneration
            const canVoid = creditNote.canBeVoided && hasPermissions(['creditNotesVoid'])
            const canResendEmail =
              hasPermissions(['creditNotesSend']) &&
              !!creditNote?.billingEntity?.emailSettings?.includes(
                BillingEntityEmailSettingsEnum.CreditNoteCreated,
              )

            actions = [
              ...actions,
              {
                startIcon: 'duplicate',
                title: translate('text_636d12ce54c41fccdf0ef731'),
                onAction: async ({ id }: { id: string }) => {
                  copyToClipboard(id)

                  addToast({
                    severity: 'info',
                    translateKey: 'text_63720bd734e1344aea75b82d',
                  })
                },
              },
            ]

            if (canDownload) {
              actions = [
                ...actions,
                {
                  startIcon: 'download',
                  title: translate('text_636d12ce54c41fccdf0ef72d'),
                  disabled: loadingCreditNoteDownload,
                  onAction: async ({ id }: { id: string }) => {
                    await downloadCreditNote({
                      variables: { input: { id } },
                    })
                  },
                },
              ]
            }

            if (canResendEmail) {
              actions = [
                ...actions,
                {
                  startIcon: 'at',
                  title: translate('text_1770392315728uyw3zhs7kzh'),
                  onAction: async () => {
                    showResendEmailDialog({
                      subject: translate('text_17706311399872btwgaui8va', {
                        organization: creditNote?.billingEntity.name,
                        creditNoteNumber: creditNote?.number,
                      }),
                      type: BillingEntityEmailSettingsEnum.CreditNoteCreated,
                      billingEntity: creditNote?.billingEntity,
                      documentId: creditNote?.id,
                      customerEmail: creditNote?.customer?.email,
                      documentData: buildCreditNoteDocumentData(creditNote),
                    })
                  },
                },
              ]
            }

            if (canVoid) {
              actions = [
                ...actions,
                {
                  startIcon: 'stop',
                  title: translate('text_636d12ce54c41fccdf0ef72f'),
                  onAction: async ({ id, totalAmountCents, currency }) => {
                    openVoidCreditNoteDialog({
                      id,
                      totalAmountCents,
                      currency,
                    })
                  },
                },
              ]
            }

            return actions
          }}
          onRowActionLink={(creditNote) =>
            generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE, {
              customerId: creditNote?.invoice?.customer?.id as string,
              invoiceId: creditNote?.invoice?.id as string,
              creditNoteId: creditNote?.id as string,
            })
          }
          columns={[
            {
              key: 'totalAmountCents',
              title: translate('text_1727078012568v9460bmnh8a'),
              content: (creditNote) => <CreditNoteBadge creditNote={creditNote} />,
            },
            {
              key: 'billingEntity.name',
              title: translate('text_17436114971570doqrwuwhf0'),
              content: ({ billingEntity }) => (
                <Typography variant="body" noWrap>
                  {billingEntity?.name || billingEntity?.code || '-'}
                </Typography>
              ),
            },
            {
              key: 'number',
              title: translate('text_64188b3d9735d5007d71227f'),
              minWidth: 160,
              content: ({ number }) => (
                <TypographyWithCopy compact noWrap variant="body">
                  {number}
                </TypographyWithCopy>
              ),
            },
            {
              key: 'totalAmountCents',
              title: translate('text_62544c1db13ca10187214d85'),
              content: ({ totalAmountCents, currency }) => (
                <Typography
                  className="font-medium"
                  variant="body"
                  color={showCustomerName ? 'grey700' : 'success600'}
                  align="right"
                  noWrap
                >
                  {intlFormatNumber(deserializeAmount(totalAmountCents || 0, currency), {
                    currencyDisplay: 'symbol',
                    currency,
                  })}
                </Typography>
              ),
              maxSpace: !showCustomerName,
              textAlign: 'right',
            },
            ...(showCustomerName
              ? [
                  {
                    key: 'invoice.customer.displayName',
                    title: translate('text_63ac86d797f728a87b2f9fb3'),
                    content: (creditNote: CreditNoteTableItemFragment) => (
                      <Typography variant="body" color="grey600" noWrap>
                        {creditNote.invoice?.customer.displayName}
                      </Typography>
                    ),
                    maxSpace: true,
                    tdCellClassName: 'hidden md:table-cell',
                  } as TableColumn<CreditNoteTableItemFragment>,
                ]
              : []),
            {
              key: 'createdAt',
              title: translate('text_62544c1db13ca10187214d7f'),
              content: ({ createdAt }) => (
                <Typography variant="body" color="grey600" noWrap>
                  {
                    intlFormatDateTime(createdAt, {
                      timezone: customerTimezone,
                    }).date
                  }
                </Typography>
              ),
            },
          ]}
        />
      </InfiniteScroll>
    </div>
  )
}

export default CreditNotesTable
