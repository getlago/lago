import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type SubscriptionFeeInfoPlan = {
  amountCents?: string | number | null
  amountCurrency?: CurrencyEnum | null
  payInAdvance?: boolean | null
  trialPeriod?: number | null
  taxes?: Array<{ id: string; name?: string | null; rate?: number | null }> | null
}

type SubscriptionFeeInfoProps = {
  plan: SubscriptionFeeInfoPlan
}

export const SubscriptionFeeInfo = ({ plan }: SubscriptionFeeInfoProps) => {
  const { translate } = useInternationalization()
  const currency = plan.amountCurrency ?? CurrencyEnum.Usd

  return (
    <div className="flex flex-col gap-6">
      <DetailsPage.TableDisplay
        name="subscription-fee"
        header={[translate('text_624453d52e945301380e49b6')]}
        body={[
          [
            intlFormatNumber(deserializeAmount(plan.amountCents || 0, currency), {
              currency,
            }),
          ],
        ]}
      />
      <DetailsPage.InfoGrid
        grid={[
          {
            label: translate('text_65201b8216455901fe273dd9'),
            value: plan.payInAdvance
              ? translate('text_646e2d0cc536351b62ba6faa')
              : translate('text_646e2d0cc536351b62ba6f8c'),
          },
          {
            label: translate('text_65201b8216455901fe273dcd'),
            value: plan.trialPeriod || '-',
          },
          {
            label: translate('text_645bb193927b375079d28a8f'),
            value: !!plan.taxes?.length
              ? plan.taxes.map((tax, i) => (
                  <div key={`subscription-fee-tax-${tax.id ?? i}`}>
                    <Typography variant="body" color="grey700">
                      {tax.name} (
                      {intlFormatNumber(Number(tax.rate) / 100 || 0, { style: 'percent' })})
                    </Typography>
                  </div>
                ))
              : '-',
          },
        ]}
      />
    </div>
  )
}
