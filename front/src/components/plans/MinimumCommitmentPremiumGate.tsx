import PremiumFeature from '~/components/premium/PremiumFeature'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const MINIMUM_COMMITMENT_PREMIUM_GATE_TEST_ID = 'minimum-commitment-premium-gate'

export const MinimumCommitmentPremiumGate = () => {
  const { translate } = useInternationalization()

  return (
    <PremiumFeature
      data-test={MINIMUM_COMMITMENT_PREMIUM_GATE_TEST_ID}
      title={translate('text_17700400130439xuo82ha60n')}
      description={translate('text_1770040013043awgs0eemonf')}
      feature={translate('text_65d601bffb11e0f9d1d9f569')}
    />
  )
}
