import { FC } from 'react'
import { generatePath, useParams, useSearchParams } from 'react-router-dom'

import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { WEBHOOK_LOGS_ROUTE } from '~/components/developers/devtoolsRoutes'
import { ListSectionRef } from '~/components/developers/LogsLayout'
import { statusWebhookMapping } from '~/components/developers/webhooks/utils'
import { getCurrentBreakpoint } from '~/core/utils/getCurrentBreakpoint'
import { GetWebhookLogQueryResult } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

type WebhookLogTableProps = {
  getWebhookLogsResult: GetWebhookLogQueryResult
  logListRef: React.RefObject<ListSectionRef>
  isLoading: boolean
}

export const WebhookLogTable: FC<WebhookLogTableProps> = ({
  getWebhookLogsResult,
  logListRef,
  isLoading,
}) => {
  const { webhookId = '' } = useParams<{ webhookId: string; logId?: string }>()
  const [searchParams] = useSearchParams()
  const { formattedDateTimeWithSecondsOrgaTZ } = useFormatterDateHelper()
  const { translate } = useInternationalization()

  const { data, error, loading, fetchMore, variables } = getWebhookLogsResult

  return (
    <InfiniteScroll
      onBottom={async () => {
        const { currentPage = 0, totalPages = 0 } = data?.webhooks?.metadata || {}

        if (currentPage < totalPages && !isLoading) {
          await fetchMore({
            variables: { page: currentPage + 1 },
          })
        }
      }}
    >
      <Table
        name="webhook-logs"
        containerClassName="h-full md:h-auto"
        containerSize={16}
        rowSize={48}
        data={data?.webhooks.collection || []}
        hasError={!!error}
        isLoading={loading}
        onRowActionLink={({ id }) => {
          const currentParams = searchParams.toString()
          const path = generatePath(WEBHOOK_LOGS_ROUTE, {
            webhookId,
            logId: id,
          })

          if (getCurrentBreakpoint() === 'sm') {
            logListRef.current?.updateView('forward')
          }

          return currentParams ? `${path}?${currentParams}` : path
        }}
        columns={[
          {
            title: translate('text_63ac86d797f728a87b2f9fa7'),
            key: 'status',
            content: ({ status }) => <Status {...statusWebhookMapping(status)} />,
          },
          {
            title: translate('text_1746622271766rmi2hgoq1sb'),
            key: 'webhookType',
            content: ({ webhookType }) => (
              <Typography color="grey700" variant="captionCode">
                {webhookType}
              </Typography>
            ),
            maxSpace: true,
          },
          {
            title: translate('text_664cb90097bfa800e6efa3f5'),
            key: 'updatedAt',
            content: ({ updatedAt }) => (
              <Typography noWrap>{formattedDateTimeWithSecondsOrgaTZ(updatedAt)}</Typography>
            ),
          },
        ]}
        placeholder={{
          emptyState: {
            title: translate(
              !!variables?.searchTerm
                ? 'text_63ebafd12755e50052a86e13'
                : 'text_63ebaf555f88d954d73beb7e',
            ),
            subtitle: !variables?.searchTerm ? (
              <Typography
                className="[&_a]:text-blue"
                html={translate('text_63ebafc2c3d08550e5c0341c')}
              />
            ) : (
              translate('text_63ebafd92755e50052a86e14')
            ),
          },
        }}
      />
    </InfiniteScroll>
  )
}
