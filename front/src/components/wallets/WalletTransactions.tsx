import { Icon } from 'lago-design-system'
import { DateTime } from 'luxon'
import { FC, PropsWithChildren, useMemo } from 'react'

import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TimezoneDate } from '~/components/TimezoneDate'
import { WalletTransactionList } from '~/components/wallets/WalletTransactionList'
import { WalletTransactionListItem } from '~/components/wallets/WalletTransactionListItem'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { DateFormat, intlFormatDateTime, TimeFormat } from '~/core/timezone/utils'
import {
  TimezoneEnum,
  WalletDetailsFragment,
  WalletStatusEnum,
  WalletTransactionSourceEnum,
  WalletTransactionStatusEnum,
  WalletTransactionTransactionTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { tw } from '~/styles/utils'

export const WALLET_TRANSACTIONS_CONTAINER_TEST_ID = 'wallet-transactions-container'

const TODAY = DateTime.now().toISODate()

interface WalletTransactionsProps {
  wallet: WalletDetailsFragment
  customerTimezone?: TimezoneEnum
  initiallyOpen?: boolean
  selectedTransaction?: string | null
  loading?: boolean
}

export const WalletTransactions: FC<WalletTransactionsProps> = ({
  customerTimezone,
  wallet,
  selectedTransaction,
  loading,
}) => {
  const {
    balanceCents,
    consumedAmountCents,
    consumedCredits,
    creditsBalance,
    currency,
    expirationAt,
    lastBalanceSyncAt,
    lastConsumedCreditAt,
    lastOngoingBalanceSyncAt,
    status,
    terminatedAt,
    ongoingBalanceCents,
    creditsOngoingBalance,
  } = wallet
  const { isPremium } = useCurrentUser()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const [creditAmountUnit = '0', creditAmountCents = '00'] = String(creditsBalance).split('.')
  const [consumedCreditUnit = '0', consumedCreditCents = '00'] =
    String(creditsOngoingBalance).split('.')
  const { translate } = useInternationalization()
  const isWalletActive = status === WalletStatusEnum.Active

  const { formattedLastOngoingBalanceSyncAt, formattedLastBalanceSyncAt } = useMemo(() => {
    const dateConfig = {
      timezone: TimezoneEnum.TzUtc,
      formatDate: DateFormat.DATE_MED,
      formatTime: TimeFormat.TIME_24_WITH_SECONDS,
    }

    const localFormattedLastOngoingBalanceSyncAt = intlFormatDateTime(
      lastOngoingBalanceSyncAt || DateTime.now(),
      dateConfig,
    )

    const localFormattedLastBalanceSyncAt = intlFormatDateTime(
      lastBalanceSyncAt || DateTime.now(),
      dateConfig,
    )

    return {
      formattedLastOngoingBalanceSyncAt: `${localFormattedLastOngoingBalanceSyncAt.date} ${localFormattedLastOngoingBalanceSyncAt.time} ${localFormattedLastOngoingBalanceSyncAt.timezone}`,
      formattedLastBalanceSyncAt: `${localFormattedLastBalanceSyncAt.date} ${localFormattedLastBalanceSyncAt.time} ${localFormattedLastBalanceSyncAt.timezone}`,
    }
  }, [lastOngoingBalanceSyncAt, lastBalanceSyncAt])

  return (
    <div data-test={WALLET_TRANSACTIONS_CONTAINER_TEST_ID} className="flex w-full flex-col">
      <div className="flex flex-row items-end gap-8 px-0 pb-4 shadow-b">
        <div className="flex flex-col gap-1">
          <div className="flex items-center [&_*]:flex">
            <Typography className="mr-1" variant="captionHl" color="grey600">
              {translate('text_65ae73ebe3a66bec2b91d747')}
            </Typography>
            <Tooltip
              className="flex h-5 items-end"
              placement="bottom-start"
              title={translate('text_65ae73ebe3a66bec2b91d741', {
                date: formattedLastBalanceSyncAt,
              })}
            >
              <Icon name="info-circle" />
            </Tooltip>
          </div>
          <DetailSummaryLine className="items-baseline">
            <Typography color={isWalletActive ? 'grey700' : 'grey600'} variant="subhead1" noWrap>
              {creditAmountUnit}
            </Typography>
            <Typography
              className="mr-1"
              color={isWalletActive ? 'grey700' : 'grey600'}
              variant="captionHl"
            >
              .{creditAmountCents}
            </Typography>
            <Typography color={isWalletActive ? 'grey700' : 'grey600'} variant="captionHl">
              {translate('text_62da6ec24a8e24e44f81287a', undefined, Number(creditAmountUnit) || 0)}
            </Typography>
          </DetailSummaryLine>
          <DetailSummaryLine>
            <Typography color="grey600" variant="caption">
              {intlFormatNumber(deserializeAmount(balanceCents, currency), {
                currencyDisplay: 'symbol',
                currency,
              })}
            </Typography>
          </DetailSummaryLine>
        </div>

        {isWalletActive && (
          <div className="flex flex-col gap-1">
            <DetailSummaryLine>
              <Typography className="mr-1" variant="captionHl" color="grey600">
                {translate('text_65ae73ebe3a66bec2b91d75f')}
              </Typography>
              <Tooltip
                className="flex h-5 items-end"
                placement="bottom-start"
                title={translate('text_65ae73ebe3a66bec2b91d749', {
                  date: formattedLastOngoingBalanceSyncAt,
                })}
              >
                <Icon name="info-circle" />
              </Tooltip>
            </DetailSummaryLine>
            <DetailSummaryLine className="items-baseline">
              <Typography
                blur={!isPremium}
                color={isWalletActive ? 'grey700' : 'grey600'}
                variant="subhead1"
                noWrap
              >
                {isPremium ? consumedCreditUnit : '0'}
              </Typography>
              <Typography
                className="mr-1"
                blur={!isPremium}
                color={isWalletActive ? 'grey700' : 'grey600'}
                variant="captionHl"
              >
                .{isPremium ? consumedCreditCents : '00'}
              </Typography>
              <Typography
                color={isWalletActive ? 'grey700' : 'grey600'}
                variant="captionHl"
                blur={!isPremium}
              >
                {translate(
                  'text_62da6ec24a8e24e44f812884',
                  undefined,
                  Number(consumedCreditUnit) || 0,
                )}
              </Typography>
            </DetailSummaryLine>
            <DetailSummaryLine>
              <Typography color="grey600" variant="caption" blur={!isPremium}>
                {intlFormatNumber(
                  deserializeAmount(isPremium ? ongoingBalanceCents : 0, currency),
                  {
                    currencyDisplay: 'symbol',
                    currency,
                  },
                )}
              </Typography>
            </DetailSummaryLine>
          </div>
        )}

        <div className="flex flex-col gap-1">
          <DetailSummaryLine>
            <Typography color="grey500" variant="captionHl">
              {isWalletActive
                ? translate('text_62da6ec24a8e24e44f81288a')
                : translate('text_62e2a2f2a79d60429eff3035')}
            </Typography>
          </DetailSummaryLine>
          <DetailSummaryLine>
            {!isWalletActive && (
              <TimezoneDate
                mainTypographyProps={{ variant: 'caption', color: 'grey700' }}
                date={terminatedAt}
                customerTimezone={customerTimezone}
              />
            )}
            {isWalletActive && expirationAt && (
              <TimezoneDate
                mainTypographyProps={{ variant: 'caption', color: 'grey700' }}
                date={expirationAt}
                customerTimezone={customerTimezone}
              />
            )}
            {isWalletActive && !expirationAt && (
              <Typography color="grey700" variant="caption">
                {translate('text_62da6ec24a8e24e44f81288c')}
              </Typography>
            )}
          </DetailSummaryLine>
        </div>
      </div>

      {isWalletActive && (
        <WalletTransactionListItem
          isRealTimeTransaction
          transaction={{
            id: 'real-time-transaction-id',
            amount: String(deserializeAmount(wallet.ongoingUsageBalanceCents, wallet.currency)),
            creditAmount: String(wallet.creditsOngoingUsageBalance),
            createdAt: TODAY,
            settledAt: TODAY,
            wallet,
            status: WalletTransactionStatusEnum.Settled,
            transactionType: WalletTransactionTransactionTypeEnum.Outbound,
            transactionStatus: undefined,
            source: WalletTransactionSourceEnum.Manual,
          }}
          customerTimezone={customerTimezone}
          isWalletActive={isWalletActive}
          rowClassName="px-0"
        />
      )}

      {!loading && wallet?.id && (
        <WalletTransactionList
          customerTimezone={customerTimezone}
          isOpen={true}
          wallet={wallet}
          selectedTransaction={selectedTransaction}
          footer={
            <Typography
              className="ml-auto flex items-center gap-1"
              color="grey600"
              variant="caption"
            >
              {`${translate('text_65ae73ece3a66bec2b91d7d7')} ${consumedCredits} ${translate('text_62da6ec24a8e24e44f81287a', undefined, Number(consumedCredits) || 0)} | ${intlFormatNumber(
                deserializeAmount(consumedAmountCents, currency),
                {
                  currencyDisplay: 'symbol',
                  currency,
                },
              )}`}
              <Tooltip
                className="flex h-5 items-end"
                placement="top-end"
                title={translate('text_62da6db136909f52c2704c40', {
                  date: intlFormatDateTimeOrgaTZ(lastConsumedCreditAt || DateTime.now()).date,
                })}
              >
                <Icon name="info-circle" />
              </Tooltip>
            </Typography>
          }
          containerSize={0}
        />
      )}
    </div>
  )
}

const DetailSummaryLine: FC<PropsWithChildren<{ className?: string }>> = ({
  className,
  children,
}) => {
  return <div className={tw('flex items-center [&_*]:flex', className)}>{children}</div>
}
