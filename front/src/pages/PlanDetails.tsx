import { gql } from '@apollo/client'
import { useEffect } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { useDeletePlanDialog } from '~/components/plans/DeletePlanDialog'
import { PlanDetailsV2 } from '~/components/plans/details-v2/PlanDetailsV2'
import { PlanDetailsActivityLogs } from '~/components/plans/details/PlanDetailsActivityLogs'
import PlanSubscriptionList from '~/components/plans/details/PlanSubscriptionList'
import { updateDuplicatePlanVar } from '~/core/apolloClient'
import { PlanDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CREATE_PLAN_ROUTE,
  CUSTOMER_SUBSCRIPTION_PLAN_DETAILS,
  PLAN_DETAILS_ROUTE,
  PLANS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  DeletePlanDialogFragment,
  DeletePlanDialogFragmentDoc,
  LagoApiError,
  useGetPlanForDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query getPlanForDetails($planId: ID!) {
    plan(id: $planId) {
      id
      name
      code
      parent {
        id
      }
      ...DeletePlanDialog
    }
  }

  ${DeletePlanDialogFragmentDoc}
`

const PlanDetails = () => {
  const navigate = useNavigate()
  const { hasPermissions } = usePermissions()
  const { customerId, planId, subscriptionId } = useParams()
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()

  const { openDeletePlanDialog } = useDeletePlanDialog()
  const {
    data: planResult,
    loading: isPlanLoading,
    error: planError,
  } = useGetPlanForDetailsQuery({
    variables: { planId: planId as string },
    skip: !planId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })
  const plan = planResult?.plan

  useNotFoundRedirect({
    error: planError,
    loading: isPlanLoading,
    redirectTo: PLANS_ROUTE,
    translateKey: 'text_17779954437882bskjocn0qv',
  })

  useEffect(() => {
    // WARNING: This page should not be used to show overridden plan's details
    // If a parent plan is detected, redirect to the plans list
    if (!!plan?.parent?.id) {
      navigate(PLANS_ROUTE, { replace: true })
    }
  }, [navigate, plan?.parent?.id])

  const actions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_626162c62f790600f850b6fe'),
      dataTest: 'plan-details-actions',
      items: [
        {
          label: translate('text_65281f686a80b400c8e2f6b6'),
          hidden: !hasPermissions(['plansCreate']),
          onClick: (closePopper) => {
            updateDuplicatePlanVar({
              type: 'duplicate',
              parentId: plan?.id,
            })
            navigate(CREATE_PLAN_ROUTE)
            closePopper()
          },
        },
        {
          label: translate('text_625fd165963a7b00c8f597b5'),
          hidden: !hasPermissions(['plansDelete']),
          onClick: (closePopper) => {
            openDeletePlanDialog({
              plan: plan as DeletePlanDialogFragment,
              callback: () => {
                navigate(PLANS_ROUTE)
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
        breadcrumb={[{ label: translate('text_62442e40cea25600b0b6d84a'), path: PLANS_ROUTE }]}
        entity={{
          viewName: translate('text_65281f686a80b400c8e2f6ad', { planName: plan?.name }),
          viewNameLoading: isPlanLoading,
          metadata: plan?.code ? <TypographyWithCopy>{plan.code}</TypographyWithCopy> : undefined,
          metadataLoading: isPlanLoading,
        }}
        actions={{ items: actions, loading: isPlanLoading }}
        tabs={[
          {
            title: translate('text_628cf761cbe6820138b8f2e4'),
            link: generatePath(PLAN_DETAILS_ROUTE, {
              planId: planId as string,
              tab: PlanDetailsTabsOptionsEnum.overview,
            }),
            match: [
              generatePath(PLAN_DETAILS_ROUTE, {
                planId: planId as string,
                tab: PlanDetailsTabsOptionsEnum.overview,
              }),
              generatePath(CUSTOMER_SUBSCRIPTION_PLAN_DETAILS, {
                customerId: customerId || '',
                subscriptionId: subscriptionId || '',
                planId: planId as string,
                tab: PlanDetailsTabsOptionsEnum.overview,
              }),
            ],
            content: (
              <DetailsPage.Container className="pb-0">
                <PlanDetailsV2 planId={planId as string} />
              </DetailsPage.Container>
            ),
          },
          {
            title: translate('text_6250304370f0f700a8fdc28d'),
            link: generatePath(PLAN_DETAILS_ROUTE, {
              planId: planId as string,
              tab: PlanDetailsTabsOptionsEnum.subscriptions,
            }),
            match: [
              generatePath(PLAN_DETAILS_ROUTE, {
                planId: planId as string,
                tab: PlanDetailsTabsOptionsEnum.subscriptions,
              }),
            ],
            content: (
              <DetailsPage.Container>
                <PlanSubscriptionList planCode={plan?.code} />
              </DetailsPage.Container>
            ),
          },
          {
            title: translate('text_1747314141347qq6rasuxisl'),
            link: generatePath(PLAN_DETAILS_ROUTE, {
              planId: planId as string,
              tab: PlanDetailsTabsOptionsEnum.activityLogs,
            }),
            content: <PlanDetailsActivityLogs planId={planId as string} />,
            hidden: !isPremium || !hasPermissions(['auditLogsView']),
          },
        ]}
      />

      <>{activeTabContent}</>
    </>
  )
}

export default PlanDetails
