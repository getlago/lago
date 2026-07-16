import { Spinner } from '~/components/designSystem/Spinner'
import { envGlobalVar } from '~/core/apolloClient'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import NewAnalytics from '~/pages/analytics/NewAnalytics'
import Dashboards from '~/pages/dashboards/Dashboards'
import OldAnalytics from '~/pages/OldAnalytics'

const { lagoSupersetUrl } = envGlobalVar()

const Analytics = () => {
  const {
    hasOrganizationPremiumAddon,
    loading: organizationDataLoading,
    organization,
  } = useOrganizationInfos()

  const hasAccessToAnalyticsDashboardsFeature = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.AnalyticsDashboards,
  )

  if (organizationDataLoading || !organization?.id) {
    return <Spinner />
  }

  if (hasAccessToAnalyticsDashboardsFeature) {
    if (lagoSupersetUrl) {
      return <Dashboards />
    }

    return <NewAnalytics />
  }

  return <OldAnalytics />
}

export default Analytics
