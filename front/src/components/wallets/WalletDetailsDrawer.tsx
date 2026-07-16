import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import {
  FC,
  forwardRef,
  Fragment,
  ReactNode,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Avatar, AvatarBadge } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { NavigationTab, TabManagedBy } from '~/components/designSystem/NavigationTab'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import WalletTransactionItems from '~/components/wallets/WalletTransactionItems'
import { buildGoCardlessPaymentUrl, buildStripePaymentUrl } from '~/core/constants/externalUrls'
import {
  payablePaymentStatusMapping,
  paymentStatusMapping,
} from '~/core/constants/statusInvoiceMapping'
import { CustomerInvoiceDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_INVOICE_DETAILS_ROUTE, Link } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { DateFormat, intlFormatDateTime, TimeFormat } from '~/core/timezone'
import {
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
  LagoApiError,
  ProviderTypeEnum,
  useGetWalletTransactionConsumptionsQuery,
  useGetWalletTransactionDetailsLazyQuery,
  useGetWalletTransactionFundingsQuery,
  WalletInfosForTransactionsFragment,
  WalletTransactionSourceEnum,
  WalletTransactionStatusEnum,
  WalletTransactionTransactionStatusEnum,
  WalletTransactionTransactionTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import ErrorImage from '~/public/images/maneki/error.svg'
import { tw } from '~/styles/utils'

gql`
  fragment WalletTransactionDetails on WalletTransaction {
    id
    name
    amount
    createdAt
    transactionType
    creditAmount
    settledAt
    failedAt
    status
    transactionStatus
    source
    invoiceRequiresSuccessfulPayment
    priority
    remainingAmountCents
    remainingCreditAmount
    metadata {
      key
      value
    }
    invoice {
      id
      status
      invoiceType
      number
      paymentStatus
      customer {
        id
      }
      payments {
        id
        providerPaymentId
        paymentProviderType
        payablePaymentStatus
      }
    }
  }

  query GetWalletTransactionDetails($transactionId: ID!) {
    walletTransaction(id: $transactionId) {
      id
      ...WalletTransactionDetails
    }
  }

  fragment WalletTransactionFundingItem on WalletTransactionFunding {
    id
    amountCents
    createdAt
    creditAmount
    walletTransaction {
      id
      transactionStatus
    }
  }

  fragment WalletTransactionConsumptionItem on WalletTransactionConsumption {
    id
    amountCents
    createdAt
    creditAmount
    walletTransaction {
      id
      transactionStatus
    }
  }

  query GetWalletTransactionFundings($walletTransactionId: ID!, $page: Int, $limit: Int) {
    walletTransactionFundings(
      walletTransactionId: $walletTransactionId
      page: $page
      limit: $limit
    ) {
      collection {
        ...WalletTransactionFundingItem
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }

  query GetWalletTransactionConsumptions($walletTransactionId: ID!, $page: Int, $limit: Int) {
    walletTransactionConsumptions(
      walletTransactionId: $walletTransactionId
      page: $page
      limit: $limit
    ) {
      collection {
        ...WalletTransactionConsumptionItem
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`

interface WalletDetailsDrawerState {
  transactionId: string
}

export interface WalletDetailsDrawerRef extends DrawerRef {
  openDrawer: (data?: WalletDetailsDrawerState) => unknown
  closeDrawer: () => unknown
}

interface WalletDetailsDrawerProps {
  wallet: WalletInfosForTransactionsFragment
}

export const GRID =
  'grid grid-cols-1 gap-y-1 [&>*:nth-child(even)]:mb-3 sm:[&>*:nth-child(even)]:mb-0 sm:grid-cols-[fit-content(100%)_1fr] sm:auto-rows-[minmax(40px,1fr)] items-center sm:gap-x-8 sm:gap-y-2'

const WALLET_TRANSACTION_SOURCE_TRANSLATIONS: Record<WalletTransactionSourceEnum, string> = {
  [WalletTransactionSourceEnum.Interval]: 'text_1751530295201vhd64062mii',
  [WalletTransactionSourceEnum.Threshold]: 'text_1751530295201xyz98abc123',
  [WalletTransactionSourceEnum.Manual]: 'text_1751530295201def456ghi78',
}

export const TRANSACTION_STATUS_LABEL_MAP = {
  [WalletTransactionTransactionStatusEnum.Granted]: 'text_662fc05d2cfe3a0596b29db0',
  [WalletTransactionTransactionStatusEnum.Voided]: 'text_662fc05d2cfe3a0596b29d98',
  [WalletTransactionTransactionStatusEnum.Invoiced]: 'text_62da6ec24a8e24e44f812892',
  [WalletTransactionTransactionStatusEnum.Purchased]: 'text_62da6ec24a8e24e44f81289a',
}

export const WalletDetailsDrawer = forwardRef<WalletDetailsDrawerRef, WalletDetailsDrawerProps>(
  ({ wallet }: WalletDetailsDrawerProps, ref) => {
    const drawerRef = useRef<DrawerRef>(null)
    const { translate } = useInternationalization()
    const { timezone } = useOrganizationInfos()
    const { customerId } = useParams()

    const [walletTransactionId, setWalletTransactionId] = useState<string>('')

    const [getTransaction, { data, loading, error }] = useGetWalletTransactionDetailsLazyQuery()

    const walletTransactionType = data?.walletTransaction?.transactionType

    const showConsumptionTab =
      wallet?.traceable && walletTransactionType === WalletTransactionTransactionTypeEnum.Inbound

    const showFundingTab =
      wallet?.traceable && walletTransactionType === WalletTransactionTransactionTypeEnum.Outbound

    const {
      data: fundings,
      error: fundingsError,
      loading: fundingsLoading,
      fetchMore: fundingsFetchMore,
    } = useGetWalletTransactionFundingsQuery({
      variables: {
        walletTransactionId: walletTransactionId as string,
        limit: 20,
      },
      skip: !walletTransactionId || !showFundingTab,
      context: {
        silentErrorCodes: [LagoApiError.UnprocessableEntity],
      },
    })

    const {
      data: consumptions,
      error: consumptionsError,
      loading: consumptionsLoading,
      fetchMore: consumptionsFetchMore,
    } = useGetWalletTransactionConsumptionsQuery({
      variables: {
        walletTransactionId: walletTransactionId as string,
        limit: 20,
      },
      skip: !walletTransactionId || !showConsumptionTab,
      context: {
        silentErrorCodes: [LagoApiError.UnprocessableEntity],
      },
    })

    const [showAllPayments, setShowAllPayments] = useState(false)

    const onClose = () => {
      setShowAllPayments(false)
      drawerRef.current?.closeDrawer()
    }

    useImperativeHandle(ref, () => ({
      openDrawer: async (args) => {
        if (!args?.transactionId) return

        await getTransaction({ variables: { transactionId: args.transactionId } })

        setWalletTransactionId(args.transactionId)

        drawerRef.current?.openDrawer()
      },
      closeDrawer: onClose,
    }))

    const {
      id,
      createdAt,
      failedAt,
      invoice,
      invoiceRequiresSuccessfulPayment,
      priority,
      remainingAmountCents,
      remainingCreditAmount,
      metadata,
      name,
      settledAt,
      source,
      status,
      transactionStatus,
      transactionType,
      amount,
      creditAmount,
    } = data?.walletTransaction || {}

    const formatted = useMemo(() => {
      const deserialized = {
        credit: Number(data?.walletTransaction?.creditAmount || 0),
        amount: Number(data?.walletTransaction?.amount || 0),
      }

      const granted =
        data?.walletTransaction?.transactionStatus ===
          WalletTransactionTransactionStatusEnum.Granted && 'text_662fc05d2cfe3a0596b29db0'
      const voided =
        data?.walletTransaction?.transactionStatus ===
          WalletTransactionTransactionStatusEnum.Voided && 'text_662fc05d2cfe3a0596b29d98'
      const invoiced =
        data?.walletTransaction?.transactionStatus ===
          WalletTransactionTransactionStatusEnum.Invoiced && 'text_62da6ec24a8e24e44f812892'
      const purchased =
        data?.walletTransaction?.transactionStatus ===
          WalletTransactionTransactionStatusEnum.Purchased && 'text_62da6ec24a8e24e44f81289a'

      const localFormatted: {
        credit: string
        amount: string
        type: string
      } = {
        credit: `${data?.walletTransaction?.transactionType === WalletTransactionTransactionTypeEnum.Inbound ? '+' : '-'}${translate('text_62da6ec24a8e24e44f812896', { amount: deserialized.credit }, deserialized.credit)}`,
        amount: intlFormatNumber(deserialized.amount, {
          currency: wallet?.currency,
        }),
        type: translate(
          granted || voided || invoiced || purchased || 'text_62d18855b22699e5cf55f879',
          undefined,
          deserialized.credit,
        ),
      }

      return localFormatted
    }, [data?.walletTransaction, wallet, translate])

    const isSettled = status === WalletTransactionStatusEnum.Settled

    const transactionBalance = useMemo(() => {
      return {
        settled: {
          amount: intlFormatNumber(isSettled ? Number(amount || '0') : 0, {
            currency: wallet?.currency,
          }),
          creditAmount: isSettled ? Number(creditAmount) : 0,
        },
        available: {
          amount: intlFormatNumber(deserializeAmount(remainingAmountCents, wallet?.currency), {
            currency: wallet?.currency,
          }),
          creditAmount: Number(remainingCreditAmount || 0),
        },
      }
    }, [
      isSettled,
      amount,
      creditAmount,
      remainingAmountCents,
      remainingCreditAmount,
      wallet?.currency,
    ])

    const canHaveInvoice =
      (transactionStatus === WalletTransactionTransactionStatusEnum.Invoiced ||
        transactionStatus === WalletTransactionTransactionStatusEnum.Purchased) &&
      !!invoice
    const hasPayments = !!invoice?.payments && invoice?.payments?.length > 0
    const canHavePayment = transactionStatus === WalletTransactionTransactionStatusEnum.Purchased
    const hasNoSuccessfulPaymentButRequiresIt =
      !!invoiceRequiresSuccessfulPayment &&
      settledAt === null &&
      invoice?.status !== InvoiceStatusTypeEnum.Finalized

    const createdAtDate = createdAt
      ? intlFormatDateTime(createdAt, {
          timezone,
          formatDate: DateFormat.DATE_FULL,
          formatTime: TimeFormat.TIME_WITH_SECONDS,
        })
      : undefined
    const failedAtDate = failedAt
      ? intlFormatDateTime(failedAt, {
          timezone,
          formatDate: DateFormat.DATE_FULL,
          formatTime: TimeFormat.TIME_WITH_SECONDS,
        })
      : undefined
    const settledAtDate = settledAt
      ? intlFormatDateTime(settledAt, {
          timezone,
          formatDate: DateFormat.DATE_FULL,
          formatTime: TimeFormat.TIME_WITH_SECONDS,
        })
      : undefined

    return (
      <Drawer
        className="px-12 pt-12"
        ref={drawerRef}
        title={translate('text_1741944051511ju78ai43hw9')}
        onClose={onClose}
        stickyBottomBar={
          <Button size="medium" onClick={onClose}>
            {translate('text_62f50d26c989ab03196884ae')}
          </Button>
        }
        stickyBottomBarClassName="md:py-3"
      >
        <div className="flex flex-col gap-12 not-last-child:pb-12 not-last-child:shadow-b">
          {loading && (
            <>
              <header>
                <Skeleton variant="connectorAvatar" size="big" className="mb-4" />
                <div className="flex flex-row gap-4">
                  <div className="flex grow flex-col gap-1">
                    <Skeleton variant="text" textVariant="headline" className="w-60" />
                    <Skeleton variant="text" textVariant="body" className="w-30" />
                  </div>
                  <div className="flex flex-col gap-1 text-right">
                    <Skeleton variant="text" textVariant="headline" className="ml-auto w-60" />
                    <Skeleton variant="text" textVariant="body" className="ml-auto w-30" />
                  </div>
                </div>
              </header>

              <section className="flex flex-col gap-4">
                <Skeleton variant="text" textVariant="subhead1" className="w-34" />
                <div className={tw(GRID)}>
                  {[1, 2].map((i) => (
                    <Fragment key={`transaction-row-${i}`}>
                      <Skeleton variant="text" className="w-20" />
                      <Skeleton variant="text" className="w-28" />
                    </Fragment>
                  ))}
                </div>
              </section>
            </>
          )}

          {!loading && error && (
            <GenericPlaceholder
              title={translate('text_636d023ce11a9d038819b579')}
              subtitle={translate('text_636d023ce11a9d038819b57b')}
              image={<ErrorImage width="136" height="104" />}
            />
          )}

          {!loading && !error && (
            <>
              <header>
                <Avatar variant="connector" size="big" className="mb-4">
                  {transactionType === WalletTransactionTransactionTypeEnum.Inbound && (
                    <Icon name="plus" />
                  )}
                  {transactionType === WalletTransactionTransactionTypeEnum.Outbound && (
                    <Icon name="minus" />
                  )}
                  {status === WalletTransactionStatusEnum.Pending && (
                    <AvatarBadge icon="sync" color="dark" size="big" />
                  )}
                  {status === WalletTransactionStatusEnum.Failed && (
                    <AvatarBadge icon="stop" color="warning" size="big" />
                  )}
                </Avatar>

                <div className="mb-4 flex flex-row gap-4">
                  <div className="flex grow flex-col gap-1">
                    <Typography
                      variant="headline"
                      color={status === WalletTransactionStatusEnum.Settled ? 'grey700' : 'grey500'}
                    >
                      {formatted.type}
                    </Typography>
                    <Typography variant="body">
                      {status === WalletTransactionStatusEnum.Pending &&
                        `${translate('text_62da6db136909f52c2704c30')} • `}
                      {status === WalletTransactionStatusEnum.Failed &&
                        `${translate('text_637656ef3d876b0269edc7a1')} • `}
                      {intlFormatDateTime(createdAt, { timezone }).date}
                    </Typography>
                  </div>
                  <div className="flex flex-col gap-1 text-right">
                    <Typography
                      variant="headline"
                      {...(transactionType === WalletTransactionTransactionTypeEnum.Inbound && {
                        color: 'success600',
                      })}
                      {...(transactionType === WalletTransactionTransactionTypeEnum.Outbound && {
                        color: 'grey700',
                      })}
                      {...((status === WalletTransactionStatusEnum.Pending ||
                        status === WalletTransactionStatusEnum.Failed) && {
                        color: 'grey500',
                      })}
                      className={tw(
                        status === WalletTransactionStatusEnum.Failed && 'line-through',
                      )}
                    >
                      {formatted.credit}
                    </Typography>
                    <Typography variant="body">{formatted.amount}</Typography>
                  </div>
                </div>

                <NavigationTab
                  className="mb-12"
                  managedBy={TabManagedBy.INDEX}
                  tabs={[
                    {
                      title: translate('text_17703766701147jewqsvrwfk'),
                      component: (
                        <div className="flex flex-col gap-12">
                          {/* Details section */}
                          <section className="flex flex-col gap-4">
                            <Typography variant="subhead1">
                              {translate('text_1741943835752ac5uwdgkvfj')}
                            </Typography>
                            <div className={tw(GRID)}>
                              {!!name && (
                                <DetailRow
                                  label={translate('text_6419c64eace749372fc72b0f')}
                                  value={name}
                                />
                              )}
                              {typeof priority !== 'undefined' && (
                                <DetailRow
                                  label={translate('text_17703766701153r59onisjcq')}
                                  value={priority}
                                />
                              )}
                              <DetailRow
                                label={translate('text_1741943835752ttg2ano3kju')}
                                value={formatted.credit}
                              />
                              <DetailRow
                                label={translate('text_6419c64eace749372fc72b3e')}
                                value={formatted.amount}
                              />
                              <DetailRow
                                label={translate('text_6560809c38fb9de88d8a52fb')}
                                value={formatted.type}
                              />
                              <DetailRow
                                label={translate('text_63ac86d797f728a87b2f9fa7')}
                                value={
                                  <>
                                    {status === WalletTransactionStatusEnum.Settled &&
                                      translate('text_17419455271371fw602t6rhg')}
                                    {status === WalletTransactionStatusEnum.Pending &&
                                      translate('text_62da6db136909f52c2704c30')}
                                    {status === WalletTransactionStatusEnum.Failed &&
                                      translate('text_63e27c56dfe64b846474ef4e')}
                                  </>
                                }
                              />
                              <DetailRow
                                label={translate('text_1751530295201wwh8zbwv2w9')}
                                value={
                                  source &&
                                  translate(WALLET_TRANSACTION_SOURCE_TRANSLATIONS[source])
                                }
                              />
                              <DetailRow
                                label={translate('text_1741943835752e00705sjtf8')}
                                value={
                                  createdAtDate && `${createdAtDate?.date} ${createdAtDate?.time}`
                                }
                              />
                              <DetailRow
                                label={translate('text_17419438357527l2yykxqmau')}
                                value={
                                  failedAtDate && `${failedAtDate?.date} ${failedAtDate?.time}`
                                }
                              />
                              <DetailRow
                                label={translate('text_17419438357526t0aku37wn0')}
                                value={
                                  settledAtDate && `${settledAtDate?.date} ${settledAtDate?.time}`
                                }
                              />
                              <DetailRow
                                label={translate('text_6298bd525e359200d5ea01f2')}
                                value={
                                  <TypographyWithCopy variant="body" color="grey700">
                                    {id}
                                  </TypographyWithCopy>
                                }
                              />
                            </div>
                          </section>
                          {/* Metadata section */}
                          <section className="flex flex-col gap-4">
                            <Typography variant="subhead1">
                              {translate('text_1737892224510vc53d10q4h5')}
                            </Typography>
                            {!!metadata?.length ? (
                              <div className={tw(GRID)}>
                                {metadata?.map((meta, index) => (
                                  <DetailRow
                                    key={`transaction-metadata-${index}`}
                                    label={meta.key}
                                    value={meta.value}
                                  />
                                ))}
                              </div>
                            ) : (
                              <Typography variant="body" color="grey500">
                                {translate('text_17419455271376kghg3guq5i')}
                              </Typography>
                            )}
                          </section>

                          {/* Invoice section */}
                          {canHaveInvoice && (
                            <section className="flex flex-col gap-4">
                              <Typography variant="subhead1">
                                {translate('text_1770376670114tmqmstyk2qw')}
                              </Typography>
                              {hasNoSuccessfulPaymentButRequiresIt ? (
                                <Alert type="info">
                                  {translate('text_1741943835752na70uvegm9k')}
                                </Alert>
                              ) : (
                                <div className={tw(GRID)}>
                                  <DetailRow
                                    label={translate('text_1741943835752dyeh035aorl')}
                                    value={
                                      <>
                                        {invoice?.invoiceType === InvoiceTypeEnum.Credit &&
                                          translate('text_174194552713793wk0n532oi')}
                                        {invoice?.invoiceType === InvoiceTypeEnum.Subscription &&
                                          translate('text_1741945527137rb74r70jp6v')}
                                      </>
                                    }
                                  />
                                  <DetailRow
                                    label={translate('text_1741944051511g2xahsgoyn7')}
                                    value={
                                      invoice?.id ? (
                                        <TypographyWithCopy variant="body" color="grey700">
                                          {invoice.id}
                                        </TypographyWithCopy>
                                      ) : undefined
                                    }
                                  />
                                  <DetailRow
                                    label={translate('text_64188b3d9735d5007d71226c')}
                                    value={
                                      <Link
                                        className="visited:text-blue focus:underline focus:ring-0"
                                        to={generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
                                          invoiceId: invoice?.id,
                                          customerId: invoice?.customer?.id,
                                          tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
                                        })}
                                      >
                                        {invoice?.number}
                                      </Link>
                                    }
                                  />
                                  <DetailRow
                                    label={translate('text_63eba8c65a6c8043feee2a0f')}
                                    value={
                                      <Status
                                        {...paymentStatusMapping({
                                          status: invoice?.status,
                                          paymentStatus: invoice?.paymentStatus,
                                        })}
                                      />
                                    }
                                  />
                                </div>
                              )}
                            </section>
                          )}
                        </div>
                      ),
                    },
                    {
                      title: translate('text_1770376670114jug6xb8rb4f'),
                      hidden: !canHavePayment,
                      component: (
                        <>
                          {/* Payment section */}
                          {canHavePayment && (
                            <section className="flex flex-col gap-4">
                              <Typography variant="subhead1">
                                {translate('text_1741943835752hd6fcwsfprn')}
                              </Typography>

                              {!hasPayments && (
                                <Alert type="info">
                                  <Typography variant="body" color="grey700">
                                    {translate('text_17703766701152gtr8a2vadt')}
                                  </Typography>
                                </Alert>
                              )}

                              {hasPayments && (
                                <>
                                  <div className="not-last-child:mb-12 not-last-child:pb-12 not-last-child:shadow-b">
                                    {(invoice?.payments ?? [])
                                      .filter((_, index) => {
                                        return !showAllPayments ? index === 0 : true
                                      })
                                      .map((payment, index) => {
                                        let paymentProviderValue: string | JSX.Element =
                                          payment?.providerPaymentId ?? '-'

                                        if (payment?.providerPaymentId) {
                                          let href = ''

                                          if (
                                            payment.paymentProviderType === ProviderTypeEnum.Stripe
                                          ) {
                                            href = buildStripePaymentUrl(payment.providerPaymentId)
                                          }
                                          if (
                                            payment.paymentProviderType ===
                                            ProviderTypeEnum.Gocardless
                                          ) {
                                            href = buildGoCardlessPaymentUrl(
                                              payment.providerPaymentId,
                                            )
                                          }

                                          paymentProviderValue = (
                                            <Link
                                              target="_blank"
                                              rel="noopener noreferrer"
                                              to={href}
                                              className="flex items-center gap-2 visited:text-blue focus:underline focus:ring-0"
                                            >
                                              {payment.providerPaymentId}
                                              <Icon name="outside" />
                                            </Link>
                                          )
                                        }

                                        return (
                                          <div key={`payment-${index}`} className={tw(GRID)}>
                                            <DetailRow
                                              label={translate('text_1741943835752p8v8nrgnuyl')}
                                              value={
                                                payment?.id ? (
                                                  <TypographyWithCopy
                                                    variant="body"
                                                    color="grey700"
                                                  >
                                                    {payment.id}
                                                  </TypographyWithCopy>
                                                ) : undefined
                                              }
                                            />
                                            <DetailRow
                                              label={translate('text_1737112054603c6phsbkyvmx')}
                                              value={paymentProviderValue}
                                            />
                                            <DetailRow
                                              label={translate('text_63eba8c65a6c8043feee2a0f')}
                                              value={
                                                <Status
                                                  {...payablePaymentStatusMapping({
                                                    payablePaymentStatus:
                                                      payment?.payablePaymentStatus ?? undefined,
                                                  })}
                                                />
                                              }
                                            />
                                          </div>
                                        )
                                      })}
                                  </div>
                                  {invoice?.payments &&
                                    invoice?.payments?.length > 1 &&
                                    !showAllPayments && (
                                      <div>
                                        <button
                                          className="size-auto rounded-none p-0 text-blue hover:underline focus:ring"
                                          onClick={() => setShowAllPayments(true)}
                                        >
                                          {translate('text_1741943835752rff77n2oaj6')}
                                        </button>
                                      </div>
                                    )}
                                </>
                              )}
                            </section>
                          )}
                        </>
                      ),
                    },
                    {
                      title: translate('text_1770376670114z4njo02220z'),
                      hidden: !showConsumptionTab,
                      component: (
                        <div className="flex flex-col gap-12">
                          <section className="flex flex-col gap-4">
                            <Typography variant="subhead1">
                              {translate('text_17703766701155zzhjrnqgsz')}
                            </Typography>
                            <Typography>{translate('text_17703831122279c9rz3r08cw')}</Typography>

                            <div className={tw(GRID, 'gap-y-0 sm:gap-y-0')}>
                              <DetailRow
                                label={translate('text_1770381610089co5rhgw8rr8')}
                                value={
                                  <div className="flex">
                                    <Typography color="grey700">{`${transactionBalance.settled.amount}`}</Typography>
                                    <Typography color="grey600">
                                      &nbsp;
                                      {`(${translate('text_62da6ec24a8e24e44f812896', { amount: transactionBalance.settled.creditAmount }, Number(transactionBalance.settled.creditAmount) || 0)})`}
                                    </Typography>
                                  </div>
                                }
                              />

                              <DetailRow
                                label={translate('text_1770381610089rix8snaszn3')}
                                value={
                                  <div className="flex">
                                    <Typography color="grey700">{`${transactionBalance.available.amount}`}</Typography>
                                    <Typography color="grey600">
                                      &nbsp;
                                      {`(${translate('text_62da6ec24a8e24e44f812896', { amount: transactionBalance.available.creditAmount }, Number(transactionBalance.available.creditAmount) || 0)})`}
                                    </Typography>
                                  </div>
                                }
                              />
                            </div>
                          </section>

                          <section className="flex flex-col gap-4">
                            <div className="flex flex-col gap-2">
                              <Typography variant="subhead1">
                                {translate('text_1770381610089sh8aohddi6n')}
                              </Typography>
                              <Typography variant="caption">
                                {translate('text_17703831122279c9rz3r08cw')}
                              </Typography>
                            </div>

                            {!consumptions?.walletTransactionConsumptions?.collection?.length && (
                              <Alert type="info">
                                <Typography variant="body" color="grey700">
                                  {status === WalletTransactionStatusEnum.Failed &&
                                    translate('text_17703831122275gplx4hf9zw')}
                                  {status === WalletTransactionStatusEnum.Pending &&
                                    translate('text_1770383112227fm7xs39y88v')}
                                  {status === WalletTransactionStatusEnum.Settled &&
                                    translate('text_1770381610089ayq9wo7d6xk')}
                                </Typography>
                              </Alert>
                            )}

                            <div className="not-last-child:mb-12 not-last-child:pb-12 not-last-child:shadow-b">
                              <WalletTransactionItems
                                error={consumptionsError}
                                transactions={
                                  consumptions?.walletTransactionConsumptions?.collection
                                }
                                isConsumption={true}
                                isLoading={consumptionsLoading}
                                pagination={{
                                  ...consumptions?.walletTransactionConsumptions?.metadata,
                                  fetchMore: consumptionsFetchMore,
                                }}
                                customerId={customerId}
                                timezone={timezone}
                                wallet={wallet}
                              />
                            </div>
                          </section>
                        </div>
                      ),
                    },
                    {
                      title: translate('text_1770376670114ic8vl4elscw'),
                      hidden: !showFundingTab,
                      component: (
                        <div className="flex flex-col gap-12">
                          <section className="flex flex-col gap-4">
                            <div className="flex flex-col gap-2">
                              <Typography variant="subhead1">
                                {translate('text_1770383112227t2bvzgxawjj')}
                              </Typography>
                              <Typography variant="caption">
                                {translate('text_1770383112227ic0gppa8zt5')}
                              </Typography>
                            </div>

                            <div className="not-last-child:mb-12 not-last-child:pb-12 not-last-child:shadow-b">
                              {!fundings?.walletTransactionFundings?.collection?.length && (
                                <Alert type="info">
                                  <Typography variant="body" color="grey700">
                                    {translate('text_1770383112227bb128kkzkcv')}
                                  </Typography>
                                </Alert>
                              )}

                              <WalletTransactionItems
                                error={fundingsError}
                                transactions={fundings?.walletTransactionFundings?.collection}
                                isConsumption={false}
                                isLoading={fundingsLoading}
                                pagination={{
                                  ...fundings?.walletTransactionFundings?.metadata,
                                  fetchMore: fundingsFetchMore,
                                }}
                                customerId={customerId}
                                timezone={timezone}
                                wallet={wallet}
                              />
                            </div>
                          </section>
                        </div>
                      ),
                    },
                  ]}
                />
              </header>
            </>
          )}
        </div>
      </Drawer>
    )
  },
)

WalletDetailsDrawer.displayName = 'WalletDetailsDrawer'

type DetailRowProps = {
  label: string
  value?: string | ReactNode
}

export const DetailRow: FC<DetailRowProps> = ({ label, value }) => {
  return (
    <>
      <Typography variant="body" color="grey600">
        {label}
      </Typography>
      <Typography variant="body" color={'grey700'}>
        {value || '-'}
      </Typography>
    </>
  )
}
