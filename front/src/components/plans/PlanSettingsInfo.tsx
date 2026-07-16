import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { PlanInterval } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type PlanSettingsInfoProps = {
  plan: {
    name?: string | null
    code?: string | null
    description?: string | null
    interval?: PlanInterval | null
    amountCurrency?: string | null
    taxes?: ReadonlyArray<{ id: string; name: string; rate: number }> | null
  }
}

export const PlanSettingsInfo = ({ plan }: PlanSettingsInfoProps) => {
  const { translate } = useInternationalization()

  return (
    <div className="flex flex-col gap-4">
      <DetailsPage.InfoGrid
        grid={[
          {
            label: translate('text_62442e40cea25600b0b6d852'),
            value: plan.name ?? undefined,
          },
          {
            label: translate('text_642d5eb2783a2ad10d670320'),
            value: plan.code ? (
              <TypographyWithCopy variant="body" color="grey700">
                {plan.code}
              </TypographyWithCopy>
            ) : undefined,
          },
          {
            label: translate('text_65201b8216455901fe273dc1'),
            value: plan.interval ? translate(getIntervalTranslationKey[plan.interval]) : undefined,
          },
          {
            label: translate('text_632b4acf0c41206cbcb8c324'),
            value: plan.amountCurrency ?? undefined,
          },
        ]}
      />

      {!!plan.description && (
        <DetailsPage.InfoGridItem
          label={translate('text_6388b923e514213fed58331c')}
          value={plan.description}
        />
      )}

      {!!plan.taxes?.length && (
        <DetailsPage.InfoGridItem
          label={translate('text_645bb193927b375079d28a8f')}
          value={plan.taxes.map((tax) => (
            <div key={`plan-settings-tax-${tax.id}`}>
              {tax.name} ({intlFormatNumber(Number(tax.rate) / 100 || 0, { style: 'percent' })})
            </div>
          ))}
        />
      )}
    </div>
  )
}
