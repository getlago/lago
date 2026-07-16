import { gql } from '@apollo/client'
import { Icon, IconName } from 'lago-design-system'
import { ReactNode } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { ConditionalWrapper } from '~/components/ConditionalWrapper'
import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { buildPaymentDocumentData } from '~/components/emails/buildDocumentData'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { PaymentProviderChip } from '~/components/PaymentProviderChip'
import { addToast } from '~/core/apolloClient'
import { buildGoCardlessPaymentUrl, buildStripePaymentUrl } from '~/core/constants/externalUrls'
import {
  isInvoicePartiallyPaid,
  payablePaymentStatusMapping,
  paymentStatusMapping,
} from '~/core/constants/statusInvoiceMapping'
import { CustomerInvoiceDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_INVOICE_DETAILS_ROUTE,
  Link,
  PAYMENTS_ROUTE,
} from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime, TimeFormat } from '~/core/timezone'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  BillingEntityEmailSettingsEnum,
  CurrencyEnum,
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  LagoApiError,
  PaymentTypeEnum,
  ProviderTypeEnum,
  useGetPaymentDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import useDownloadPaymentReceipts from '~/hooks/paymentReceipts/useDownloadPaymentReceipts'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import { useResendEmailDialog } from '~/hooks/useResendEmailDialog'
import { MenuPopper } from '~/styles'

gql`
  fragment InvoiceForPaymentDetails on Invoice {
    id
    status
    paymentStatus
    number
    totalAmountCents
    totalDueAmountCents
    issuingDate
    currency
    paymentOverdue
    totalPaidAmountCents
    paymentDisputeLostAt
  }

  query GetPaymentDetails($id: ID!) {
    payment(id: $id) {
      id
      amountCents
      amountCurrency
      createdAt
      updatedAt
      reference
      paymentType
      paymentProviderType
      payablePaymentStatus
      providerPaymentId
      customer {
        deletedAt
        id
        name
        email
        displayName
        applicableTimezone
        billingEntity {
          id
          name
          email
          einvoicing
          emailSettings
          logoUrl
        }
      }
      payable {
        ... on Invoice {
          id
          payableType
          ...InvoiceForPaymentDetails
        }
        ... on PaymentRequest {
          id
          payableType
          invoices {
            ...InvoiceForPaymentDetails
          }
        }
      }
      paymentReceipt {
        id
        xmlUrl
        number
      }
    }
  }
`

const Loading = () => {
  return (
    <div className="flex flex-col gap-8 lg:flex-row">
      <div className="flex w-full flex-col gap-3">
        {[1, 2, 3, 4].map((i) => (
          <div key={`key-skeleton-line-${i}`} className="flex flex-row gap-x-3">
            <div className="min-w-35">
              <Skeleton variant="text" className="w-28" />
            </div>
            <Skeleton variant="text" className="w-60" />
          </div>
        ))}
      </div>
      <div className="flex w-full flex-col gap-3">
        {[1, 2, 3, 4].map((i) => (
          <div key={`key-skeleton-line-${i}`} className="flex flex-row gap-x-3">
            <div className="min-w-35">
              <Skeleton variant="text" className="w-24" />
            </div>
            <Skeleton variant="text" className="w-60" />
          </div>
        ))}
      </div>
    </div>
  )
}

const InfoLine = ({
  label,
  value,
  isBold,
}: {
  label: string
  value: string | ReactNode
  isBold?: boolean
}) => (
  <div className="flex items-center gap-3 align-baseline [&>a>*]:text-inherit [&>a]:text-blue-600">
    <Typography variant={isBold ? 'captionHl' : 'caption'} noWrap className="min-w-35">
      {label}
    </Typography>
    {typeof value === 'string' ? (
      <Typography variant="body" color="grey700" forceBreak>
        {value}
      </Typography>
    ) : (
      value
    )}
  </div>
)

const PaymentDetails = () => {
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()
  const { timezone } = useOrganizationInfos()
  const { customerId, paymentId } = useParams()

  const {
    data = {},
    loading,
    error,
  } = useGetPaymentDetailsQuery({
    variables: {
      id: paymentId as string,
    },
    skip: !paymentId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  useNotFoundRedirect({
    error,
    loading,
    redirectTo: PAYMENTS_ROUTE,
    translateKey: 'text_1777995443788h3delxx2sno',
  })

  const { showResendEmailDialog } = useResendEmailDialog()

  const payment = data.payment
  const customer = payment?.customer
  const payable = payment?.payable
  const payableInvoice = payable?.__typename === 'Invoice' && [payable]
  const requestPaymentInvoices = payable?.__typename === 'PaymentRequest' && payable?.invoices
  const invoices = payableInvoice || requestPaymentInvoices || []

  const { canDownloadPaymentReceipts, downloadPaymentReceipts, downloadPaymentXmlReceipts } =
    useDownloadPaymentReceipts()
  const canDownloadXmlFile =
    canDownloadPaymentReceipts &&
    (!!payment?.paymentReceipt?.xmlUrl || !!payment?.customer?.billingEntity?.einvoicing)

  const canResendEmail =
    hasPermissions(['paymentReceiptsSend']) &&
    !!payment?.customer?.billingEntity?.emailSettings?.includes(
      BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
    )

  const paymentFormattedDate = (dateString: string) => {
    const formattedDate = intlFormatDateTime(dateString, {
      timezone: customer?.applicableTimezone,
      formatTime: TimeFormat.TIME_24_SIMPLE,
    })

    return `${formattedDate.date} ${formattedDate.time} ${formattedDate.timezone}`
  }

  const resendEmail = () => {
    showResendEmailDialog({
      subject: translate('text_1770631139987tf8b59zentb', {
        organization: payment?.customer?.billingEntity.name,
        receiptNumber: payment?.paymentReceipt?.number,
      }),
      type: BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
      billingEntity: payment?.customer?.billingEntity,
      documentId: payment?.paymentReceipt?.id,
      customerEmail: payment?.customer?.email,
      documentData: buildPaymentDocumentData({
        amountCents: payment?.amountCents,
        amountCurrency: payment?.amountCurrency,
        createdAt: payment?.createdAt,
        paymentType: payment?.paymentType,
        paymentProviderType: payment?.paymentProviderType,
        paymentReceipt: payment?.paymentReceipt,
        invoices,
        timezone: customer?.applicableTimezone,
        translate,
      }),
    })
  }

  const headerEntity = {
    viewName: intlFormatNumber(
      deserializeAmount(payment?.amountCents, payment?.amountCurrency || CurrencyEnum.Usd),
      { currency: payment?.amountCurrency },
    ),
    viewNameLoading: loading,
    metadata: payment?.id || '',
    metadataLoading: loading,
    badges: payment?.payablePaymentStatus
      ? [payablePaymentStatusMapping({ payablePaymentStatus: payment.payablePaymentStatus })]
      : [],
  }

  const headerActions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_626162c62f790600f850b6fe'),
      dataTest: 'payment-details-actions',
      items: [
        {
          label: translate('text_1737029625089rtcf3ah5khq'),
          onClick: (closePopper) => {
            if (!payment?.id) return

            copyToClipboard(payment.id)
            addToast({
              severity: 'info',
              translateKey: translate('text_17370296250897n2pakp5v33'),
            })
            closePopper()
          },
        },
        {
          label: translate('text_1741334392622fl3ozwejrul'),
          hidden: !canDownloadPaymentReceipts || canDownloadXmlFile,
          disabled: !payment?.paymentReceipt?.id,
          onClick: (closePopper) => {
            downloadPaymentReceipts({
              paymentReceiptId: payment?.paymentReceipt?.id,
            })
            closePopper()
          },
        },
        {
          label: translate('text_1762529003426q0xqqentmsc'),
          hidden: !canDownloadXmlFile,
          disabled: !payment?.paymentReceipt?.id,
          onClick: (closePopper) => {
            downloadPaymentReceipts({
              paymentReceiptId: payment?.paymentReceipt?.id,
            })
            closePopper()
          },
        },
        {
          label: translate('text_17625290034260szr7wfl8cs'),
          hidden: !canDownloadXmlFile,
          disabled: !payment?.paymentReceipt?.id,
          onClick: (closePopper) => {
            downloadPaymentXmlReceipts({
              paymentReceiptId: payment?.paymentReceipt?.id,
            })
            closePopper()
          },
        },
        {
          label: translate('text_1770392315728uyw3zhs7kzh'),
          hidden: !canResendEmail,
          onClick: (closePopper) => {
            resendEmail()
            closePopper()
          },
        },
      ],
    },
  ]

  return (
    <div>
      <MainHeader.Configure
        breadcrumb={[{ label: translate('text_6672ebb8b1b50be550eccbed'), path: PAYMENTS_ROUTE }]}
        entity={headerEntity}
        actions={{ items: headerActions, loading }}
      />

      <DetailsPage.Container className="pt-8">
        <div className="pb-12 shadow-b">
          <div className="mb-4 flex items-center justify-between">
            <Typography variant="subhead1">{translate('text_634687079be251fdb43833b7')}</Typography>

            {canDownloadPaymentReceipts && !canDownloadXmlFile && (
              <Button
                variant="inline"
                align="left"
                disabled={!payment?.paymentReceipt?.id}
                onClick={() => {
                  downloadPaymentReceipts({
                    paymentReceiptId: payment?.paymentReceipt?.id,
                  })
                }}
              >
                {translate('text_1741334392622fl3ozwejrul')}
              </Button>
            )}

            {canDownloadXmlFile && (
              <Popper
                PopperProps={{ placement: 'bottom-end' }}
                opener={
                  <Button
                    variant="inline"
                    endIcon="chevron-down"
                    data-test="coupon-details-actions"
                  >
                    {translate('text_1741334392622fl3ozwejrul')}
                  </Button>
                }
              >
                {({ closePopper }) => (
                  <MenuPopper>
                    <Button
                      variant="quaternary"
                      align="left"
                      onClick={() => {
                        downloadPaymentReceipts({
                          paymentReceiptId: payment?.paymentReceipt?.id,
                        })
                        closePopper()
                      }}
                    >
                      {translate('text_1762529003426q0xqqentmsc')}
                    </Button>
                    <Button
                      variant="quaternary"
                      align="left"
                      onClick={() => {
                        downloadPaymentXmlReceipts({
                          paymentReceiptId: payment?.paymentReceipt?.id,
                        })
                        closePopper()
                      }}
                    >
                      {translate('text_17625290034260szr7wfl8cs')}
                    </Button>
                  </MenuPopper>
                )}
              </Popper>
            )}
          </div>

          {loading && <Loading />}
          {!loading && (
            <div className="flex flex-col gap-8 lg:flex-row">
              <div className="flex flex-1 flex-col gap-3">
                <InfoLine
                  label={translate('text_634687079be251fdb43833cb')}
                  value={
                    <ConditionalWrapper
                      condition={!!customer?.deletedAt || !hasPermissions(['customersView'])}
                      validWrapper={(children) => <>{children}</>}
                      invalidWrapper={(children) => {
                        return !!customerId || customer?.id ? (
                          <Link
                            to={generatePath(CUSTOMER_DETAILS_ROUTE, {
                              customerId: (customerId || customer?.id) as string,
                            })}
                          >
                            {children}
                          </Link>
                        ) : (
                          <>{children}</>
                        )
                      }}
                    >
                      <Typography variant="body" color="grey700" forceBreak>
                        {customer?.displayName || customer?.name}
                      </Typography>
                    </ConditionalWrapper>
                  }
                />
                <InfoLine
                  label={translate('text_65a6b4e2cb38d9b70ec53d83')}
                  value={intlFormatNumber(
                    deserializeAmount(
                      payment?.amountCents,
                      payment?.amountCurrency || CurrencyEnum.Usd,
                    ),
                    {
                      currency: payment?.amountCurrency,
                    },
                  )}
                />
                <InfoLine
                  label={translate('text_62442e40cea25600b0b6d858')}
                  value={paymentFormattedDate(payment?.createdAt)}
                />
                <InfoLine
                  label={translate('text_1737043149535dhigi301msf')}
                  value={paymentFormattedDate(payment?.updatedAt)}
                />
              </div>

              <div className="flex flex-1 flex-col gap-3">
                <InfoLine
                  isBold
                  label={translate('text_1737043182491927uocp2ydo')}
                  value={
                    <PaymentProviderChip
                      paymentProvider={
                        payment?.paymentType === PaymentTypeEnum.Manual
                          ? 'manual_long'
                          : (payment?.paymentProviderType ?? undefined)
                      }
                    />
                  }
                />
                <InfoLine
                  label={translate('text_1737112054603c6phsbkyvmx')}
                  value={
                    <ConditionalWrapper
                      condition={!!payment?.providerPaymentId}
                      validWrapper={(children) => {
                        if (
                          payment?.providerPaymentId &&
                          payment?.paymentProviderType &&
                          [ProviderTypeEnum.Stripe, ProviderTypeEnum.Gocardless].includes(
                            payment.paymentProviderType,
                          )
                        ) {
                          const href =
                            payment?.paymentProviderType === ProviderTypeEnum.Stripe
                              ? buildStripePaymentUrl(payment.providerPaymentId)
                              : buildGoCardlessPaymentUrl(payment.providerPaymentId)

                          // If the payment has a providerPaymentId, it means it was created by a payment provider
                          return (
                            <Link
                              target="_blank"
                              rel="noopener noreferrer"
                              to={href}
                              className="w-fit !shadow-none line-break-anywhere hover:no-underline focus:ring-0"
                            >
                              {children}
                            </Link>
                          )
                        }

                        return (
                          <Typography variant="body" color="grey700" forceBreak>
                            {payment?.providerPaymentId}
                          </Typography>
                        )
                      }}
                      invalidWrapper={() => <>{'-'}</>}
                    >
                      <Typography variant="body" color="grey700" forceBreak>
                        {payment?.providerPaymentId ?? payment?.reference}
                        <Icon name="outside" className="mb-1 ml-2" />
                      </Typography>
                    </ConditionalWrapper>
                  }
                />
                <InfoLine
                  label={translate('text_63eba8c65a6c8043feee2a0f')}
                  value={
                    <Status
                      {...payablePaymentStatusMapping({
                        payablePaymentStatus: payment?.payablePaymentStatus ?? undefined,
                      })}
                    />
                  }
                />
                <InfoLine
                  label={translate('text_17370432002911cyzkxf966v')}
                  value={payment?.reference ?? '-'}
                />
              </div>
            </div>
          )}
        </div>

        <div>
          <Typography variant="subhead1" className="mb-4">
            {translate('text_63ac86d797f728a87b2f9f85')}
          </Typography>

          <Table
            name={'payment-invoices'}
            data={invoices}
            isLoading={loading}
            containerSize={{
              default: 4,
            }}
            onRowActionLink={({ id }) =>
              generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
                customerId: customerId || (customer?.id as string),
                invoiceId: id as string,
                tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
              })
            }
            columns={[
              {
                key: 'paymentStatus',
                title: translate('text_6419c64eace749372fc72b40'),
                content: ({
                  paymentStatus,
                  paymentOverdue,
                  totalPaidAmountCents,
                  totalDueAmountCents,
                  paymentDisputeLostAt,
                  status,
                }) => {
                  if (status !== InvoiceStatusTypeEnum.Finalized) {
                    return null
                  }

                  let content: { tooltipTitle?: string; statusEndIcon?: IconName } = {
                    tooltipTitle: undefined,
                    statusEndIcon: undefined,
                  }

                  const isOverdue =
                    paymentOverdue && paymentStatus === InvoicePaymentStatusTypeEnum.Pending
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
                        {...(isOverdue
                          ? {
                              type: StatusType.danger,
                              label: 'overdue',
                            }
                          : paymentStatusMapping({
                              status,
                              paymentStatus,
                              totalPaidAmountCents,
                              totalDueAmountCents,
                            }))}
                        endIcon={content.statusEndIcon}
                      />
                    </Tooltip>
                  )
                },
              },
              {
                key: 'number',
                title: translate('text_64188b3d9735d5007d71226c'),
                maxSpace: true,
                content: ({ number }) => number,
              },
              {
                key: 'totalAmountCents',
                title: translate('text_6419c64eace749372fc72b3e'),
                content: ({ totalAmountCents, currency }) => (
                  <Typography variant="bodyHl" color="grey700">
                    {intlFormatNumber(
                      deserializeAmount(totalAmountCents, currency || CurrencyEnum.Usd),
                      {
                        currency: currency || CurrencyEnum.Usd,
                      },
                    )}
                  </Typography>
                ),
              },
              {
                key: 'totalDueAmountCents',
                title: translate('text_17374735502775afvcm9pqxk'),
                textAlign: 'right',
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
                key: 'issuingDate',
                title: translate('text_6419c64eace749372fc72b39'),
                content: ({ issuingDate }) => intlFormatDateTime(issuingDate, { timezone }).date,
              },
            ]}
            placeholder={{
              emptyState: {
                title: translate('text_63b578e959c1366df5d14569'),
                subtitle: translate('text_62bb102b66ff57dbfe7905c2'),
              },
            }}
          />
        </div>
      </DetailsPage.Container>
    </div>
  )
}

export default PaymentDetails
