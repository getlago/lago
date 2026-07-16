import { gql } from '@apollo/client'
import { tw } from 'lago-design-system'
import { DateTime } from 'luxon'
import { createContext, ReactNode, useCallback, useContext, useMemo, useState } from 'react'
import { MemoryRouter } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { NavigationTab, TabManagedBy } from '~/components/designSystem/NavigationTab'
import { Table } from '~/components/designSystem/Table'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { useDrawer } from '~/components/drawers/useDrawer'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { DetailRow, GRID } from '~/components/wallets/WalletDetailsDrawer'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { FeeForViewFeeDetailsDrawerFragment, FeeTypesEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import {
  VIEW_FEE_DETAILS_DRAWER_TEST_ID,
  VIEW_FEE_DETAILS_HEADER_TEST_ID,
  VIEW_FEE_DETAILS_OVERVIEW_TEST_ID,
  VIEW_FEE_DETAILS_PGK_TABLE_TEST_ID,
  VIEW_FEE_DETAILS_SOURCE_ITEM_TEST_ID,
} from './invoiceDetailsTestIds'

gql`
  fragment FeeForViewFeeDetailsDrawer on Fee {
    id
    amountCents
    amountCurrency
    preciseAmountCents
    preciseCouponsAmountCents
    subTotalExcludingTaxesAmountCents
    subTotalExcludingTaxesPreciseAmountCents
    taxesRate
    taxesAmountCents
    taxesPreciseAmountCents
    totalAmountCents
    preciseTotalAmountCents
    units
    eventsCount
    payInAdvance
    feeType
    itemCode
    itemName
    itemType
    invoiceDisplayName
    properties {
      fromDatetime
      toDatetime
    }
    trueUpParentFee {
      id
    }
    subscription {
      id
      plan {
        id
        name
        interval
      }
    }
    charge {
      id
      invoiceable
      billableMetric {
        id
      }
    }
    fixedCharge {
      id
      addOn {
        id
      }
    }
    addOn {
      id
    }
    presentationBreakdowns {
      presentationBy
      units
    }
  }
`

// Public surface of the `useViewFeeDetailsDrawer` hook. Consumers call
// `open(fee)` to display the drawer; `close()` is exposed so a caller can
// dismiss it programmatically (e.g. after a follow-up action).
export type UseViewFeeDetailsDrawerReturn = {
  open: (fee: FeeForViewFeeDetailsDrawerFragment) => void
  close: () => void
}

// Spec'd format is `MMMM D, YYYY - HH:mm:ss UTC` (e.g. May 11, 2026 - 14:32:05 UTC).
// The shared `intlFormatDateTime` helper returns the timezone as `UTC+0:00`, so
// we hand-roll the format with luxon here for an exact spec match.
const formatFeeDate = (iso: string | null | undefined): string => {
  if (iso === null || iso === undefined) return '-'
  return DateTime.fromISO(iso, { zone: 'utc' }).toFormat("LLLL d, yyyy - HH:mm:ss 'UTC'")
}

type ViewFeeDetailsHeaderProps = {
  fee: FeeForViewFeeDetailsDrawerFragment
}

const buildFeeTitle = (
  fee: FeeForViewFeeDetailsDrawerFragment,
  translate: ReturnType<typeof useInternationalization>['translate'],
): string => {
  // Only subscription fees should be titled by plan + interval. Charges,
  // fixed charges, add-ons, etc. share the same subscription association but
  // refer to a different concept (a billable metric, an add-on, …), so the
  // plan-based label is misleading there.
  if (fee.feeType === FeeTypesEnum.Subscription) {
    const planName = fee.subscription?.plan?.name
    const planInterval = fee.subscription?.plan?.interval

    if (
      planName !== null &&
      planName !== undefined &&
      planInterval !== null &&
      planInterval !== undefined
    ) {
      return translate('text_1778489273044dawd3fh19ga', { interval: planInterval, name: planName })
    }
  }

  return fee.invoiceDisplayName || fee.itemName
}

const ViewFeeDetailsHeader = ({ fee }: ViewFeeDetailsHeaderProps) => {
  const currency = fee.amountCurrency
  const { translate } = useInternationalization()
  const title = buildFeeTitle(fee, translate)

  return (
    <header
      data-test={VIEW_FEE_DETAILS_HEADER_TEST_ID}
      className="flex items-start justify-between gap-4"
    >
      <div className="flex flex-col gap-1">
        <Typography variant="headline" color="grey700">
          {title}
        </Typography>
        <Typography variant="caption" color="grey600">
          {fee.id}
        </Typography>
      </div>
      <Typography variant="headline" color="grey700">
        {intlFormatNumber(deserializeAmount(fee.amountCents, currency), {
          currencyDisplay: 'symbol',
          currency,
        })}
      </Typography>
    </header>
  )
}

type OverviewContentProps = {
  fee: FeeForViewFeeDetailsDrawerFragment
  showParentIdRow: boolean
}

const OverviewContent = ({ fee, showParentIdRow }: OverviewContentProps) => {
  const { translate } = useInternationalization()
  const currency = fee.amountCurrency

  const sourceItemId =
    fee.charge?.billableMetric?.id ??
    fee.fixedCharge?.addOn?.id ??
    fee.addOn?.id ??
    fee.subscription?.plan?.id ??
    '-'

  const formatCurrency = (value: string | number | null | undefined) =>
    intlFormatNumber(deserializeAmount(value ?? 0, currency), {
      currencyDisplay: 'symbol',
      currency,
    })

  return (
    <div className="flex flex-col gap-12">
      <section data-test={VIEW_FEE_DETAILS_OVERVIEW_TEST_ID} className="flex flex-col gap-4">
        <Typography variant="subhead1" color="grey700">
          {translate('text_1778485363573x86iip8zvol')}
        </Typography>
        <div className={tw(GRID)}>
          <DetailRow
            label={translate('text_1778485363573m3z3vhkli9m')}
            value={<TypographyWithCopy color="grey700">{fee.id}</TypographyWithCopy>}
          />
          {showParentIdRow && !!fee.trueUpParentFee?.id && (
            <DetailRow
              label={translate('text_1778485363573omt0phjqyjf')}
              value={
                <TypographyWithCopy color="grey700">{fee.trueUpParentFee.id}</TypographyWithCopy>
              }
            />
          )}
          <DetailRow
            label={translate('text_1778485363573g1bx23ms20d')}
            value={formatFeeDate(fee.properties?.fromDatetime)}
          />
          <DetailRow
            label={translate('text_1778485363573qufhnafv1s7')}
            value={formatFeeDate(fee.properties?.toDatetime)}
          />
          <DetailRow
            label={translate('text_1778490892190yz0uiowyheu')}
            value={translate(
              fee.payInAdvance ? 'text_17440181167432q7jzt9znuh' : 'text_1744018116743ntlygtcnq95',
            )}
          />
          <DetailRow
            label={translate('text_1778490892190exazejgkryd')}
            value={translate(
              !!fee?.charge?.invoiceable
                ? 'text_17440181167432q7jzt9znuh'
                : 'text_1744018116743ntlygtcnq95',
            )}
          />
          <DetailRow label={translate('text_1778485363573rg5koelt3xl')} value={String(fee.units)} />
          <DetailRow
            label={translate('text_1778485363573t3ualwsek49')}
            value={String(fee.eventsCount ?? 0)}
          />
          <DetailRow
            label={translate('text_17784853635736lythk93pix')}
            value={fee.amountCurrency}
          />
          <DetailRow
            label={translate('text_1778485363573ak0q09qqld2')}
            value={formatCurrency(fee.amountCents)}
          />
          <DetailRow
            label={translate('text_1778490892190t88x76715na')}
            value={String(fee.preciseAmountCents)}
          />
          <DetailRow
            label={translate('text_1778490892190ehl0skg0k5j')}
            value={formatCurrency(-fee.preciseCouponsAmountCents)}
          />
          <DetailRow
            label={translate('text_1778490892190l3jpvmw0buv')}
            value={formatCurrency(fee.subTotalExcludingTaxesAmountCents)}
          />
          <DetailRow
            label={translate('text_1778490892190oyfk8pf7p2f')}
            value={String(fee.subTotalExcludingTaxesPreciseAmountCents)}
          />
          <DetailRow
            label={translate('text_1778485363573vsznzlvuo73')}
            value={`${fee.taxesRate ?? 0}%`}
          />
          <DetailRow
            label={translate('text_1778485363573qqb7v9a7lqc')}
            value={formatCurrency(fee.taxesAmountCents)}
          />
          <DetailRow
            label={translate('text_1778490892190k2ufb6mtgsv')}
            value={String(fee.taxesPreciseAmountCents)}
          />
          <DetailRow
            label={translate('text_1778490892190wmqatogkxyd')}
            value={formatCurrency(fee.totalAmountCents)}
          />
          <DetailRow
            label={translate('text_1778490892190r05w5pkp0cq')}
            value={String(fee.preciseTotalAmountCents)}
          />
        </div>
      </section>

      <section data-test={VIEW_FEE_DETAILS_SOURCE_ITEM_TEST_ID} className="flex flex-col gap-4">
        <Typography variant="subhead1" color="grey700">
          {translate('text_1778485363573o8h8xpr4qyj')}
        </Typography>
        <div className={tw(GRID)}>
          <DetailRow label={translate('text_1778485363574w7zyl8tilba')} value={fee.feeType} />
          <DetailRow
            label={translate('text_1778485363574dygtpz792rx')}
            value={<TypographyWithCopy color="grey700">{fee.itemCode}</TypographyWithCopy>}
          />
          <DetailRow label={translate('text_177848536357404anic3s604')} value={fee.itemName} />
          {!!fee.invoiceDisplayName && (
            <DetailRow
              label={translate('text_1778485363574e70wgua8cxw')}
              value={fee.invoiceDisplayName}
            />
          )}
          <DetailRow label={translate('text_1778485363574gqoz4lwxrb6')} value={fee.itemType} />
          {sourceItemId !== '-' && (
            <DetailRow
              label={translate('text_17784853635746778oyfl0yh')}
              value={<TypographyWithCopy color="grey700">{sourceItemId}</TypographyWithCopy>}
            />
          )}
        </div>
      </section>
    </div>
  )
}

type PresentationGroupKeyTableProps = {
  fee: FeeForViewFeeDetailsDrawerFragment
}

const PresentationGroupKeyTable = ({ fee }: PresentationGroupKeyTableProps) => {
  const { translate } = useInternationalization()
  const breakdowns = fee.presentationBreakdowns

  if (!breakdowns?.length) {
    return null
  }

  const isMeaningful = (value: unknown): boolean =>
    value !== null && value !== undefined && String(value).length > 0

  const firstPresentationBy = breakdowns.find((b) => !!b.presentationBy)?.presentationBy as
    Record<string, unknown> | undefined

  if (!firstPresentationBy) {
    return null
  }

  const columnKeys = Object.keys(firstPresentationBy)

  const header =
    `${translate('text_1778496527600jgpur5fmwi5')} ${columnKeys[0]}` +
    (columnKeys[1] ? ` ${translate('text_1778496527600i320tl9y47e')} ${columnKeys[1]}` : '')

  // The design-system Table requires each row to have a string `id`. Breakdowns
  // from the API don't have one — synthesise a stable index-based id. Drop
  // breakdowns whose `presentationBy` has no meaningful values so the user
  // never sees a row of empty chips.
  type Row = {
    id: string
    presentationBy: Record<string, unknown>
    units: string
  }
  const rows: Row[] = breakdowns
    .map((b, i) => ({
      id: `breakdown-${i}`,
      presentationBy: (b.presentationBy ?? {}) as Record<string, unknown>,
      units: b.units,
    }))
    .filter((r) => Object.values(r.presentationBy).some(isMeaningful))

  if (rows.length === 0) {
    return null
  }

  return (
    <div className="flex flex-col gap-4">
      <Typography variant="subhead1" color="grey700">
        {translate('text_1778496527600awcxxc1uust')}
      </Typography>

      <Table
        name={VIEW_FEE_DETAILS_PGK_TABLE_TEST_ID}
        data={rows}
        containerSize={0}
        rowSize={72}
        columns={[
          {
            key: 'id',
            maxSpace: true,
            title: (
              <Typography variant="captionHl" color="grey600">
                {header}
              </Typography>
            ),
            content: ({ presentationBy }) => (
              <div className="flex gap-1">
                {columnKeys
                  .filter((key) => isMeaningful(presentationBy?.[key]))
                  .map((key) => (
                    <Chip key={key} label={String(presentationBy?.[key])} />
                  ))}
              </div>
            ),
          },
          {
            key: 'units',
            textAlign: 'right',
            title: (
              <Typography className="pr-1" variant="captionHl" color="grey600">
                {translate('text_1778485363573rg5koelt3xl')}
              </Typography>
            ),
            content: ({ units }) => (
              <Typography className="pr-1" variant="body" color="grey700">
                {units}
              </Typography>
            ),
          },
        ]}
      />
    </div>
  )
}

const ViewFeeDetailsBody = ({ fee }: { fee: FeeForViewFeeDetailsDrawerFragment }) => {
  const { translate } = useInternationalization()
  const [tabIndex, setTabIndex] = useState(0)
  const hasBreakdowns = (fee.presentationBreakdowns?.length ?? 0) > 0

  return (
    <MemoryRouter>
      <div data-test={VIEW_FEE_DETAILS_DRAWER_TEST_ID}>
        <CenteredPage.SectionWrapper>
          <div>
            <ViewFeeDetailsHeader fee={fee} />

            {hasBreakdowns && (
              <NavigationTab
                managedBy={TabManagedBy.INDEX}
                currentTab={tabIndex}
                onChange={(index) => setTabIndex(index)}
                className="mb-12 mt-4"
                tabs={[
                  {
                    title: translate('text_17784853635748xbwslxipeo'),
                    component: <OverviewContent fee={fee} showParentIdRow={true} />,
                  },
                  {
                    title: translate('text_1778487825608a08eizdrt7y'),
                    component: <PresentationGroupKeyTable fee={fee} />,
                  },
                ]}
              />
            )}
          </div>

          {!hasBreakdowns && <OverviewContent fee={fee} showParentIdRow={false} />}
        </CenteredPage.SectionWrapper>
      </div>
    </MemoryRouter>
  )
}

// Implementation note — the drawer registration MUST live on a component that
// outlives any popper / menu / row that opens it. If we instead called
// `useDrawer()` directly inside `ViewFeeDetailsButton`, the popper that hosts
// the menu unmounts as soon as `closePopper()` runs after a click, which fires
// the hook's `useEffect` cleanup and unregisters the NiceModal entry before
// NiceModal can finish showing it — producing the "no modal found for id :rm:"
// error reported by QA. A provider hoisted to a stable parent (page / layout)
// keeps a single registration alive across all click sites.

const ViewFeeDetailsDrawerContext = createContext<UseViewFeeDetailsDrawerReturn | null>(null)

export const ViewFeeDetailsDrawerProvider = ({ children }: { children: ReactNode }) => {
  const { translate } = useInternationalization()
  const viewFeeDetailsDrawer = useDrawer()

  const open = useCallback(
    (fee: FeeForViewFeeDetailsDrawerFragment) => {
      viewFeeDetailsDrawer.open({
        title: translate('text_1778496527600pn3sn6m4ni0'),
        children: <ViewFeeDetailsBody key={fee.id} fee={fee} />,
        actions: (
          <div className="flex items-center justify-end gap-3">
            <Button onClick={() => viewFeeDetailsDrawer.close()}>
              {translate('text_62f50d26c989ab03196884ae')}
            </Button>
          </div>
        ),
      })
    },
    [translate, viewFeeDetailsDrawer],
  )

  const value = useMemo(
    () => ({ open, close: viewFeeDetailsDrawer.close }),
    [open, viewFeeDetailsDrawer.close],
  )

  return (
    <ViewFeeDetailsDrawerContext.Provider value={value}>
      {children}
    </ViewFeeDetailsDrawerContext.Provider>
  )
}

const NOOP_VIEW_FEE_DETAILS_DRAWER: UseViewFeeDetailsDrawerReturn = {
  open: () => undefined,
  close: () => undefined,
}

/**
 * Hook to open the read-only fee-details drawer.
 *
 * Usage:
 * ```tsx
 * const viewFeeDetails = useViewFeeDetailsDrawer()
 * <button onClick={() => viewFeeDetails.open(fee)}>View fee details</button>
 * ```
 *
 * Best paired with `<ViewFeeDetailsDrawerProvider>` at a stable parent so the
 * NiceModal registration survives popper/menu lifecycles. When no provider is
 * present (e.g. the regenerate flow where row clicks shouldn't open the
 * drawer) the hook returns a no-op so consumers don't need to gate.
 */
export const useViewFeeDetailsDrawer = (): UseViewFeeDetailsDrawerReturn => {
  return useContext(ViewFeeDetailsDrawerContext) ?? NOOP_VIEW_FEE_DETAILS_DRAWER
}
