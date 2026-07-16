import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const FeatureEntitlementSection = () => {
  const { translate } = useInternationalization()

  return (
    <div className="flex flex-col items-start gap-4">
      <div className="flex flex-col gap-1">
        <Typography variant="bodyHl" color="grey700">
          {translate('text_63e26d8308d03687188221a6')}
        </Typography>

        <Typography
          variant="caption"
          color="grey600"
          html={translate('text_17697190237699e4t0knd8hj')}
        />
      </div>
    </div>
  )
}
