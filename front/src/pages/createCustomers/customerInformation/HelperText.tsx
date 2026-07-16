import { generatePath } from 'react-router-dom'

import { Typography } from '~/components/designSystem/Typography'
import { BILLING_ENTITY_GENERAL_ROUTE } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

type HelperTextProps = {
  billingEntityCode: string
}

const HelperText = ({ billingEntityCode }: HelperTextProps) => {
  const { translate } = useInternationalization()
  const { timezoneConfig } = useOrganizationInfos()

  return (
    <Typography
      variant="caption"
      html={translate('text_6390a4ffef9227ba45daca94', {
        timezone: translate('text_638f743fa9a2a9545ee6409a', {
          zone: timezoneConfig.name,
          offset: timezoneConfig.offset,
        }),
        link: generatePath(BILLING_ENTITY_GENERAL_ROUTE, {
          billingEntityCode: billingEntityCode,
        }),
      })}
    />
  )
}

export default HelperText
