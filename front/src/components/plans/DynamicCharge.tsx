import { Alert } from '~/components/designSystem/Alert'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const DynamicCharge = () => {
  const { translate } = useInternationalization()

  return <Alert type="info">{translate('text_17277706303454rxgscdqklx')}</Alert>
}

DynamicCharge.displayName = 'DynamicCharge'
