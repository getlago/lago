import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { BillableMetricDetailsActivityLogs } from '~/components/billableMetrics/BillableMetricDetailsActivityLogs'
import { BillableMetricDetailsOverview } from '~/components/billableMetrics/BillableMetricDetailsOverview'
import { useDeleteBillableMetricDialog } from '~/components/billableMetrics/DeleteBillableMetricDialog'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { addToast } from '~/core/apolloClient'
import { BillableMetricDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  BILLABLE_METRIC_DETAILS_ROUTE,
  BILLABLE_METRICS_ROUTE,
  DUPLICATE_BILLABLE_METRIC_ROUTE,
  UPDATE_BILLABLE_METRIC_ROUTE,
  useNavigate,
} from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { LagoApiError, useGetBillableMetricForHeaderDetailsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query getBillableMetricForHeaderDetails($id: ID!) {
    billableMetric(id: $id) {
      id
      name
      code
    }
  }
`

const BillableMetricDetails = () => {
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { billableMetricId } = useParams()
  const { isPremium } = useCurrentUser()

  const { openDeleteBillableMetricDialog } = useDeleteBillableMetricDialog()

  const { data, loading, error } = useGetBillableMetricForHeaderDetailsQuery({
    variables: {
      id: billableMetricId as string,
    },
    skip: !billableMetricId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  useNotFoundRedirect({
    error,
    loading,
    redirectTo: BILLABLE_METRICS_ROUTE,
    translateKey: 'text_1777995443789mu6h3lr2kbg',
  })

  const billableMetric = data?.billableMetric

  const actions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_626162c62f790600f850b6fe'),
      items: [
        {
          label: translate('text_1748440972215b2bo0i27zg4'),
          hidden: !hasPermissions(['billableMetricsUpdate']),
          onClick: (closePopper) => {
            navigate(
              generatePath(UPDATE_BILLABLE_METRIC_ROUTE, {
                billableMetricId: billableMetricId as string,
              }),
            )
            closePopper()
          },
        },
        {
          label: translate('text_1748440972215htw8rqfn3tu'),
          onClick: () => {
            copyToClipboard(billableMetricId as string)
            addToast({
              message: translate('text_1748441335808ev2ygtkq66n'),
              severity: 'success',
            })
          },
        },
        {
          label: translate('text_1748447578763m2i8k8djc4r'),
          hidden: !hasPermissions(['billableMetricsCreate']),
          onClick: () => {
            navigate(
              generatePath(DUPLICATE_BILLABLE_METRIC_ROUTE, {
                billableMetricId: billableMetricId as string,
              }),
            )
          },
        },
        {
          label: translate('text_1748440972215btigjp0mowx'),
          hidden: !hasPermissions(['billableMetricsDelete']),
          onClick: (closePopper) => {
            openDeleteBillableMetricDialog({
              billableMetricId: billableMetricId as string,
              callback: () => {
                navigate(generatePath(BILLABLE_METRICS_ROUTE))
              },
            })
            closePopper()
          },
        },
      ],
    },
  ]

  const activeTabContent = useMainHeaderTabContent()

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          { label: translate('text_623b497ad05b960101be3438'), path: BILLABLE_METRICS_ROUTE },
        ]}
        entity={{
          viewName: billableMetric?.name || '',
          viewNameLoading: loading,
          metadata: billableMetric?.code || '',
          metadataLoading: loading,
        }}
        actions={{ items: actions, loading }}
        tabs={[
          {
            title: translate('text_628cf761cbe6820138b8f2e4'),
            link: generatePath(BILLABLE_METRIC_DETAILS_ROUTE, {
              billableMetricId: billableMetricId as string,
              tab: BillableMetricDetailsTabsOptionsEnum.overview,
            }),
            content: (
              <DetailsPage.Container>
                <BillableMetricDetailsOverview />
              </DetailsPage.Container>
            ),
          },
          {
            title: translate('text_1747314141347qq6rasuxisl'),
            link: generatePath(BILLABLE_METRIC_DETAILS_ROUTE, {
              billableMetricId: billableMetricId as string,
              tab: BillableMetricDetailsTabsOptionsEnum.activityLogs,
            }),
            content: (
              <div className="px-4 py-6 md:px-12">
                <BillableMetricDetailsActivityLogs billableMetricId={billableMetricId as string} />
              </div>
            ),
            hidden: !isPremium || !hasPermissions(['auditLogsView']),
          },
        ]}
      />

      <>{activeTabContent}</>
    </>
  )
}

export default BillableMetricDetails
