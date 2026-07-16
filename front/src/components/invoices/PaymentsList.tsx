import { ApolloError, gql, LazyQueryHookOptions } from '@apollo/client'
import { FC } from 'react'
import { generatePath } from 'react-router-dom'

import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { buildPaymentDocumentData } from '~/components/emails/buildDocumentData'
import { PaymentProviderChip } from '~/components/PaymentProviderChip'
import { addToast } from '~/core/apolloClient'
import { payablePaymentStatusMapping } from '~/core/constants/statusInvoiceMapping'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { PAYMENT_DETAILS_ROUTE } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { isInvoice, isPaymentRequest } from '~/core/utils/payableUtils'
import {
  BillingEntityEmailSettingsEnum,
  CurrencyEnum,
  GetPaymentsListQuery,
  GetPaymentsListQueryHookResult,
  PaymentForPaymentsListFragment,
  PaymentTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import useDownloadPaymentReceipts from '~/hooks/paymentReceipts/useDownloadPaymentReceipts'
import { usePermissions } from '~/hooks/usePermissions'
import { useResendEmailDialog } from '~/hooks/useResendEmailDialog'

gql`
  fragment PaymentForPaymentsList on Payment {
    amountCents
    amountCurrency
    createdAt
    id
    payable {
      ... on Invoice {
        id
        number
        payableType
      }
      ... on PaymentRequest {
        payableType
        invoices {
          id
          number
        }
      }
    }
    payablePaymentStatus
    paymentProviderType
    paymentType
    providerPaymentId
    paymentProvider {
      ... on AdyenProvider {
        name
      }
      ... on CashfreeProvider {
        name
      }
      ... on FlutterwaveProvider {
        name
      }
      ... on GocardlessProvider {
        name
      }
      ... on MoneyhashProvider {
        name
      }
      ... on StripeProvider {
        name
      }
    }
    reference
    customer {
      id
      name
      displayName
      email
      applicableTimezone
      billingEntity {
        id
        code
        name
        email
        einvoicing
        emailSettings
      }
    }
    paymentReceipt {
      id
      number
    }
  }
`

interface PaymentsListProps {
  isLoading: boolean
  payments?: PaymentForPaymentsListFragment[]
  metadata?: GetPaymentsListQuery['payments']['metadata']
  error?: ApolloError
  variables?: LazyQueryHookOptions['variables']
  fetchMore?: GetPaymentsListQueryHookResult['fetchMore']
}

export const PaymentsList: FC<PaymentsListProps> = ({
  isLoading,
  payments,
  metadata,
  error,
  variables,
  fetchMore,
}) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { canDownloadPaymentReceipts, downloadPaymentReceipts } = useDownloadPaymentReceipts()

  const { showResendEmailDialog } = useResendEmailDialog()

  return (
    <div className="border-t border-grey-300">
      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } = metadata || {}

          currentPage < totalPages &&
            !isLoading &&
            fetchMore?.({
              variables: { page: currentPage + 1 },
            })
        }}
      >
        <Table
          name="payments-list"
          data={payments || []}
          containerSize={{
            default: 16,
            md: 48,
          }}
          isLoading={isLoading}
          hasError={!!error}
          actionColumn={({ paymentReceipt, customer }) => {
            const canResendEmail =
              hasPermissions(['paymentReceiptsSend']) &&
              customer?.billingEntity?.emailSettings?.includes(
                BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
              )

            return [
              {
                startIcon: 'duplicate',
                title: translate('text_1737029625089rtcf3ah5khq'),
                onAction: ({ id }) => {
                  copyToClipboard(id)
                  addToast({
                    severity: 'info',
                    translateKey: translate('text_17370296250897n2pakp5v33'),
                  })
                },
              },
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
              canResendEmail
                ? {
                    startIcon: 'at',
                    title: translate('text_1770392315728uyw3zhs7kzh'),
                    onAction: (payment) => {
                      const payable = payment.payable
                      const payableInvoice = payable?.__typename === 'Invoice' && [payable]
                      const requestPaymentInvoices =
                        payable?.__typename === 'PaymentRequest' && payable?.invoices
                      const paymentInvoices = payableInvoice || requestPaymentInvoices || []

                      showResendEmailDialog({
                        subject: translate('text_1770631139987tf8b59zentb', {
                          organization: customer?.billingEntity.name,
                          receiptNumber: payment.paymentReceipt?.number,
                        }),
                        type: BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
                        billingEntity: customer?.billingEntity,
                        documentId: payment.paymentReceipt?.id,
                        customerEmail: customer.email,
                        documentData: buildPaymentDocumentData({
                          amountCents: payment.amountCents,
                          amountCurrency: payment.amountCurrency,
                          createdAt: payment.createdAt,
                          paymentType: payment.paymentType,
                          paymentReceipt: payment.paymentReceipt,
                          invoices: paymentInvoices,
                          translate,
                        }),
                      })
                    },
                    disabled: !paymentReceipt?.id,
                  }
                : null,
            ]
          }}
          actionColumnTooltip={() => translate('text_637f813d31381b1ed90ab326')}
          onRowActionLink={(request) =>
            generatePath(PAYMENT_DETAILS_ROUTE, {
              paymentId: request.id,
            })
          }
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
              content: ({ payable }) => {
                if (isInvoice(payable)) {
                  return payable.number ? (
                    <TypographyWithCopy compact noWrap variant="body">
                      {payable.number}
                    </TypographyWithCopy>
                  ) : null
                }
                if (isPaymentRequest(payable)) {
                  if (payable.invoices.length > 1) {
                    return translate('text_17370296250898eqj4qe4qg9', {
                      count: payable.invoices.length,
                    })
                  }

                  const firstNumber = payable.invoices[0]?.number

                  return firstNumber ? (
                    <TypographyWithCopy compact noWrap variant="body">
                      {firstNumber}
                    </TypographyWithCopy>
                  ) : null
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
              key: 'customer.displayName',
              title: translate('text_63ac86d797f728a87b2f9fb3'),
              maxSpace: true,
              content: ({ customer }) => customer?.displayName || customer?.name,
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
          placeholder={{
            errorState: variables?.searchTerm
              ? {
                  title: translate('text_623b53fea66c76017eaebb6e'),
                  subtitle: translate('text_63bab307a61c62af497e0599'),
                }
              : {
                  title: translate('text_63ac86d797f728a87b2f9fea'),
                  subtitle: translate('text_63ac86d797f728a87b2f9ff2'),
                  buttonTitle: translate('text_63ac86d797f728a87b2f9ffa'),
                  buttonAction: () => location.reload(),
                  buttonVariant: 'primary',
                },
            emptyState: variables?.searchTerm
              ? {
                  title: translate('text_1738056040178doq581h3d2o'),
                  subtitle: translate('text_63ebafd92755e50052a86e14'),
                }
              : {
                  title: translate('text_173805604017831h2cebcami'),
                  subtitle: translate('text_1738056040178gw94jzmzckx'),
                },
          }}
        />
      </InfiniteScroll>
    </div>
  )
}
