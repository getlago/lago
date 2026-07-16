import { Icon } from 'lago-design-system'

import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'

type SectionErrorProps = {
  refresh?: () => void
  customTitle?: string
  customDescription?: string
  hideDescription?: boolean
}

const SectionError = ({
  customTitle,
  customDescription,
  hideDescription,
  refresh,
}: SectionErrorProps) => {
  const { translate } = useCustomerPortalTranslate()

  return (
    <div className="flex flex-col items-start gap-5">
      <div className="rounded-xl bg-grey-100 p-5">
        <Icon name="warning-unfilled" size="large" />
      </div>

      <div>
        <Typography variant="subhead1" color="grey700" className="mb-3">
          {customTitle || translate('text_1728385052917x4pkr4t3x3b')}
        </Typography>

        {!hideDescription && (
          <Typography variant="subhead2" color="grey600">
            {customDescription || translate('text_1728385052918teqr4dhxxi6')}
          </Typography>
        )}
      </div>

      {refresh && <Button onClick={refresh}>{translate('text_1728385052918zkczgwzq967')}</Button>}
    </div>
  )
}

export default SectionError
