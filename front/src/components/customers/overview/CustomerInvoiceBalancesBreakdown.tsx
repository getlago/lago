import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { BillingEntityLabel } from '~/components/billingEntity/BillingEntityLabel'
import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Table, TableColumn } from '~/components/designSystem/Table'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  FeatureFlagEnum,
  GetCustomerGrossRevenuesQuery,
  GetCustomerOverdueBalancesQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { tw } from '~/styles/utils'

export const BREAKDOWN_ENTITY_CELL = 'breakdown-entity-cell'
export const BREAKDOWN_REQUEST_PAYMENT_BUTTON = 'breakdown-request-payment-button'

type GrossRevenueItem = NonNullable<
  GetCustomerGrossRevenuesQuery['grossRevenues']['collection']
>[number]
type OverdueBalanceItem = NonNullable<
  GetCustomerOverdueBalancesQuery['overdueBalances']['collection']
>[number]

type InvoiceBalanceRow = {
  id: string
  currency: CurrencyEnum
  billingEntityId: string | null
  grossRevenueAmount: number
  grossRevenueInvoicesCount: number
  overdueAmount: number
  overdueInvoicesCount: number
}

interface CustomerInvoiceBalancesBreakdownProps {
  grossRevenues: GrossRevenueItem[]
  overdueBalances: OverdueBalanceItem[]
  customerBillingEntity?: { id: string; code: string; name?: string | null } | null
  isLoading?: boolean
}

const rowKey = (currency: CurrencyEnum, billingEntityId: string | null) =>
  `${currency}|${billingEntityId ?? 'inherit'}`

const emptyRow = (currency: CurrencyEnum, billingEntityId: string | null): InvoiceBalanceRow => ({
  id: rowKey(currency, billingEntityId),
  currency,
  billingEntityId,
  grossRevenueAmount: 0,
  grossRevenueInvoicesCount: 0,
  overdueAmount: 0,
  overdueInvoicesCount: 0,
})

/**
 * Per (currency × billing_entity) breakdown of a customer's invoice balances.
 * Aggregates monthly `grossRevenues` and `overdueBalances` into one row per
 * bucket. Hides nothing — overdue=0 rows render with a disabled "Request
 * payment" button so the operator sees the full balance picture.
 *
 * Rendered when at least one of `multi_currency` / `multi_entity_billing`
 * is enabled. The parent (`CustomerOverview`) handles flag gating and falls
 * back to the legacy 2-card layout when both flags are off.
 */
export const CustomerInvoiceBalancesBreakdown = ({
  grossRevenues,
  overdueBalances,
  customerBillingEntity,
  isLoading = false,
}: CustomerInvoiceBalancesBreakdownProps) => {
  const { translate } = useInternationalization()
  const { customerId } = useParams()
  const navigate = useNavigate()
  const { hasFeatureFlag } = useOrganizationInfos()
  const hasMultiCurrency = hasFeatureFlag(FeatureFlagEnum.MultiCurrency)
  const hasMultiEntityBilling = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)

  const rows = useMemo<InvoiceBalanceRow[]>(() => {
    const map = new Map<string, InvoiceBalanceRow>()

    for (const item of grossRevenues) {
      // Rows without a currency are not orderable into a bucket — skip them.
      if (!item.currency) continue
      const billingEntityId = item.billingEntityId ?? null
      const k = rowKey(item.currency, billingEntityId)
      const row = map.get(k) ?? emptyRow(item.currency, billingEntityId)

      row.grossRevenueAmount += deserializeAmount(item.amountCents, item.currency)
      row.grossRevenueInvoicesCount += Number(item.invoicesCount ?? 0)
      map.set(k, row)
    }

    for (const item of overdueBalances) {
      if (!item.currency) continue
      const billingEntityId = item.billingEntityId ?? null
      const k = rowKey(item.currency, billingEntityId)
      const row = map.get(k) ?? emptyRow(item.currency, billingEntityId)

      row.overdueAmount += deserializeAmount(item.amountCents, item.currency)
      row.overdueInvoicesCount += item.lagoInvoiceIds.length
      map.set(k, row)
    }

    return Array.from(map.values())
  }, [grossRevenues, overdueBalances])

  const columns: TableColumn<InvoiceBalanceRow>[] = useMemo(
    () => [
      {
        key: 'currency',
        minWidth: 80,
        title: translate('text_632b4acf0c41206cbcb8c324'),
        content: ({ currency }) => <Chip size="medium" label={currency} />,
      },
      {
        key: 'billingEntityId',
        minWidth: 160,
        maxWidth: 320,
        title: translate('text_17436114971570doqrwuwhf0'),
        // `BillingEntityLabel` runs `useBillingEntitiesOptions()` per row. The
        // hook hits the same `getBillingEntities` query which Apollo dedupes
        // into a single in-flight request, so N rows = 1 network call. The
        // per-row `options.find()` is O(N) over a handful of org entities —
        // intentional simplicity, do not hoist.
        content: ({ billingEntityId }) => (
          <Typography variant="body" color="grey700" noWrap data-test={BREAKDOWN_ENTITY_CELL}>
            <BillingEntityLabel ownId={billingEntityId} customerEntity={customerBillingEntity} />
          </Typography>
        ),
      },
      {
        key: 'grossRevenueAmount',
        textAlign: 'right',
        maxSpace: true,
        minWidth: 140,
        title: translate('text_6553885df387fd0097fd7385'),
        content: ({ grossRevenueAmount, grossRevenueInvoicesCount, currency }) => (
          <div className="flex flex-col">
            <Typography variant="body" color="grey700">
              {intlFormatNumber(grossRevenueAmount, {
                currencyDisplay: 'symbol',
                currency,
              })}
            </Typography>
            <Typography variant="caption" color="grey600">
              {translate(
                'text_6670a7222702d70114cc795c',
                { count: grossRevenueInvoicesCount },
                grossRevenueInvoicesCount,
              )}
            </Typography>
          </div>
        ),
      },
      {
        key: 'overdueAmount',
        textAlign: 'right',
        minWidth: 140,
        title: translate('text_666c5b12fea4aa1e1b26bf55'),
        content: ({ overdueAmount, overdueInvoicesCount, currency }) => {
          const hasOverdue = overdueAmount > 0 && overdueInvoicesCount > 0

          return (
            <div className="flex flex-col">
              <Typography
                variant="body"
                className={tw(hasOverdue ? 'text-yellow-700' : 'text-grey-600')}
              >
                {intlFormatNumber(overdueAmount, {
                  currencyDisplay: 'symbol',
                  currency,
                })}
              </Typography>
              <Typography variant="caption" color="grey600">
                {translate(
                  'text_6670a7222702d70114cc795c',
                  { count: overdueInvoicesCount },
                  overdueInvoicesCount,
                )}
              </Typography>
            </div>
          )
        },
      },
      {
        key: 'id',
        minWidth: 120,
        title: '',
        content: ({ currency, billingEntityId, overdueAmount, overdueInvoicesCount }) => {
          const canRequest = overdueAmount > 0 && overdueInvoicesCount > 0

          return (
            <Button
              variant="quaternary"
              data-test={BREAKDOWN_REQUEST_PAYMENT_BUTTON}
              disabled={!canRequest}
              onClick={() => {
                const params = new URLSearchParams()

                // Forward each scope only when its feature flag is enabled, so
                // the URL mirrors the page guard logic (single-flag orgs don't
                // get a redundant param).
                if (hasMultiCurrency) {
                  params.set('currency', currency)
                }
                if (hasMultiEntityBilling && billingEntityId) {
                  params.set('billingEntityId', billingEntityId)
                }

                navigate({
                  pathname: generatePath(CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE, {
                    customerId: customerId ?? '',
                  }),
                  search: params.toString() ? `?${params.toString()}` : '',
                })
              }}
            >
              {translate('text_66b258f62100490d0eb5caa2')}
            </Button>
          )
        },
      },
    ],
    [
      translate,
      customerBillingEntity,
      customerId,
      hasMultiCurrency,
      hasMultiEntityBilling,
      navigate,
    ],
  )

  return (
    <Table
      name="customer-invoice-balances-breakdown"
      data={rows}
      containerSize={{ default: 0 }}
      rowSize={72}
      columns={columns}
      isLoading={isLoading}
      placeholder={{
        emptyState: {
          title: translate('text_1779787031619tx5g643tprj'),
          subtitle: translate('text_1779787031619oysgpqyces5'),
        },
      }}
    />
  )
}
