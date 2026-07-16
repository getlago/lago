import PremiumFeature from '~/components/premium/PremiumFeature'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const PROGRESSIVE_BILLING_PREMIUM_GATE_TEST_ID = 'progressive-billing-premium-gate'

export const ProgressiveBillingPremiumGate = () => {
  const { translate } = useInternationalization()

  return (
    <PremiumFeature
      data-test={PROGRESSIVE_BILLING_PREMIUM_GATE_TEST_ID}
      title={translate('text_1724345142892pcnx5m2k3r2')}
      description={translate('text_1724345142892ljzi79afhmc')}
      feature={translate('text_1724179887722baucvj7bvc1')}
    />
  )
}
