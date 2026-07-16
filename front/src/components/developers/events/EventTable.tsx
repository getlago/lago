import { FC, RefObject, useMemo } from 'react'
import { generatePath } from 'react-router-dom'

import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { EVENT_LOG_ROUTE } from '~/components/developers/devtoolsRoutes'
import { ListSectionRef } from '~/components/developers/LogsLayout'
import { getCurrentBreakpoint } from '~/core/utils/getCurrentBreakpoint'
import { EventsQueryResult } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

type EventTableProps = {
  getEventsResult: EventsQueryResult
  logListRef: RefObject<ListSectionRef>
}

export const EventTable: FC<EventTableProps> = ({ getEventsResult, logListRef }) => {
  const { translate } = useInternationalization()
  const { formattedDateTimeWithSecondsOrgaTZ } = useFormatterDateHelper()

  const { data, error, loading, fetchMore, refetch } = getEventsResult

  const events = useMemo(
    () =>
      data?.events?.collection.map((event) => ({
        ...event,
        // We need to use the transactionId as the id because the eventId is not always available (for Clickhouse events)
        id: event.transactionId as string,
      })) || [],
    [data?.events?.collection],
  )

  return (
    <InfiniteScroll
      onBottom={async () => {
        const { currentPage = 0, totalPages = 0 } = data?.events?.metadata || {}

        if (currentPage < totalPages && !loading) {
          await fetchMore({
            variables: { page: currentPage + 1 },
          })
        }
      }}
    >
      <Table
        name="events-logs"
        containerClassName="h-auto"
        containerSize={16}
        rowSize={48}
        data={events}
        hasError={!!error}
        isLoading={loading}
        onRowActionLink={({ transactionId }) => {
          if (getCurrentBreakpoint() === 'sm') {
            logListRef.current?.updateView('forward')
          }

          return generatePath(EVENT_LOG_ROUTE, {
            '*': transactionId as string,
          })
        }}
        columns={[
          {
            title: translate('text_1747058197364eeqig77mkmq'),
            key: 'code',
            content: ({ code }) => (
              <Typography color="grey700" variant="captionCode">
                {code}
              </Typography>
            ),
            maxSpace: true,
          },
          {
            title: translate('text_664cb90097bfa800e6efa3f5'),
            key: 'receivedAt',
            content: ({ receivedAt }) => (
              <Typography noWrap>{formattedDateTimeWithSecondsOrgaTZ(receivedAt)}</Typography>
            ),
          },
        ]}
        placeholder={{
          emptyState: {
            title: translate('text_6298bd525e359200d5ea002a'),
            subtitle: translate('text_6298bd525e359200d5ea0036'),
          },
          errorState: {
            title: translate('text_1747058197364dm3no1jnete'),
            subtitle: translate('text_63e27c56dfe64b846474ef3b'),
            buttonTitle: translate('text_63e27c56dfe64b846474ef3c'),
            buttonAction: () => refetch(),
          },
        }}
      />
    </InfiniteScroll>
  )
}
