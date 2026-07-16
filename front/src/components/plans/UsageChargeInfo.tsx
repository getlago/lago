import { useState } from 'react'

import { ConditionalWrapper } from '~/components/ConditionalWrapper'
import { Accordion } from '~/components/designSystem/Accordion'
import { Typography } from '~/components/designSystem/Typography'
import { VirtualFilterList } from '~/components/designSystem/VirtualList/VirtualFilterList'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { PlanDetailsChargeWrapperSwitch } from '~/components/plans/details/PlanDetailsChargeWrapperSwitch'
import PlanDetailsPresentationGroupKeys from '~/components/plans/details/PlanDetailsPresentationGroupKeys'
import { isPlanIntervalAnnual, mapChargeIntervalCopy } from '~/components/plans/utils'
import { chargeModelLookupTranslation } from '~/core/constants/form'
import { composeChargeFilterDisplayName } from '~/core/formats/formatInvoiceItemsMap'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  ChargeFilter,
  ChargeModelEnum,
  CurrencyEnum,
  Maybe,
  PlanInterval,
  Properties,
  RegroupPaidFeesEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type Tax = { id: string; name: string; rate: number; code?: string }

export type UsageChargeInfoCharge = {
  __typename?: 'Charge'
  id: string
  chargeModel: ChargeModelEnum
  invoiceDisplayName?: string | null
  invoiceable?: boolean | null
  payInAdvance?: boolean | null
  prorated?: boolean | null
  minAmountCents?: string | number | null
  regroupPaidFees?: RegroupPaidFeesEnum | null
  properties?: Maybe<Properties>
  filters?: ReadonlyArray<ChargeFilter> | null
  appliedPricingUnit?: Maybe<{
    conversionRate: number
    pricingUnit: { name: string; shortName?: string }
  }>
  taxes?: ReadonlyArray<Tax> | null
  billableMetric: {
    id: string
    name: string
    code?: string
    recurring?: boolean | null
    filters?: ReadonlyArray<{ id?: string; key: string; values: string[] }> | null
  }
}

export type UsageChargeInfoProps = {
  charge: UsageChargeInfoCharge
  currency: CurrencyEnum
  planInterval?: PlanInterval | null
  billChargesMonthly?: boolean | null
  planTaxes?: ReadonlyArray<Tax> | null
}

export const UsageChargeInfo = ({
  charge,
  currency,
  planInterval,
  billChargesMonthly,
  planTaxes,
}: UsageChargeInfoProps) => {
  const { translate } = useInternationalization()
  const isAnnual = isPlanIntervalAnnual(planInterval ?? undefined)

  // Filter index is safe as a key here because this is a read-only details view where filters
  // are never reordered or spliced; a mutable context would need a stable id instead.
  const [openFilterIndexes, setOpenFilterIndexes] = useState<Set<number>>(() => new Set())

  const toggleFilterOpen = (index: number, open: boolean) =>
    setOpenFilterIndexes((current) => {
      const next = new Set(current)

      if (open) next.add(index)
      else next.delete(index)

      return next
    })
  const chargeTaxes = charge.taxes?.length ? charge.taxes : null
  const fallbackTaxes = planTaxes?.length ? planTaxes : null
  const taxesApplied = chargeTaxes ?? fallbackTaxes
  const hasFilters = !!charge.billableMetric?.filters?.length

  const invoicingStrategy = (() => {
    if (!charge.payInAdvance) return translate('text_66968fba80f8f89a8aefdec0')
    if (charge.invoiceable) return translate('text_66968fba80f8f89a8aefdebf')
    if (charge.regroupPaidFees === RegroupPaidFeesEnum.Invoice)
      return translate('text_66968fba80f8f89a8aefdec0')
    return translate('text_6682c52081acea9052074686')
  })()

  const invoicingRow = charge.billableMetric?.recurring
    ? {
        label: translate('text_646e2d0cc536351b62ba6f16'),
        value: charge.invoiceable
          ? translate('text_65251f46339c650084ce0d57')
          : translate('text_65251f4cd55aeb004e5aa5ef'),
      }
    : {
        label: translate('text_6682c52081acea90520744ca'),
        value: invoicingStrategy,
      }

  return (
    <section className="flex flex-col gap-4">
      {!!charge.appliedPricingUnit && (
        <div className="p-4 shadow-b">
          <DetailsPage.InfoGrid
            grid={[
              {
                label: translate('text_17502505476284yyq70yy6mx'),
                value: charge.appliedPricingUnit.pricingUnit.name,
              },
              {
                label: translate('text_1750411499858su5b7bbp5t9'),
                value: translate('text_1750424999815sw5whlu1xj0', {
                  shortName: charge.appliedPricingUnit.pricingUnit?.shortName,
                  conversionRateAmount: intlFormatNumber(
                    charge.appliedPricingUnit?.conversionRate,
                    { maximumFractionDigits: 15, currency },
                  ),
                }),
              },
            ]}
          />
        </div>
      )}

      <div className="px-4 pt-4">
        <DetailsPage.InfoGrid
          grid={[
            {
              label: translate('text_65201b8216455901fe273dd5'),
              value: translate(chargeModelLookupTranslation[charge.chargeModel]),
            },
            {
              label: translate('text_65201b8216455901fe273dc1'),
              value: translate(
                mapChargeIntervalCopy(
                  (planInterval as PlanInterval) ?? PlanInterval.Monthly,
                  (isAnnual && !!billChargesMonthly) || false,
                ),
              ),
            },
          ]}
        />
      </div>

      <section className="flex flex-col gap-4 px-4 pb-4 shadow-b">
        {hasFilters && (
          <PlanDetailsPresentationGroupKeys
            presentationGroupKeys={charge.properties?.presentationGroupKeys}
          />
        )}

        <ConditionalWrapper
          condition={hasFilters}
          invalidWrapper={(children) => <div>{children}</div>}
          validWrapper={(children) => (
            <Accordion
              summary={
                <Typography variant="bodyHl" color="grey700">
                  {translate('text_64e620bca31226337ffc62ad')}
                </Typography>
              }
            >
              {children}
            </Accordion>
          )}
        >
          <PlanDetailsChargeWrapperSwitch
            currency={currency}
            chargeModel={charge.chargeModel}
            values={charge.properties}
            chargeAppliedPricingUnit={charge.appliedPricingUnit}
            showPresentationGroupKeys={!hasFilters}
          />
        </ConditionalWrapper>

        {!!charge.filters?.length && (
          <VirtualFilterList
            className="flex flex-col gap-4"
            gap={16}
            items={charge.filters}
            estimateItemHeight={72}
            getItemKey={(_filter, index) => `usage-charge-info-${charge.id}-filter-${index}`}
            renderItem={(filter, i) => {
              const fallbackName = composeChargeFilterDisplayName({
                ...filter,
                values: filter.values as Record<string, string[]>,
              })

              return (
                <Accordion
                  isOpen={openFilterIndexes.has(i)}
                  onToggle={(open) => toggleFilterOpen(i, open)}
                  summary={
                    <Typography noWrap variant="bodyHl" color="grey700">
                      {filter.invoiceDisplayName || fallbackName}
                    </Typography>
                  }
                >
                  <PlanDetailsChargeWrapperSwitch
                    currency={currency}
                    chargeModel={charge.chargeModel}
                    values={filter.properties}
                    chargeAppliedPricingUnit={charge.appliedPricingUnit}
                  />
                </Accordion>
              )
            }}
          />
        )}
      </section>

      <div className="px-4 pb-4">
        <DetailsPage.InfoGrid
          grid={[
            {
              label: translate('text_65201b8216455901fe273dd9'),
              value: charge.payInAdvance
                ? translate('text_646e2d0cc536351b62ba6faa')
                : translate('text_646e2d0cc536351b62ba6f8c'),
            },
            {
              label: translate('text_65201b8216455901fe273ddb'),
              value: intlFormatNumber(deserializeAmount(charge.minAmountCents ?? 0, currency), {
                currencyDisplay: 'symbol',
                currency,
                pricingUnitShortName: charge.appliedPricingUnit?.pricingUnit?.shortName,
                maximumFractionDigits: 15,
              }),
            },
            {
              label: translate('text_65201b8216455901fe273df0'),
              value: charge.prorated
                ? translate('text_65251f46339c650084ce0d57')
                : translate('text_65251f4cd55aeb004e5aa5ef'),
            },
            invoicingRow,
            {
              label: translate('text_645bb193927b375079d28a8f'),
              value: taxesApplied
                ? taxesApplied.map((tax) => (
                    <div key={`usage-charge-${charge.id}-tax-${tax.id}`}>
                      {tax.name} (
                      {intlFormatNumber(Number(tax.rate) / 100 || 0, { style: 'percent' })})
                    </div>
                  ))
                : '-',
            },
          ]}
        />
      </div>
    </section>
  )
}
