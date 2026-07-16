import { Icon, tw } from 'lago-design-system'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type PremiumFeatureProps = {
  title: string
  description: string
  feature: string
  className?: string
  buttonClassName?: string
  'data-test'?: string
}

const PremiumFeature = ({
  title,
  description,
  feature,
  className,
  buttonClassName,
  'data-test': dataTest,
}: PremiumFeatureProps) => {
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()

  return (
    <div
      className={tw(
        'flex w-full flex-row items-center justify-between gap-2 rounded-xl bg-grey-100 px-6 py-4',
        className,
      )}
      data-test={dataTest}
    >
      <div className="flex flex-col">
        <div className="flex flex-row items-center gap-2">
          <Typography variant="bodyHl" color="grey700">
            {title}
          </Typography>

          <Icon name="sparkles" />
        </div>

        <Typography variant="caption" color="grey600">
          {description}
        </Typography>
      </div>

      <Button
        className={buttonClassName}
        endIcon="sparkles"
        variant="tertiary"
        onClick={() =>
          premiumWarningDialog.open({
            title,
            description,
            mailtoSubject: translate('text_1759493418045b173t4qhktb', {
              feature,
            }),
            mailtoBody: translate('text_1759493745332hiuejhksn15', {
              feature,
            }),
          })
        }
      >
        {translate('text_65ae73ebe3a66bec2b91d72d')}
      </Button>
    </div>
  )
}

export default PremiumFeature
