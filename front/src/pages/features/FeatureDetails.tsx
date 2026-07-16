import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { useDeleteFeatureDialog } from '~/components/features/DeleteFeatureDialog'
import { FeatureDetailsActivityLogs } from '~/components/features/FeatureDetailsActivityLogs'
import { FeatureDetailsOverview } from '~/components/features/FeatureDetailsOverview'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { FeatureDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  FEATURE_DETAILS_ROUTE,
  FEATURES_ROUTE,
  UPDATE_FEATURE_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  FeatureForDeleteFeatureDialogFragmentDoc,
  LagoApiError,
  useGetFeatureForDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query getFeatureForDetails($feature: ID!) {
    feature(id: $feature) {
      id
      name
      code
      ...FeatureForDeleteFeatureDialog
    }
  }

  ${FeatureForDeleteFeatureDialogFragmentDoc}
`

const FeatureDetails = () => {
  const navigate = useNavigate()
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const { featureId } = useParams()

  const { openDeleteFeatureDialog } = useDeleteFeatureDialog()

  const {
    data: featureResult,
    loading: isFeatureLoading,
    error: featureError,
  } = useGetFeatureForDetailsQuery({
    variables: {
      feature: featureId as string,
    },
    skip: !featureId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  useNotFoundRedirect({
    error: featureError,
    loading: isFeatureLoading,
    redirectTo: FEATURES_ROUTE,
    translateKey: 'text_1777995443788m0uv1vvtz7j',
  })

  const feature = featureResult?.feature

  const actions: MainHeaderAction[] = feature
    ? [
        {
          type: 'dropdown',
          label: translate('text_626162c62f790600f850b6fe'),
          dataTest: 'feature-details-actions',
          items: [
            {
              label: translate('text_1756217474408noiuzsd087w'),
              dataTest: 'feature-details-edit',
              hidden: !hasPermissions(['featuresUpdate']),
              onClick: (closePopper) => {
                navigate(generatePath(UPDATE_FEATURE_ROUTE, { featureId: feature.id }))
                closePopper()
              },
            },
            {
              label: translate('text_1752693359315sd2ms0qxvi3'),
              hidden: !hasPermissions(['featuresDelete']),
              onClick: (closePopper) => {
                openDeleteFeatureDialog({
                  feature,
                  callback: () => {
                    navigate(FEATURES_ROUTE)
                  },
                })
                closePopper()
              },
            },
          ],
        },
      ]
    : []

  const activeTabContent = useMainHeaderTabContent()

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[{ label: translate('text_1752692673070k7z0mmf0494'), path: FEATURES_ROUTE }]}
        entity={{
          viewName: feature?.name || '-',
          viewNameLoading: isFeatureLoading,
          metadata: feature?.code || '',
          metadataLoading: isFeatureLoading,
        }}
        actions={{ items: actions, loading: isFeatureLoading }}
        tabs={[
          {
            title: translate('text_628cf761cbe6820138b8f2e4'),
            link: generatePath(FEATURE_DETAILS_ROUTE, {
              featureId: featureId as string,
              tab: FeatureDetailsTabsOptionsEnum.overview,
            }),
            content: (
              <DetailsPage.Container>
                <FeatureDetailsOverview />
              </DetailsPage.Container>
            ),
          },
          {
            title: translate('text_1747314141347qq6rasuxisl'),
            link: generatePath(FEATURE_DETAILS_ROUTE, {
              featureId: featureId as string,
              tab: FeatureDetailsTabsOptionsEnum.activityLogs,
            }),
            content: <FeatureDetailsActivityLogs featureId={featureId as string} />,
            hidden: !isPremium || !hasPermissions(['auditLogsView']),
          },
        ]}
      />

      <>{activeTabContent}</>
    </>
  )
}

export default FeatureDetails
