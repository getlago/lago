import { DetailsPage } from '~/components/layouts/DetailsPage'
import { PlanDetailsChargeWrapperSwitch } from '~/components/plans/details/PlanDetailsChargeWrapperSwitch'
import { isPlanIntervalAnnual, mapChargeIntervalCopy } from '~/components/plans/utils'
import { chargeModelLookupTranslation } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  FixedChargeProperties,
  Maybe,
  PlanInterval,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type Tax = { id: string; name: string; rate: number }

type FixedChargeInfoCharge = {
  id: string
  invoiceDisplayName?: string | null
  chargeModel: FixedChargeChargeModelEnum
  units?: string | number | null
  payInAdvance?: boolean | null
  prorated?: boolean | null
  properties?: Maybe<FixedChargeProperties>
  addOn: { id: string; name: string; code: string }
  taxes?: ReadonlyArray<Tax> | null
}

export type FixedChargeInfoProps = {
  fixedCharge: FixedChargeInfoCharge
  currency: CurrencyEnum
  planInterval?: PlanInterval | null
  billFixedChargesMonthly?: boolean | null
  planTaxes?: ReadonlyArray<Tax> | null
}

export const FixedChargeInfo = ({
  fixedCharge,
  currency,
  planInterval,
  billFixedChargesMonthly,
  planTaxes,
}: FixedChargeInfoProps) => {
  const { translate } = useInternationalization()
  const isAnnual = isPlanIntervalAnnual(planInterval ?? undefined)

  const fixedTaxes = fixedCharge.taxes?.length ? fixedCharge.taxes : null
  const fallbackTaxes = planTaxes?.length ? planTaxes : null
  const taxesApplied = fixedTaxes ?? fallbackTaxes

  return (
    <section className="flex flex-col gap-4">
      <div className="px-4 pt-4">
        <DetailsPage.InfoGrid
          grid={[
            {
              label: translate('text_65201b8216455901fe273dd5'),
              value: translate(chargeModelLookupTranslation[fixedCharge.chargeModel]),
            },
            {
              label: translate('text_65201b8216455901fe273dc1'),
              value: translate(
                mapChargeIntervalCopy(
                  (planInterval as PlanInterval) ?? PlanInterval.Monthly,
                  (isAnnual && !!billFixedChargesMonthly) || false,
                ),
              ),
            },
            {
              label: translate('text_65771fa3f4ab9a00720726ce'),
              value: fixedCharge.units,
            },
          ]}
        />
      </div>
      <section className="flex flex-col gap-4 px-4 pb-4 shadow-b">
        <PlanDetailsChargeWrapperSwitch
          currency={currency}
          chargeModel={fixedCharge.chargeModel}
          values={fixedCharge.properties}
        />
      </section>
      <div className="px-4 pb-4">
        <DetailsPage.InfoGrid
          grid={[
            {
              label: translate('text_65201b8216455901fe273dd9'),
              value: fixedCharge.payInAdvance
                ? translate('text_646e2d0cc536351b62ba6faa')
                : translate('text_646e2d0cc536351b62ba6f8c'),
            },
            {
              label: translate('text_65201b8216455901fe273df0'),
              value: fixedCharge.prorated
                ? translate('text_65251f46339c650084ce0d57')
                : translate('text_65251f4cd55aeb004e5aa5ef'),
            },
            {
              label: translate('text_645bb193927b375079d28a8f'),
              value: taxesApplied
                ? taxesApplied.map((tax) => (
                    <div key={`fixed-charge-${fixedCharge.id}-tax-${tax.id}`}>
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
