import { gql } from '@apollo/client'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Table, TableColumn } from '~/components/designSystem/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { PageSectionTitle } from '~/components/layouts/Section'
import { formatAmount, formatCredits } from '~/components/wallets/utils'
import { CREATE_WALLET_DATA_TEST } from '~/components/wallets/utils/dataTestConstants'
import WalletActions from '~/components/wallets/WalletActions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CREATE_WALLET_ROUTE, useNavigate, WALLET_DETAILS_ROUTE } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  CustomerWalletFragment,
  TimezoneEnum,
  useGetCustomerWalletListQuery,
  WalletForUpdateFragmentDoc,
  WalletInfosForTransactionsFragmentDoc,
  WalletStatusEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import { WalletDetailsTabsOptionsEnum } from '~/pages/wallet/WalletDetails'
import ErrorImage from '~/public/images/maneki/error.svg'

const ACTIVE_WALLET_COUNT_LIMIT = 6

gql`
  fragment WalletAccordion on Wallet {
    id
    code
    balanceCents
    consumedAmountCents
    consumedCredits
    createdAt
    creditsBalance
    currency
    expirationAt
    lastBalanceSyncAt
    lastConsumedCreditAt
    lastOngoingBalanceSyncAt
    name
    rateAmount
    status
    terminatedAt
    ongoingBalanceCents
    creditsOngoingBalance
    priority

    ...WalletInfosForTransactions
  }

  fragment CustomerWallet on Wallet {
    ...WalletForUpdate
    ...WalletAccordion
    ...WalletInfosForTransactions
  }

  query getCustomerWalletList($customerId: ID!, $page: Int, $limit: Int) {
    wallets(customerId: $customerId, page: $page, limit: $limit) {
      metadata {
        currentPage
        totalPages
        customerActiveWalletsCount
      }
      collection {
        ...CustomerWallet
      }
    }
  }

  ${WalletInfosForTransactionsFragmentDoc}
  ${WalletForUpdateFragmentDoc}
`

export const CUSTOMER_WALLET_LIST_LOADING_TEST_ID = 'customer-wallet-list-loading'
export const CUSTOMER_WALLET_LIST_EMPTY_TEST_ID = 'customer-wallet-list-empty'

interface CustomerWalletListProps {
  customerId: string
  customerTimezone?: TimezoneEnum
}

export const CustomerWalletsList = ({ customerId }: CustomerWalletListProps) => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const { data, error, loading, fetchMore } = useGetCustomerWalletListQuery({
    variables: { customerId, page: 0, limit: 10 },
  })
  const walletsCollection = data?.wallets?.collection || []
  const hasMoreThanActiveWalletsLimit =
    (data?.wallets?.metadata?.customerActiveWalletsCount || 0) >= ACTIVE_WALLET_COUNT_LIMIT

  const columns: TableColumn<CustomerWalletFragment>[] = [
    {
      key: 'status',
      title: translate('text_1772536695408q802eishgnx'),
      content: ({ status }) => (
        <div className="pl-1">
          {status === WalletStatusEnum.Active && (
            <Status type={StatusType.success} label={translate('text_624efab67eb2570101d1180e')} />
          )}

          {status === WalletStatusEnum.Terminated && (
            <Status type={StatusType.danger} label={translate('text_62e2a2f2a79d60429eff3035')} />
          )}
        </div>
      ),
    },
    {
      key: 'id',
      maxSpace: true,
      title: translate('text_1772536695408sddzumtfq2t'),
      content: ({ code, createdAt, currency, name, rateAmount }) => {
        const rateLabel = translate('text_62da6ec24a8e24e44f812872', {
          rateAmount: intlFormatNumber(Number(rateAmount) || 0, {
            currencyDisplay: 'symbol',
            currency,
          }),
        })

        return (
          <div className="flex flex-col">
            <Typography variant="bodyHl" color="grey700">
              {name ||
                translate('text_62da6ec24a8e24e44f8128b2', {
                  createdAt: intlFormatDateTimeOrgaTZ(createdAt).date,
                })}
            </Typography>
            {code ? (
              <div className="flex items-baseline gap-1">
                <TypographyWithCopy className="shrink-0" compact noWrap variant="caption">
                  {code}
                </TypographyWithCopy>
                <Typography className="min-w-0" variant="caption" color="grey600" noWrap>
                  {`• ${rateLabel}`}
                </Typography>
              </div>
            ) : (
              <Typography variant="caption" color="grey600">
                {rateLabel}
              </Typography>
            )}
          </div>
        )
      },
    },
    {
      key: 'balanceCents',
      title: translate('text_1772536695408yws01ove0kv'),
      textAlign: 'right',
      content: ({ balanceCents, currency, creditsBalance }) => {
        const amount = formatCredits({
          credits: creditsBalance?.toString(),
        })

        const amountCents = formatAmount({
          amountCents: deserializeAmount(balanceCents, currency || CurrencyEnum.Usd)?.toString(),
          currency: currency,
        })

        return (
          <div className="flex flex-col">
            <Typography color="grey700" variant="body" noWrap>
              {amountCents}
            </Typography>

            <Typography color="grey600" variant="caption" noWrap>
              {translate(
                'text_62da6ec24a8e24e44f812896',
                {
                  amount: amount,
                },
                Number(amount) || 0,
              )}
            </Typography>
          </div>
        )
      },
    },
    {
      key: 'ongoingBalanceCents',
      title: translate('text_17725366954080ut3kxr0kvl'),
      textAlign: 'right',
      content: ({ currency, creditsOngoingBalance, ongoingBalanceCents, status }) => {
        const amount = formatCredits({
          credits: creditsOngoingBalance?.toString(),
        })

        const amountCents = formatAmount({
          amountCents: deserializeAmount(
            ongoingBalanceCents,
            currency || CurrencyEnum.Usd,
          )?.toString(),
          currency: currency,
        })

        const isWalletActive = status === WalletStatusEnum.Active

        return !isWalletActive ? null : (
          <div className="flex flex-col">
            <Typography color="grey700" variant="body" noWrap>
              {amountCents}
            </Typography>

            <Typography color="grey600" variant="caption" noWrap>
              {translate(
                'text_62da6ec24a8e24e44f812896',
                {
                  amount: amount,
                },
                Number(amount) || 0,
              )}
            </Typography>
          </div>
        )
      },
    },
    {
      key: 'priority',
      title: translate('text_1772536695408m4r9zfc2tcw'),
      textAlign: 'right',
      content: ({ priority }) => (
        <Typography variant="caption" color="grey600">
          {priority || '-'}
        </Typography>
      ),
    },
  ]

  if (!loading && !!error) {
    return (
      <GenericPlaceholder
        title={translate('text_62e0ee200a543924c8f6775e')}
        subtitle={translate('text_62e0ee200a543924c8f67760')}
        buttonTitle={translate('text_62e0ee200a543924c8f67762')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  return (
    <>
      <PageSectionTitle
        title={translate('text_62d175066d2dbf1d50bc9384')}
        subtitle={translate('text_1737647019083bbxjrexen5s')}
        customAction={
          <>
            {hasPermissions(['walletsCreate']) && (
              <Tooltip
                title={translate(
                  'text_176071328361044kwwdb4re4',
                  {
                    count: ACTIVE_WALLET_COUNT_LIMIT,
                  },
                  ACTIVE_WALLET_COUNT_LIMIT,
                )}
                disableHoverListener={!hasMoreThanActiveWalletsLimit}
              >
                <Button
                  variant="inline"
                  disabled={hasMoreThanActiveWalletsLimit || loading}
                  onClick={() =>
                    navigate(
                      generatePath(CREATE_WALLET_ROUTE, {
                        customerId: customerId as string,
                      }),
                    )
                  }
                  data-test={CREATE_WALLET_DATA_TEST}
                >
                  {translate('text_62d175066d2dbf1d50bc9382')}
                </Button>
              </Tooltip>
            )}
          </>
        }
      />

      {loading && (
        <div data-test={CUSTOMER_WALLET_LIST_LOADING_TEST_ID} className="flex flex-col gap-4">
          {[1, 2, 3].map((i) => (
            <Skeleton key={`customer-wallet-list-${i}`} variant="text" />
          ))}
        </div>
      )}

      {!loading && !walletsCollection.length && (
        <Typography data-test={CUSTOMER_WALLET_LIST_EMPTY_TEST_ID} className="text-grey-500">
          {translate('text_62d175066d2dbf1d50bc9386')}
        </Typography>
      )}

      {!loading && !!walletsCollection.length && (
        <InfiniteScroll
          onBottom={() => {
            const { currentPage = 0, totalPages = 0 } = data?.wallets?.metadata || {}

            currentPage < totalPages &&
              !loading &&
              fetchMore({
                variables: { page: currentPage + 1 },
              })
          }}
        >
          <Table
            name="customer-wallet-list"
            data={walletsCollection}
            isLoading={loading}
            hasError={!!error}
            containerSize={0}
            rowSize={72}
            onRowActionLink={({ id }) =>
              generatePath(WALLET_DETAILS_ROUTE, {
                customerId,
                walletId: id,
                tab: WalletDetailsTabsOptionsEnum.overview,
              })
            }
            columns={columns}
            actionColumn={({ creditsBalance, currency, id, rateAmount, status }) => {
              return (
                <WalletActions
                  walletId={id}
                  customerId={customerId}
                  status={status}
                  creditsBalance={creditsBalance}
                  rateAmount={rateAmount}
                  currency={currency}
                />
              )
            }}
          />
        </InfiniteScroll>
      )}
    </>
  )
}
