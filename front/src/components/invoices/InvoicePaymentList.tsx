import { FC } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { PaymentProviderChip } from '~/components/PaymentProviderChip'
import { payablePaymentStatusMapping } from '~/core/constants/statusInvoiceMapping'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CREATE_INVOICE_PAYMENT_ROUTE, PAYMENT_DETAILS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { isInvoice, isPaymentRequest } from '~/core/utils/payableUtils'
import { CurrencyEnum, PaymentTypeEnum, useGetPaymentsListQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import useDownloadPaymentReceipts from '~/hooks/paymentReceipts/useDownloadPaymentReceipts'
import { useCurrentUser } from '~/hooks/useCurrentUser'

export const InvoicePaymentList: FC<{
  canRecordPayment: boolean
}> = ({ canRecordPayment }) => {
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const { invoiceId } = useParams()
  const navigate = useNavigate()
  const premiumWarningDialog = usePremiumWarningDialog()

  const { data, loading, error, fetchMore } = useGetPaymentsListQuery({
    variables: { invoiceId: invoiceId as string, limit: 20 },
    skip: !invoiceId,
  })

  const { canDownloadPaymentReceipts, downloadPaymentReceipts } = useDownloadPaymentReceipts()

  const payments = data?.payments.collection || []

  return (
    <>
      <div className="flex h-18 items-center justify-between shadow-b">
        <Typography variant="subhead1">{translate('text_6672ebb8b1b50be550eccbed')}</Typography>
        {canRecordPayment && (
          <Button
            variant="quaternary"
            align="left"
            endIcon={isPremium ? undefined : 'sparkles'}
            onClick={() => {
              if (isPremium) {
                navigate(
                  generatePath(CREATE_INVOICE_PAYMENT_ROUTE, {
                    invoiceId: invoiceId as string,
                  }),
                )
              } else {
                premiumWarningDialog.open()
              }
            }}
          >
            {translate('text_1737471851634wpeojigr27w')}
          </Button>
        )}
      </div>
      {!loading && !payments.length && (
        <Typography className="mt-6" variant="body" color="grey500">
          {translate('text_17380560401785kuvb6m2yfm')}
        </Typography>
      )}
      {!loading && payments.length > 0 && (
        <InfiniteScroll
          onBottom={() => {
            const { currentPage = 0, totalPages = 0 } = data?.payments.metadata || {}

            currentPage < totalPages &&
              !loading &&
              fetchMore?.({ variables: { page: currentPage + 1 } })
          }}
        >
          <Table
            name="payments-list"
            data={payments || []}
            containerSize={{
              default: 0,
            }}
            isLoading={loading}
            hasError={!!error}
            onRowActionLink={(request) =>
              generatePath(PAYMENT_DETAILS_ROUTE, {
                paymentId: request.id,
              })
            }
            actionColumn={({ paymentReceipt }) => {
              return [
                canDownloadPaymentReceipts
                  ? {
                      startIcon: 'download',
                      title: translate('text_1741334392622fl3ozwejrul'),
                      onAction: ({ paymentReceipt: _paymentReceipt }) => {
                        downloadPaymentReceipts({
                          paymentReceiptId: _paymentReceipt?.id,
                        })
                      },
                      disabled: !paymentReceipt?.id,
                    }
                  : null,
              ]
            }}
            columns={[
              {
                key: 'payablePaymentStatus',
                title: translate('text_63ac86d797f728a87b2f9fa7'),
                minWidth: 80,
                content: ({ payablePaymentStatus }) => (
                  <Status
                    {...payablePaymentStatusMapping({
                      payablePaymentStatus: payablePaymentStatus ?? undefined,
                    })}
                  />
                ),
              },
              {
                key: 'payable.payableType',
                title: translate('text_63ac86d797f728a87b2f9fad'),
                minWidth: 160,
                maxSpace: true,
                content: ({ payable }) => {
                  if (isInvoice(payable)) {
                    return payable.number
                  }
                  if (isPaymentRequest(payable)) {
                    if (payable.invoices.length > 1) {
                      return translate('text_17370296250898eqj4qe4qg9', {
                        count: payable.invoices.length,
                      })
                    }
                    return payable.invoices[0]?.number
                  }
                },
              },
              {
                key: 'amountCents',
                title: translate('text_6419c64eace749372fc72b3e'),
                textAlign: 'right',
                content: ({ amountCents, amountCurrency }) => (
                  <Typography variant="bodyHl" color="textSecondary" noWrap>
                    {intlFormatNumber(
                      deserializeAmount(amountCents, amountCurrency || CurrencyEnum.Usd),
                      {
                        currency: amountCurrency || CurrencyEnum.Usd,
                      },
                    )}
                  </Typography>
                ),
              },
              {
                key: 'paymentType',
                title: translate('text_1737043182491927uocp2ydo'),
                content: ({ paymentType, paymentProviderType }) => (
                  <PaymentProviderChip
                    paymentProvider={
                      paymentProviderType ??
                      (paymentType === PaymentTypeEnum.Manual ? 'manual' : undefined)
                    }
                  />
                ),
              },
              {
                key: 'createdAt',
                title: translate('text_664cb90097bfa800e6efa3f5'),
                content: ({ createdAt, customer }) =>
                  intlFormatDateTime(createdAt, { timezone: customer.applicableTimezone }).date,
              },
            ]}
          />
        </InfiniteScroll>
      )}
    </>
  )
}
