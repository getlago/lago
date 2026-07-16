import { gql } from '@apollo/client'
import { Icon, tw } from 'lago-design-system'
import { useMemo } from 'react'
import { generatePath } from 'react-router-dom'

import { Avatar } from '~/components/designSystem/Avatar'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { ActionItem } from '~/components/designSystem/Table/types'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { useDeleteFeatureDialog } from '~/components/features/DeleteFeatureDialog'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SearchInput } from '~/components/SearchInput'
import { FeatureDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { useNavigate } from '~/core/router'
import {
  CREATE_FEATURE_ROUTE,
  FEATURE_DETAILS_ROUTE,
  UPDATE_FEATURE_ROUTE,
} from '~/core/router/ObjectsRoutes'
import { DateFormat, intlFormatDateTime } from '~/core/timezone'
import { useGetFeaturesListLazyQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  fragment FeatureForFeaturesList on FeatureObject {
    id
    name
    code
    createdAt
    subscriptionsCount
  }

  query getFeaturesList($limit: Int, $page: Int, $searchTerm: String) {
    features(limit: $limit, page: $page, searchTerm: $searchTerm) {
      collection {
        ...FeatureForFeaturesList
      }
      metadata {
        currentPage
        totalPages
        totalCount
      }
    }
  }
`

const FeaturesList = () => {
  const navigate = useNavigate()
  const { openDeleteFeatureDialog } = useDeleteFeatureDialog()
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()

  const [
    getFeatures,
    {
      data: featuresData,
      error: featuresError,
      loading: featuresLoading,
      variables: featuresVariables,
      fetchMore: fetchMoreFeatures,
    },
  ] = useGetFeaturesListLazyQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      limit: 20,
    },
  })

  const features = featuresData?.features.collection
  const { debouncedSearch, isLoading } = useDebouncedSearch(getFeatures, featuresLoading)

  const canUpdateFeatures = hasPermissions(['featuresUpdate'])
  const canDeleteFeatures = hasPermissions(['featuresDelete'])

  const tablePlaceholder = useMemo(
    () => ({
      errorState: !!featuresVariables?.searchTerm
        ? {
            title: translate('text_623b53fea66c76017eaebb6e'),
            subtitle: translate('text_63bab307a61c62af497e0599'),
          }
        : {
            title: translate('text_63ac86d797f728a87b2f9fea'),
            subtitle: translate('text_63ac86d797f728a87b2f9ff2'),
            buttonTitle: translate('text_63ac86d797f728a87b2f9ffa'),
            buttonAction: () => location.reload(),
            buttonVariant: 'primary' as const,
          },
      emptyState: !!featuresVariables?.searchTerm
        ? {
            title: translate('text_1751969008731sd4e2mssx90'),
            subtitle: translate('text_66ab48ea4ed9cd01084c60be'),
          }
        : {
            title: translate('text_1752692673070vvbkvtj8pbx'),
            subtitle: translate('text_17526926730702mizvc3o8vm'),
            ...(hasPermissions(['featuresCreate']) && {
              buttonTitle: translate('text_17526926730703ysbxa2g5fj'),
              buttonAction: () => navigate(CREATE_FEATURE_ROUTE),
              buttonVariant: 'primary' as const,
            }),
          },
    }),
    [featuresVariables?.searchTerm, translate, hasPermissions, navigate],
  )

  const featuresTotalCount = featuresData?.features?.metadata?.totalCount

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_1752692673070k7z0mmf0494'),
          metadata: formatCountToMetadata(featuresTotalCount, translate),
          metadataLoading: isLoading,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_1752693359315fi592i0bpyz'),
              variant: 'primary',
              hidden: !hasPermissions(['featuresCreate']),
              onClick: () => navigate(CREATE_FEATURE_ROUTE),
            },
          ],
        }}
        filtersSection={
          <SearchInput
            onChange={debouncedSearch}
            placeholder={translate('text_1752692673070xf4wtgsrsum')}
          />
        }
      />

      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } = featuresData?.features.metadata || {}

          currentPage < totalPages &&
            !isLoading &&
            fetchMoreFeatures?.({
              variables: { page: currentPage + 1 },
            })
        }}
      >
        <Table
          name="features-list"
          isLoading={isLoading}
          hasError={!!featuresError}
          data={features || []}
          containerSize={{
            default: 16,
            md: 48,
          }}
          containerClassName={tw('border-t border-grey-300')}
          rowSize={72}
          onRowActionLink={(feature) =>
            generatePath(FEATURE_DETAILS_ROUTE, {
              featureId: feature.id,
              tab: FeatureDetailsTabsOptionsEnum.overview,
            })
          }
          placeholder={tablePlaceholder}
          actionColumnTooltip={
            canUpdateFeatures && canDeleteFeatures
              ? () => translate('text_626162c62f790600f850b7b6')
              : undefined
          }
          columns={[
            {
              key: 'name',
              title: translate('text_6419c64eace749372fc72b0f'),
              maxSpace: true,
              minWidth: 200,
              content: (feature) => (
                <div className="flex items-center gap-3">
                  <Avatar size="big" variant="connector">
                    <Icon name="switch" color="dark" />
                  </Avatar>
                  <div>
                    <Typography variant="bodyHl" color="grey700">
                      {feature.name || '-'}
                    </Typography>
                    <TypographyWithCopy compact variant="caption" color="grey600">
                      {feature.code}
                    </TypographyWithCopy>
                  </div>
                </div>
              ),
            },
            {
              key: 'subscriptionsCount',
              minWidth: 140,
              textAlign: 'right',
              title: translate('text_62d95e42c1e1dfe7376fdf35'),
              content: ({ subscriptionsCount }) => (
                <Typography color="grey600" variant="body">
                  {subscriptionsCount}
                </Typography>
              ),
            },

            {
              key: 'createdAt',
              minWidth: 140,
              title: translate('text_62442e40cea25600b0b6d858'),
              content: ({ createdAt }) => {
                return (
                  <Typography color="grey600" variant="body">
                    {
                      intlFormatDateTime(createdAt, {
                        formatDate: DateFormat.DATE_MED,
                      }).date
                    }
                  </Typography>
                )
              },
            },
          ]}
          actionColumn={(feature) => {
            const actions: ActionItem<typeof feature>[] = []

            if (canUpdateFeatures) {
              actions.push({
                title: translate('text_63e51ef4985f0ebd75c212fc'),
                startIcon: 'pen',
                onAction: async ({ id }: { id: string }) => {
                  navigate(generatePath(UPDATE_FEATURE_ROUTE, { featureId: id }))
                },
              })
            }

            if (canDeleteFeatures) {
              actions.push({
                title: translate('text_63ea0f84f400488553caa786'),
                startIcon: 'trash',
                onAction: async () => {
                  openDeleteFeatureDialog({
                    feature: { id: feature.id },
                  })
                },
              })
            }

            return actions
          }}
        />
      </InfiniteScroll>
    </>
  )
}

export default FeaturesList
