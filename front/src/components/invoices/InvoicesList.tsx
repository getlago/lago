import { ApolloError, LazyQueryHookOptions } from '@apollo/client'
import { IconName } from 'lago-design-system'
import { useMemo, useRef } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { createCreditNoteForInvoiceButtonProps } from '~/components/creditNote/utils'
import { GenericPlaceholderProps } from '~/components/designSystem/GenericPlaceholder'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { ActionItem } from '~/components/designSystem/Table/types'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { buildInvoiceDocumentData } from '~/components/emails/buildDocumentData'
import { useUpdateInvoicePaymentStatusDialog } from '~/components/invoices/EditInvoicePaymentStatusDialog'
import {
  FinalizeInvoiceDialog,
  FinalizeInvoiceDialogRef,
} from '~/components/invoices/FinalizeInvoiceDialog'
import {
  ResendInvoiceForCollectionDialog,
  ResendInvoiceForCollectionDialogRef,
} from '~/components/invoices/ResendInvoiceForCollectionDialog'
import { getEmptyStateConfig } from '~/components/invoices/utils/emptyStateMapping'
import { getMostRecentPaymentMethodId } from '~/components/invoices/utils/getMostRecentPaymentMethodId'
import { addToast } from '~/core/apolloClient'
import {
  invoiceStatusMapping,
  isInvoicePartiallyPaid,
  paymentStatusMapping,
} from '~/core/constants/statusInvoiceMapping'
import { CustomerInvoiceDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  CREATE_INVOICE_PAYMENT_ROUTE,
  CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE,
  CUSTOMER_INVOICE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_VOID_ROUTE,
  useNavigate,
} from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { regeneratePath } from '~/core/utils/regenerateUtils'
import {
  BillingEntityEmailSettingsEnum,
  CurrencyEnum,
  GetInvoicesListQuery,
  GetInvoicesListQueryResult,
  Invoice,
  InvoiceStatusTypeEnum,
  useDownloadInvoiceItemMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useDownloadFile } from '~/hooks/useDownloadFile'
import { useGeneratePaymentUrl } from '~/hooks/useGeneratePaymentUrl'
import { usePermissionsInvoiceActions } from '~/hooks/usePermissionsInvoiceActions'
import { useResendEmailDialog } from '~/hooks/useResendEmailDialog'

type TInvoiceListProps = {
  error: ApolloError | undefined
  fetchMore: GetInvoicesListQueryResult['fetchMore']
  invoices: GetInvoicesListQuery['invoices']['collection'] | undefined
  isLoading: boolean
  metadata: GetInvoicesListQuery['invoices']['metadata'] | undefined
  variables: LazyQueryHookOptions['variables'] | undefined
}

type InvoiceItem = GetInvoicesListQuery['invoices']['collection'][number]

const InvoicesList = ({
  error,
  fetchMore,
  invoices,
  isLoading,
  metadata,
  variables,
}: TInvoiceListProps) => {
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const actions = usePermissionsInvoiceActions()
  const { showResendEmailDialog } = useResendEmailDialog()

  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()

  const { handleDownloadFile } = useDownloadFile()

  const finalizeInvoiceRef = useRef<FinalizeInvoiceDialogRef>(null)
  const { openUpdateInvoicePaymentStatusDialog } = useUpdateInvoicePaymentStatusDialog()
  const resendInvoiceForCollectionDialogRef = useRef<ResendInvoiceForCollectionDialogRef>(null)

  const [downloadInvoice] = useDownloadInvoiceItemMutation({
    onCompleted({ downloadInvoice: data }) {
      handleDownloadFile(data?.fileUrl)
    },
  })

  const { generatePaymentUrl } = useGeneratePaymentUrl()

  const emptyState = getEmptyStateConfig({
    hasSearchTerm: !!variables?.searchTerm,
    searchParams,
    translate,
  })

  const errorState: Partial<GenericPlaceholderProps> = useMemo(() => {
    if (variables?.searchTerm) {
      return {
        title: translate('text_623b53fea66c76017eaebb6e'),
        subtitle: translate('text_63bab307a61c62af497e0599'),
      }
    }

    return {
      title: translate('text_63ac86d797f728a87b2f9fea'),
      subtitle: translate('text_63ac86d797f728a87b2f9ff2'),
      buttonTitle: translate('text_63ac86d797f728a87b2f9ffa'),
      buttonAction: () => location.reload(),
      buttonVariant: 'primary',
    }
  }, [variables?.searchTerm, translate])

  const createRecordPaymentAction = (invoice: InvoiceItem): ActionItem<InvoiceItem> | null => {
    if (!actions.canRecordPayment(invoice)) return null

    return {
      startIcon: 'receipt',
      title: translate('text_1737471851634wpeojigr27w'),
      endIcon: isPremium ? undefined : 'sparkles',
      onAction: ({ id }) => {
        if (isPremium) {
          navigate(generatePath(CREATE_INVOICE_PAYMENT_ROUTE, { invoiceId: id }))
        } else {
          openPremiumWarningDialog()
        }
      },
    }
  }

  const createIssueCreditNoteAction = (
    invoice: InvoiceItem,
    isPartiallyPaid: boolean,
    isDisabledIssueCreditNoteButton: boolean,
    disabledIssueCreditNoteButtonLabel: string | false,
  ): ActionItem<InvoiceItem> | null => {
    if (!actions.canIssueCreditNote(invoice)) return null

    if (!isPremium) {
      return {
        startIcon: 'document',
        endIcon: 'sparkles',
        title: translate('text_636bdef6565341dcb9cfb127'),
        onAction: () => {
          openPremiumWarningDialog()
        },
      }
    }

    return {
      startIcon: 'document',
      title: translate('text_636bdef6565341dcb9cfb127'),
      disabled: isDisabledIssueCreditNoteButton,
      onAction: () => {
        navigate(
          generatePath(CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE, {
            customerId: invoice?.customer?.id,
            invoiceId: invoice.id,
          }),
        )
      },
      tooltip: disabledIssueCreditNoteButtonLabel
        ? translate(disabledIssueCreditNoteButtonLabel)
        : undefined,
    }
  }

  const getActionsForActionsColumn = ({
    invoice,
    hasActiveWallet,
    isPartiallyPaid,
    isDisabledIssueCreditNoteButton,
    disabledIssueCreditNoteButtonLabel,
  }: {
    invoice: InvoiceItem
    hasActiveWallet: boolean
    isPartiallyPaid: boolean
    isDisabledIssueCreditNoteButton: boolean
    disabledIssueCreditNoteButtonLabel: string | false
  }): Array<ActionItem<InvoiceItem>> => {
    const downloadAction: ActionItem<InvoiceItem> | null = actions.canDownload(invoice)
      ? {
          startIcon: 'download',
          title: translate('text_62b31e1f6a5b8b1b745ece42'),
          onAction: async ({ id }) => {
            await downloadInvoice({
              variables: { input: { id } },
            })
          },
        }
      : null

    const resendEmailAction: ActionItem<InvoiceItem> | null = actions.canResendEmail(invoice)
      ? {
          startIcon: 'at',
          title: translate('text_1770392315728uyw3zhs7kzh'),
          onAction: async () => {
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
          },
        }
      : null

    const finalizeAction: ActionItem<InvoiceItem> | null =
      !actions.canDownload(invoice) && actions.canFinalize(invoice)
        ? {
            startIcon: 'checkmark',
            title: translate('text_63a41a8eabb9ae67047c1c08'),
            onAction: (item) => {
              finalizeInvoiceRef.current?.openDialog(item)
            },
          }
        : null

    const duplicateAction: ActionItem<InvoiceItem> = {
      startIcon: 'duplicate',
      title: translate('text_63ac86d897f728a87b2fa031'),
      onAction: ({ id }) => {
        copyToClipboard(id)
        addToast({
          severity: 'info',
          translateKey: 'text_63ac86d897f728a87b2fa0b0',
        })
      },
    }

    const recordPaymentAction = createRecordPaymentAction(invoice)

    const retryCollectAction: ActionItem<InvoiceItem> | null = actions.canRetryCollect(invoice)
      ? {
          startIcon: 'push',
          title: translate('text_63ac86d897f728a87b2fa039'),
          onAction: () => {
            resendInvoiceForCollectionDialogRef.current?.openDialog({
              invoice,
              preselectedPaymentMethodId: getMostRecentPaymentMethodId(invoice?.payments),
            })
          },
        }
      : null

    const generatePaymentUrlAction: ActionItem<InvoiceItem> | null = actions.canGeneratePaymentUrl(
      invoice,
    )
      ? {
          startIcon: 'link',
          title: translate('text_1753384709668qrxbzpbskn8'),
          onAction: async ({ id }) => {
            await generatePaymentUrl({ variables: { input: { invoiceId: id } } })
          },
        }
      : null

    const updatePaymentStatusAction: ActionItem<InvoiceItem> | null =
      actions.canUpdatePaymentStatus(invoice)
        ? {
            startIcon: 'coin-dollar',
            title: translate('text_63eba8c65a6c8043feee2a01'),
            onAction: () => {
              openUpdateInvoicePaymentStatusDialog(invoice)
            },
          }
        : null

    const issueCreditNoteAction = createIssueCreditNoteAction(
      invoice,
      isPartiallyPaid,
      isDisabledIssueCreditNoteButton,
      disabledIssueCreditNoteButtonLabel,
    )

    const voidInvoiceAction: ActionItem<InvoiceItem> | null = actions.canVoid(invoice)
      ? {
          startIcon: 'stop',
          title: invoice?.customer?.deletedAt
            ? translate('text_65269b43d4d2b15dd929a259')
            : translate('text_1750678506388d4fr5etxbhh'),
          onAction: () =>
            navigate(
              generatePath(CUSTOMER_INVOICE_VOID_ROUTE, {
                customerId: invoice?.customer?.id,
                invoiceId: invoice.id,
              }),
            ),
        }
      : null

    const regenerateAction: ActionItem<InvoiceItem> | null = actions.canRegenerate(
      invoice,
      hasActiveWallet,
    )
      ? {
          startIcon: 'stop',
          title: translate('text_1750678506388oynw9hd01l9'),
          onAction: () => navigate(regeneratePath(invoice as Invoice)),
        }
      : null

    return [
      duplicateAction,
      downloadAction,
      finalizeAction,
      resendEmailAction,
      recordPaymentAction,
      retryCollectAction,
      generatePaymentUrlAction,
      updatePaymentStatusAction,
      issueCreditNoteAction,
      voidInvoiceAction,
      regenerateAction,
    ].filter(Boolean) as Array<ActionItem<InvoiceItem>>
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
          name="invoices-list"
          data={invoices || []}
          containerSize={{
            default: 16,
            md: 48,
          }}
          isLoading={isLoading}
          hasError={!!error}
          actionColumn={(invoice) => {
            const { disabledIssueCreditNoteButton, disabledIssueCreditNoteButtonLabel } =
              createCreditNoteForInvoiceButtonProps({
                invoiceType: invoice?.invoiceType,
                creditableAmountCents: invoice?.creditableAmountCents,
                refundableAmountCents: invoice?.refundableAmountCents,
                offsettableAmountCents: invoice?.offsettableAmountCents,
                associatedActiveWalletPresent: invoice?.associatedActiveWalletPresent,
              })

            const isPartiallyPaid = isInvoicePartiallyPaid(
              invoice.totalPaidAmountCents,
              invoice.totalDueAmountCents,
            )

            const hasActiveWallet = invoice?.customer?.hasActiveWallet || false

            return getActionsForActionsColumn({
              invoice,
              hasActiveWallet,
              isPartiallyPaid,
              isDisabledIssueCreditNoteButton: disabledIssueCreditNoteButton,
              disabledIssueCreditNoteButtonLabel,
            })
          }}
          columns={[
            {
              key: 'status',
              title: translate('text_63ac86d797f728a87b2f9fa7'),
              minWidth: 80,
              content: ({ status, errorDetails, taxProviderVoidable }) => {
                const showWarningIcon =
                  (!!errorDetails?.length && status !== InvoiceStatusTypeEnum.Failed) ||
                  taxProviderVoidable

                return (
                  <Tooltip
                    placement="top-start"
                    disableHoverListener={!showWarningIcon}
                    title={translate('text_1724674592260h33v56rycaw')}
                  >
                    <Status
                      {...invoiceStatusMapping({ status })}
                      endIcon={showWarningIcon ? 'warning-unfilled' : undefined}
                    />
                  </Tooltip>
                )
              },
            },
            {
              key: 'billingEntity.code',
              title: translate('text_17436114971570doqrwuwhf0'),
              content: ({ billingEntity }) => (
                <Typography variant="body" noWrap>
                  {billingEntity.name || billingEntity.code || '-'}
                </Typography>
              ),
            },
            {
              key: 'number',
              title: translate('text_63ac86d797f728a87b2f9fad'),
              minWidth: 160,
              content: ({ number }) =>
                number ? (
                  <TypographyWithCopy compact noWrap variant="body">
                    {number}
                  </TypographyWithCopy>
                ) : (
                  <Typography variant="body" noWrap>
                    -
                  </Typography>
                ),
            },
            {
              key: 'totalAmountCents',
              title: translate('text_63ac86d797f728a87b2f9fb9'),
              textAlign: 'right',
              minWidth: 160,
              content: ({ totalAmountCents, currency, status }) => {
                return (
                  <Typography variant="bodyHl" color="textSecondary" noWrap>
                    {[InvoiceStatusTypeEnum.Failed, InvoiceStatusTypeEnum.Pending].includes(status)
                      ? '-'
                      : intlFormatNumber(
                          deserializeAmount(totalAmountCents, currency || CurrencyEnum.Usd),
                          {
                            currency: currency || CurrencyEnum.Usd,
                          },
                        )}
                  </Typography>
                )
              },
            },
            {
              key: 'totalDueAmountCents',
              title: translate('text_17374735502775afvcm9pqxk'),
              textAlign: 'right',
              minWidth: 160,
              content: ({ totalDueAmountCents, currency }) => (
                <Typography variant="bodyHl" color="textSecondary" noWrap>
                  {intlFormatNumber(
                    deserializeAmount(totalDueAmountCents, currency || CurrencyEnum.Usd),
                    {
                      currency: currency || CurrencyEnum.Usd,
                    },
                  )}
                </Typography>
              ),
            },
            {
              key: 'paymentStatus',
              title: translate('text_6419c64eace749372fc72b40'),
              minWidth: 80,
              content: ({
                status,
                paymentStatus,
                paymentDisputeLostAt,
                totalPaidAmountCents,
                totalDueAmountCents,
              }) => {
                if (status !== InvoiceStatusTypeEnum.Finalized) {
                  return null
                }

                let content: { tooltipTitle?: string; statusEndIcon?: IconName } = {
                  tooltipTitle: undefined,
                  statusEndIcon: undefined,
                }

                const isPartiallyPaid = isInvoicePartiallyPaid(
                  totalPaidAmountCents,
                  totalDueAmountCents,
                )

                if (isPartiallyPaid) {
                  content = {
                    tooltipTitle: translate('text_1738071221799vib0l2z1bxe'),
                    statusEndIcon: 'partially-filled',
                  }
                } else if (!!paymentDisputeLostAt) {
                  content = {
                    tooltipTitle: translate('text_172416478461328edo4vwz05'),
                    statusEndIcon: 'warning-unfilled',
                  }
                }

                return (
                  <Tooltip placement="top" title={content.tooltipTitle}>
                    <Status
                      {...paymentStatusMapping({
                        status,
                        paymentStatus,
                        totalPaidAmountCents,
                        totalDueAmountCents,
                      })}
                      endIcon={content.statusEndIcon}
                    />
                  </Tooltip>
                )
              },
            },
            {
              key: 'paymentOverdue',
              title: translate('text_666c5b12fea4aa1e1b26bf55'),
              content: ({ paymentOverdue }) =>
                paymentOverdue && <Status type={StatusType.danger} label="overdue" />,
            },
            {
              key: 'customer.name',
              title: translate('text_65201c5a175a4b0238abf29a'),
              maxSpace: true,
              minWidth: 160,
              content: ({ customer }) => (
                <Typography variant="body" noWrap>
                  {customer?.displayName || '-'}
                </Typography>
              ),
            },

            {
              key: 'issuingDate',
              title: translate('text_63ac86d797f728a87b2f9fbf'),
              minWidth: 104,
              content: ({ issuingDate, customer }) => (
                <Typography variant="body" noWrap>
                  {intlFormatDateTime(issuingDate, { timezone: customer.applicableTimezone }).date}
                </Typography>
              ),
            },
          ]}
          onRowActionLink={(invoice) =>
            generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
              customerId: invoice?.customer?.id,
              invoiceId: invoice.id,
              tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
            })
          }
          placeholder={{
            errorState,
            emptyState,
          }}
        />
      </InfiniteScroll>

      <FinalizeInvoiceDialog ref={finalizeInvoiceRef} />
      <ResendInvoiceForCollectionDialog ref={resendInvoiceForCollectionDialogRef} />
    </div>
  )
}

export default InvoicesList
