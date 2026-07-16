import { ApolloError, gql, QueryResult } from '@apollo/client'
import { FC, useMemo } from 'react'

import { formatActivityType } from '~/components/activityLogs/utils'
import {
  Table,
  TableColumn,
  TablePlaceholder,
  TableProps,
} from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { ActivityLogsTableDataFragment } from '~/generated/graphql'
import { useActivityLogsInformation } from '~/hooks/activityLogs/useActivityLogsInformation'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

gql`
  fragment ActivityLogsTableData on ActivityLog {
    activityId
    activityType
    activityObject
    loggedAt
    externalCustomerId
    externalSubscriptionId
  }
`

interface ActivityLogsTableProps extends Pick<
  TableProps<ActivityLogsTableDataFragment>,
  'data' | 'isLoading' | 'containerSize' | 'onRowActionLink'
> {
  refetch: QueryResult['refetch']
  error: ApolloError | undefined
}

export const ActivityLogsTable: FC<ActivityLogsTableProps> = ({
  data,
  error,
  isLoading,
  containerSize = 16,
  onRowActionLink,
  refetch,
}) => {
  const { translate } = useInternationalization()
  const { formattedDateTimeWithSecondsOrgaTZ } = useFormatterDateHelper()
  const { getActivityDescription } = useActivityLogsInformation()

  const tablePlaceholder: TablePlaceholder = useMemo(() => {
    const placeholder: TablePlaceholder = {
      emptyState: {
        title: translate('text_1747314141347sfeoozf86o7'),
        subtitle: translate('text_1747314141347gs3g2lpln2h'),
      },
    }

    if (hasDefinedGQLError('FeatureUnavailable', error)) {
      placeholder.errorState = {
        title: translate('text_1747314141347qq6rasuxisl'),
        subtitle: translate('text_1764181883406sg3ir0pbxkt'),
      }
    } else if (error) {
      placeholder.errorState = {
        title: translate('text_1747058197364dm3no1jnete'),
        subtitle: translate('text_63e27c56dfe64b846474ef3b'),
        buttonTitle: translate('text_63e27c56dfe64b846474ef3c'),
        buttonAction: () => refetch(),
      }
    }

    return placeholder
  }, [error, refetch, translate])

  const logs = useMemo(() => {
    return data.map((log) => ({
      ...log,
      id: log.activityId,
    }))
  }, [data])

  const columns: Array<TableColumn<(typeof logs)[number]>> = [
    {
      title: translate('text_6560809c38fb9de88d8a52fb'),
      key: 'activityType',
      content: ({ activityType }) => (
        <Typography color="grey600" variant="captionCode">
          {formatActivityType(activityType)}
        </Typography>
      ),
    },
    {
      title: translate('text_6388b923e514213fed58331c'),
      key: 'activityId',
      maxSpace: true,
      content: ({ activityType, activityObject, externalCustomerId, externalSubscriptionId }) => {
        const activityDescription = getActivityDescription(activityType, {
          activityObject,
          externalCustomerId: externalCustomerId ?? undefined,
          externalSubscriptionId: externalSubscriptionId ?? undefined,
        })

        return (
          <Typography color="grey700" variant="bodyHl" noWrap>
            {activityDescription}
          </Typography>
        )
      },
    },
    {
      title: translate('text_664cb90097bfa800e6efa3f5'),
      key: 'loggedAt',
      content: ({ loggedAt }) => (
        <Typography noWrap>{formattedDateTimeWithSecondsOrgaTZ(loggedAt)}</Typography>
      ),
    },
  ]

  return (
    <Table
      name="activity-logs"
      containerClassName="h-auto"
      containerSize={containerSize}
      rowSize={48}
      data={logs}
      hasError={!!error}
      isLoading={isLoading}
      onRowActionLink={onRowActionLink}
      columns={columns}
      placeholder={tablePlaceholder}
    />
  )
}
