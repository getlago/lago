import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { FC, ReactNode, useEffect, useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Avatar, AvatarBadge } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Popper } from '~/components/designSystem/Popper'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Table, TableColumn, TableContainerSize } from '~/components/designSystem/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import {
  formatAmount,
  formatCredits,
  getLabelForInboundTransaction,
  getLabelForOutboundTransaction,
} from '~/components/wallets/utils'
import {
  TRANSACTION_AMOUNT_DATA_TEST,
  TRANSACTION_CREDITS_DATA_TEST,
  TRANSACTION_LABEL_DATA_TEST,
  TRANSACTION_REMAINING_CREDITS_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import {
  WalletDetailsDrawer,
  WalletDetailsDrawerRef,
} from '~/components/wallets/WalletDetailsDrawer'
import { addToast } from '~/core/apolloClient'
import { CREATE_WALLET_TOP_UP_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { ResponsiveStyleValue } from '~/core/utils/responsiveProps'
import {
  CurrencyEnum,
  TimezoneEnum,
  useGetWalletTransactionsLazyQuery,
  WalletInfosForTransactionsFragment,
  WalletStatusEnum,
  WalletTransactionDetailsFragmentDoc,
  WalletTransactionForTransactionListItemFragment,
  WalletTransactionForTransactionListItemFragmentDoc,
  WalletTransactionStatusEnum,
  WalletTransactionTransactionTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import EmptyImage from '~/public/images/maneki/empty.svg'
import ErrorImage from '~/public/images/maneki/error.svg'
import { MenuPopper } from '~/styles'
import { tw } from '~/styles/utils'

gql`
  fragment WalletInfosForTransactions on Wallet {
    id
    currency
    status
    ongoingUsageBalanceCents
    creditsOngoingUsageBalance
    rateAmount
    traceable
  }

  query getWalletTransactions($walletId: ID!, $page: Int, $limit: Int) {
    walletTransactions(walletId: $walletId, page: $page, limit: $limit) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        id
        ...WalletTransactionForTransactionListItem
      }
    }
  }

  ${WalletTransactionForTransactionListItemFragmentDoc}
  ${WalletTransactionDetailsFragmentDoc}
`

const concatInfosTextForDisplay = ({
  name,
  date,
  timezone,
}: {
  name: string | null | undefined
  date: string | null | undefined
  timezone: TimezoneEnum | undefined
}) => {
  const formattedDate = date ? intlFormatDateTime(date, { timezone }).date : ''

  return [formattedDate, name].filter(Boolean).join(' • ')
}

interface WalletTransactionListProps {
  customerTimezone?: TimezoneEnum
  isOpen: boolean
  wallet: WalletInfosForTransactionsFragment
  footer: ReactNode
  selectedTransaction?: string | null
  containerSize?: ResponsiveStyleValue<TableContainerSize>
}

export const WalletTransactionList: FC<WalletTransactionListProps> = ({
  customerTimezone,
  isOpen,
  wallet,
  footer,
  selectedTransaction,
  containerSize = 16,
}) => {
  const { translate } = useInternationalization()
  const { customerId } = useParams()
  const navigate = useNavigate()
  const walletDetailsDrawerRef = useRef<WalletDetailsDrawerRef>(null)

  const [getWalletTransactions, { data, error, fetchMore, loading, refetch }] =
    useGetWalletTransactionsLazyQuery({
      variables: { walletId: wallet.id, limit: 20 },
      notifyOnNetworkStatusChange: true,
    })
  const list = data?.walletTransactions?.collection
  const { currentPage = 0, totalPages = 0 } = data?.walletTransactions?.metadata || {}

  const hasData = !!list && !!list?.length
  const hasError = !!error && !loading
  const isLoading = loading && !error
  const isWalletEmpty = !hasData && wallet?.id && wallet?.status !== WalletStatusEnum.Terminated

  useEffect(() => {
    if (isOpen && !data && !loading && !error) {
      getWalletTransactions()
    }
  }, [isOpen, error, data, loading, getWalletTransactions])

  useEffect(() => {
    if (!data || !selectedTransaction) {
      return
    }

    walletDetailsDrawerRef.current?.openDrawer({ transactionId: selectedTransaction })
  }, [data, selectedTransaction])

  const onRowClick = ({ id }: { id: string }) => {
    walletDetailsDrawerRef.current?.openDrawer({ transactionId: id })
  }

  return (
    <>
      <div className="shadow-b">
        {hasError && (
          <GenericPlaceholder
            className="mx-auto py-6 text-center"
            title={translate('text_62d7ffcb1c57d7e6d15bdce3')}
            subtitle={translate('text_62d7ffcb1c57d7e6d15bdce5')}
            buttonTitle={translate('text_62d7ffcb1c57d7e6d15bdce7')}
            buttonVariant="primary"
            buttonAction={() => refetch()}
            image={<ErrorImage width="136" height="104" />}
          />
        )}
        {isLoading &&
          [1, 2, 3].map((i) => (
            <div
              className="flex w-full gap-3 px-3 py-4 shadow-b"
              key={`wallet-transaction-skeleton-${i}`}
            >
              <Skeleton variant="connectorAvatar" size="big" className="mr-3" />
              <div className="flex flex-1 flex-col">
                <Skeleton variant="text" className="max-w-66" />
                <Skeleton variant="text" className="max-w-30" />
              </div>
              <div className="flex flex-1 flex-col items-end justify-end">
                <Skeleton variant="text" className="max-w-36" />
                <Skeleton variant="text" className="max-w-20" />
              </div>
            </div>
          ))}
        {!isLoading && isWalletEmpty && (
          <GenericPlaceholder
            className="mx-auto py-6 text-center"
            title={translate('text_62e0ee200a543924c8f67755')}
            subtitle={translate('text_62e0ee200a543924c8f67759')}
            buttonTitle={translate('text_62e0ee200a543924c8f6775d')}
            buttonVariant="primary"
            buttonAction={() => {
              navigate(
                generatePath(CREATE_WALLET_TOP_UP_ROUTE, {
                  customerId: customerId ?? null,
                  walletId: wallet.id,
                }),
              )
            }}
            image={<EmptyImage width="136" height="104" />}
          />
        )}
        {!isLoading && !isWalletEmpty && (
          <>
            <Table
              name="wallet-transactions-list"
              data={list || []}
              containerSize={containerSize}
              rowSize={72}
              isLoading={isLoading}
              hasError={!!error}
              actionColumnTooltip={() => translate('text_634687079be251fdb438338f')}
              actionColumn={(transaction) =>
                wallet?.status === WalletStatusEnum.Active && (
                  <Popper
                    PopperProps={{ placement: 'bottom-end' }}
                    opener={(opener) => (
                      <div className="flex h-full items-center justify-end">
                        <Tooltip
                          placement="top-start"
                          disableHoverListener={opener.isOpen}
                          title={translate('text_1741251836185jea576d14uj')}
                        >
                          <Button
                            size="medium"
                            variant="quaternary"
                            icon="dots-horizontal"
                            onClick={(e) => {
                              e.preventDefault()
                              e.stopPropagation()
                              opener.onClick()
                            }}
                          />
                        </Tooltip>
                      </div>
                    )}
                  >
                    {({ closePopper }) => (
                      <MenuPopper>
                        <Button
                          startIcon="eye"
                          variant="quaternary"
                          align="left"
                          fullWidth
                          onClick={(e) => {
                            e.preventDefault()
                            e.stopPropagation()
                            onRowClick(transaction)
                            closePopper()
                          }}
                        >
                          {translate('text_1742218191558g0ysnnxbb32')}
                        </Button>

                        <Button
                          startIcon="duplicate"
                          variant="quaternary"
                          align="left"
                          fullWidth
                          onClick={(e) => {
                            e.stopPropagation()
                            copyToClipboard(transaction?.id)
                            addToast({
                              severity: 'info',
                              translateKey: 'text_17412580835361rm20fysfba',
                            })
                            closePopper()
                          }}
                        >
                          {translate('text_1741258064758s59ws4fg2l9')}
                        </Button>
                      </MenuPopper>
                    )}
                  </Popper>
                )
              }
              onRowActionClick={onRowClick}
              columns={[
                {
                  key: 'id',
                  title: translate('text_62da6ec24a8e24e44f81288e'),
                  maxSpace: true,
                  content: ({
                    createdAt,
                    creditAmount,
                    failedAt,
                    name,
                    source,
                    status,
                    settledAt,
                    transactionStatus,
                    transactionType,
                  }) => {
                    const isPending = status === WalletTransactionStatusEnum.Pending
                    const isFailed = status === WalletTransactionStatusEnum.Failed

                    const date = (isPending && settledAt) || (isFailed && failedAt) || createdAt

                    const displayText = concatInfosTextForDisplay({
                      name,
                      date,
                      timezone: customerTimezone,
                    })

                    const isInbound =
                      transactionType === WalletTransactionTransactionTypeEnum.Inbound

                    const label = isInbound
                      ? getLabelForInboundTransaction({
                          translate,
                          source,
                          creditAmount,
                          transactionStatus,
                        })
                      : getLabelForOutboundTransaction({
                          translate,
                          creditAmount,
                          transactionStatus,
                        })

                    const labelColor = 'grey700'
                    const iconName = isInbound ? 'plus' : 'minus'

                    return (
                      <div className="flex min-w-0 flex-1 items-center">
                        <Avatar className="mr-3" size="big" variant="connector">
                          <Icon name={iconName} color="dark" />
                          {isPending && <AvatarBadge icon="sync" color="dark" />}
                          {isFailed && <AvatarBadge icon="stop" color="warning" />}
                        </Avatar>
                        <div className="flex flex-col overflow-hidden">
                          <Typography
                            noWrap
                            variant="bodyHl"
                            color={isPending || isFailed ? 'grey500' : labelColor}
                            data-test={TRANSACTION_LABEL_DATA_TEST}
                          >
                            {label}
                          </Typography>
                          {!!displayText && (
                            <Typography noWrap variant="caption" color="grey600">
                              {displayText}
                            </Typography>
                          )}
                        </div>
                      </div>
                    )
                  },
                },
                {
                  key: 'priority',
                  textAlign: 'right',
                  minWidth: 96,
                  title: translate('text_17703766701153r59onisjcq'),
                  content: ({ priority, transactionType }) => (
                    <div className="flex flex-col">
                      <Typography>
                        {transactionType !== WalletTransactionTransactionTypeEnum.Inbound
                          ? '-'
                          : priority}
                      </Typography>
                      <div className="opacity-0">&nbsp;</div>
                    </div>
                  ),
                },
                {
                  key: 'amount',
                  title: translate('text_62da6ec24a8e24e44f812890'),
                  textAlign: 'right',
                  minWidth: 114,
                  content: ({ amount, creditAmount, status, transactionType }) => {
                    const isPending = status === WalletTransactionStatusEnum.Pending
                    const isFailed = status === WalletTransactionStatusEnum.Failed
                    const isInbound =
                      transactionType === WalletTransactionTransactionTypeEnum.Inbound

                    const creditsColor = isInbound ? 'success600' : 'grey700'

                    const formattedCreditAmount = formatCredits({
                      credits: creditAmount,
                    })

                    const formattedCurrencyAmount = formatAmount({
                      amountCents: amount,
                      currency: wallet?.currency,
                    })

                    const transactionAmountTranslationKey = translate(
                      'text_62da6ec24a8e24e44f812896',
                      {
                        amount: formattedCreditAmount,
                      },
                      Number(creditAmount) || 0,
                    )

                    const sign = isInbound ? '+' : '-'
                    const creditDisplay = `${Number(creditAmount) === 0 ? '' : sign}${transactionAmountTranslationKey}`
                    const amountDisplay = formattedCurrencyAmount

                    return (
                      <div className="flex flex-col">
                        <Typography
                          variant="bodyHl"
                          color={isPending || isFailed ? 'grey500' : creditsColor}
                          data-test={TRANSACTION_CREDITS_DATA_TEST}
                          className={tw('whitespace-nowrap', isFailed && 'line-through')}
                        >
                          {creditDisplay}
                        </Typography>
                        <Typography
                          variant="caption"
                          color="grey600"
                          data-test={TRANSACTION_AMOUNT_DATA_TEST}
                          className="whitespace-nowrap"
                        >
                          {amountDisplay}
                        </Typography>
                      </div>
                    )
                  },
                },
                ...(wallet?.traceable
                  ? ([
                      {
                        key: 'remainingCreditAmount',
                        textAlign: 'right',
                        minWidth: 114,
                        title: translate('text_1770381610089rix8snaszn3'),
                        content: ({
                          remainingAmountCents,
                          remainingCreditAmount,
                          status,
                          transactionType,
                        }) => {
                          const isPending = status === WalletTransactionStatusEnum.Pending
                          const isFailed = status === WalletTransactionStatusEnum.Failed
                          const isInbound =
                            transactionType === WalletTransactionTransactionTypeEnum.Inbound

                          const formattedRemainingCreditAmount = formatCredits({
                            credits: remainingCreditAmount,
                          })
                          const formattedRemainingAmountCents = formatAmount({
                            amountCents: deserializeAmount(
                              remainingAmountCents,
                              wallet?.currency || CurrencyEnum.Usd,
                            )?.toString(),
                            currency: wallet?.currency,
                          })

                          return (
                            <div className="flex flex-col">
                              <Typography
                                variant="bodyHl"
                                color={isPending || isFailed ? 'grey500' : 'grey700'}
                                data-test={TRANSACTION_REMAINING_CREDITS_DATA_TEST}
                                className="whitespace-nowrap"
                              >
                                {!isInbound
                                  ? '-'
                                  : translate(
                                      'text_62da6ec24a8e24e44f812896',
                                      {
                                        amount: formattedRemainingCreditAmount,
                                      },
                                      Number(formattedRemainingCreditAmount) || 0,
                                    )}
                              </Typography>
                              <Typography
                                variant="caption"
                                color="grey600"
                                data-test={TRANSACTION_AMOUNT_DATA_TEST}
                                className="whitespace-nowrap"
                              >
                                {!isInbound ? '-' : formattedRemainingAmountCents}
                              </Typography>
                            </div>
                          )
                        },
                      },
                    ] satisfies TableColumn<WalletTransactionForTransactionListItemFragment>[])
                  : []),
              ]}
            />
          </>
        )}
      </div>
      <div className="flex items-center justify-between gap-4 px-4 py-1">
        {currentPage < totalPages && (
          <Button
            variant="quaternary"
            size="medium"
            onClick={() =>
              fetchMore({
                variables: { page: currentPage + 1 },
              })
            }
          >
            {translate('text_62da6ec24a8e24e44f8128aa')}
          </Button>
        )}
        {footer}
      </div>

      <WalletDetailsDrawer wallet={wallet} ref={walletDetailsDrawerRef} />
    </>
  )
}
