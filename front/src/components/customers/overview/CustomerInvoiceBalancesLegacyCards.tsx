import Stack from '@mui/material/Stack'
import { DateTime } from 'luxon'
import { FC, useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { OverviewCard } from '~/components/OverviewCard'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { isSameDay, TimeFormat } from '~/core/timezone'
import { LocaleEnum } from '~/core/translations'
import {
  CurrencyEnum,
  GetCustomerGrossRevenuesQuery,
  GetCustomerOverdueBalancesQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useIsCustomerReadyForOverduePayment } from '~/hooks/useIsCustomerReadyForOverduePayment'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

export const OVERDUE_INVOICES_ALERT_TEST_ID = 'overdue-invoices-alert'

type GrossRevenueItem = NonNullable<
  GetCustomerGrossRevenuesQuery['grossRevenues']['collection']
>[number]
type OverdueBalanceItem = NonNullable<
  GetCustomerOverdueBalancesQuery['overdueBalances']['collection']
>[number]

interface CustomerInvoiceBalancesLegacyCardsProps {
  currency: CurrencyEnum
  grossRevenues: GrossRevenueItem[]
  grossRevenuesLoading: boolean
  grossRevenuesError?: unknown
  overdueBalances: OverdueBalanceItem[]
  overdueBalancesLoading: boolean
  overdueBalancesError?: unknown
  lastPaymentRequestCreatedAt?: string
  refreshOverdueBalances: () => void
}

/**
 * Legacy 2-card layout (Gross revenue + Total overdue) plus the overdue alert.
 *
 * Rendered as fallback when **both** `multi_currency` and `multi_entity_billing`
 * are off, preserving the pre-epic UX byte-identical to today.
 *
 * @deprecated Delete this component when `multi_entity_billing` reaches GA
 * (ING-75 — flag removal). The breakdown table covers all post-GA cases.
 */
export const CustomerInvoiceBalancesLegacyCards: FC<CustomerInvoiceBalancesLegacyCardsProps> = ({
  currency,
  grossRevenues,
  grossRevenuesLoading,
  grossRevenuesError,
  overdueBalances,
  overdueBalancesLoading,
  overdueBalancesError,
  lastPaymentRequestCreatedAt,
  refreshOverdueBalances,
}) => {
  const { translate } = useInternationalization()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()
  const { customerId } = useParams()
  const navigate = useNavigate()
  const { hasPermissions } = usePermissions()
  const { isCustomerReadyForOverduePayment, loading: isPaymentProcessingStatusLoading } =
    useIsCustomerReadyForOverduePayment()

  const grossRevenuesAggregate = grossRevenues.reduce(
    (acc, revenue) => ({
      amountCents: acc.amountCents + deserializeAmount(revenue.amountCents, currency),
      invoicesCount: acc.invoicesCount + Number(revenue.invoicesCount ?? 0),
    }),
    { amountCents: 0, invoicesCount: 0 },
  )

  const overdueAggregate = overdueBalances.reduce(
    (acc, { amountCents, lagoInvoiceIds }) => ({
      amountCents: acc.amountCents + deserializeAmount(amountCents, currency),
      invoiceCount: acc.invoiceCount + lagoInvoiceIds.length,
    }),
    { amountCents: 0, invoiceCount: 0 },
  )

  const hasOverdueInvoices = overdueAggregate.invoiceCount > 0

  const showOverdueAlert =
    hasOverdueInvoices &&
    !overdueBalancesError &&
    !isPaymentProcessingStatusLoading &&
    isCustomerReadyForOverduePayment

  const today = useMemo(() => DateTime.now().toUTC(), [])
  const lastPaymentRequestDate = useMemo(
    () => DateTime.fromISO(lastPaymentRequestCreatedAt ?? '').toUTC(),
    [lastPaymentRequestCreatedAt],
  )
  const hasMadePaymentRequestToday = isSameDay(lastPaymentRequestDate, today)

  return (
    <Stack gap={4}>
      {showOverdueAlert && (
        <Alert
          type="warning"
          data-test={OVERDUE_INVOICES_ALERT_TEST_ID}
          ButtonProps={
            !overdueBalancesLoading
              ? {
                  label: translate('text_66b258f62100490d0eb5caa2'),
                  onClick: () =>
                    navigate(
                      generatePath(CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE, {
                        customerId: customerId ?? '',
                      }),
                    ),
                }
              : undefined
          }
        >
          {overdueBalancesLoading ? (
            <Stack flexDirection="column" gap={1}>
              <Skeleton variant="text" className="w-37" />
              <Skeleton variant="text" className="w-20" />
            </Stack>
          ) : (
            <Stack flexDirection="column" gap={1}>
              <Typography variant="bodyHl" color="textSecondary">
                {translate(
                  'text_6670a7222702d70114cc7955',
                  {
                    count: overdueAggregate.invoiceCount,
                    amount: intlFormatNumber(overdueAggregate.amountCents, {
                      currencyDisplay: 'symbol',
                      currency,
                    }),
                  },
                  overdueAggregate.invoiceCount,
                )}
              </Typography>
              <Typography variant="caption">
                {hasMadePaymentRequestToday
                  ? translate('text_66b4f00bd67ccc185ea75c70', {
                      relativeDay: lastPaymentRequestDate.toRelativeCalendar({
                        locale: LocaleEnum.en,
                      }),
                      time: lastPaymentRequestCreatedAt
                        ? intlFormatDateTimeOrgaTZ(lastPaymentRequestCreatedAt, {
                            formatTime: TimeFormat.TIME_24_WITH_SECONDS,
                          }).time
                        : '-',
                    })
                  : translate('text_6670a2a7ae3562006c4ee3db')}
              </Typography>
            </Stack>
          )}
        </Alert>
      )}

      <Stack flexDirection="row" gap={4}>
        {hasPermissions(['analyticsView']) && !grossRevenuesError && (
          <OverviewCard
            isLoading={grossRevenuesLoading}
            title={translate('text_6553885df387fd0097fd7385')}
            tooltipContent={translate('text_65564e8e4af2340050d431bf')}
            content={intlFormatNumber(grossRevenuesAggregate.amountCents, {
              currencyDisplay: 'symbol',
              currency,
            })}
            caption={translate(
              'text_6670a7222702d70114cc795c',
              { count: grossRevenuesAggregate.invoicesCount },
              grossRevenuesAggregate.invoicesCount,
            )}
          />
        )}
        {hasPermissions(['analyticsView']) && !overdueBalancesError && (
          <OverviewCard
            isLoading={overdueBalancesLoading}
            title={translate('text_6670a7222702d70114cc795a')}
            tooltipContent={translate('text_6670a2a7ae3562006c4ee3e7')}
            content={intlFormatNumber(overdueAggregate.amountCents, {
              currencyDisplay: 'symbol',
              currency,
            })}
            caption={translate(
              'text_6670a7222702d70114cc795c',
              { count: overdueAggregate.invoiceCount },
              overdueAggregate.invoiceCount,
            )}
            isAccentContent={hasOverdueInvoices}
            refresh={refreshOverdueBalances}
          />
        )}
      </Stack>
    </Stack>
  )
}
