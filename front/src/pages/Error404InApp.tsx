import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { HOME_ROUTE, useNavigate } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'

/**
 * In-app 404 variant — rendered inside SideNavLayout when a user hits
 * an invalid sub-route under a valid org slug (e.g. `/acme/non-existing`).
 */
const Error404InApp = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()

  return (
    <div className="flex flex-1">
      <GenericPlaceholder
        image={<ErrorImage width="136" height="104" />}
        title={translate('text_62bac37900192b773560e82d')}
        subtitle={translate('text_1776863953533imjygk4dami')}
        buttonTitle={translate('text_1776444526636tm9yry92nyh')}
        buttonAction={() => navigate(HOME_ROUTE, { replace: true })}
      />
    </div>
  )
}

export default Error404InApp
