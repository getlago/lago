import { gql } from '@apollo/client'

import { ActivityLogsTable } from '~/components/activityLogs/ActivityLogsTable'
import { buildLinkToActivityLog } from '~/components/activityLogs/utils'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { PageSectionTitle } from '~/components/layouts/Section'
import {
  ActivityLogsTableDataFragmentDoc,
  LagoApiError,
  ResourceTypeEnum,
  useBillableMetricActivityLogsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useDeveloperTool } from '~/hooks/useDeveloperTool'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query BillableMetricActivityLogs(
    $page: Int
    $limit: Int
    $resourceTypes: [ResourceTypeEnum!]
    $resourceIds: [String!]
  ) {
    activityLogs(
      page: $page
      limit: $limit
      resourceTypes: $resourceTypes
      resourceIds: $resourceIds
    ) {
      collection {
        ...ActivityLogsTableData
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }

  ${ActivityLogsTableDataFragmentDoc}
`

interface BillableMetricDetailsActivityLogsProps {
  billableMetricId: string
}

export const BillableMetricDetailsActivityLogs = ({
  billableMetricId,
}: BillableMetricDetailsActivityLogsProps) => {
  const { translate } = useInternationalization()
  const { openPanel: open, setUrl } = useDeveloperTool()
  const { hasPermissions } = usePermissions()
  const { isPremium } = useCurrentUser()

  const canViewLogs = isPremium && hasPermissions(['auditLogsView'])

  const { data, loading, error, refetch, fetchMore } = useBillableMetricActivityLogsQuery({
    variables: {
      resourceTypes: [ResourceTypeEnum.BillableMetric],
      resourceIds: [billableMetricId],
      limit: 20,
    },
    context: {
      silentErrorCodes: [LagoApiError.FeatureUnavailable],
    },
    skip: !canViewLogs,
  })

  return (
    <section className="flex flex-col gap-12">
      <section>
        <PageSectionTitle
          title={translate('text_1747314141347qq6rasuxisl')}
          subtitle={translate('text_1748269135971fmdsm6bs8ig')}
        />

        <InfiniteScroll
          onBottom={async () => {
            const { currentPage = 0, totalPages = 0 } = data?.activityLogs?.metadata || {}

            if (currentPage < totalPages && !loading) {
              await fetchMore({
                variables: { page: currentPage + 1 },
              })
            }
          }}
        >
          <ActivityLogsTable
            containerSize={4}
            data={data?.activityLogs?.collection ?? []}
            error={error}
            isLoading={loading}
            refetch={refetch}
            onRowActionLink={(row) => {
              const url = buildLinkToActivityLog(row.activityId)

              open()
              setUrl(url)

              // We return an empty string to avoid the default behavior of the table
              return ''
            }}
          />
        </InfiniteScroll>
      </section>
    </section>
  )
}
