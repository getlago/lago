import { gql } from '@apollo/client'
import { FC } from 'react'

import { ActivityLogsTable } from '~/components/activityLogs/ActivityLogsTable'
import { buildLinkToActivityLog } from '~/components/activityLogs/utils'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { PageSectionTitle } from '~/components/layouts/Section'
import {
  ActivityLogsTableDataFragmentDoc,
  LagoApiError,
  useSubscriptionActivityLogsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useDeveloperTool } from '~/hooks/useDeveloperTool'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query SubscriptionActivityLogs($page: Int, $limit: Int, $externalSubscriptionId: String) {
    activityLogs(page: $page, limit: $limit, externalSubscriptionId: $externalSubscriptionId) {
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

interface SubscriptionActivityLogsProps {
  externalSubscriptionId: string
}

export const SubscriptionActivityLogs: FC<SubscriptionActivityLogsProps> = ({
  externalSubscriptionId,
}) => {
  const { translate } = useInternationalization()
  const { openPanel: open, setUrl } = useDeveloperTool()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()

  const canViewLogs = isPremium && hasPermissions(['auditLogsView'])

  const { data, loading, error, refetch, fetchMore } = useSubscriptionActivityLogsQuery({
    variables: {
      externalSubscriptionId: externalSubscriptionId,
      limit: 20,
    },
    context: {
      silentErrorCodes: [LagoApiError.FeatureUnavailable],
    },
    skip: !canViewLogs,
  })

  return (
    <div className="w-full pb-20 pt-6">
      <div className="flex flex-col gap-12">
        <div>
          <PageSectionTitle
            title={translate('text_1747314141347qq6rasuxisl')}
            subtitle={translate('text_17488665089772619td0qmi9')}
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
        </div>
      </div>
    </div>
  )
}
