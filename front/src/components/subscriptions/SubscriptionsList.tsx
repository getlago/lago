import { FC } from 'react'
import { generatePath, NavigateFunction } from 'react-router-dom'

import { useTerminateCustomerSubscriptionDialog } from '~/components/customers/subscriptions/TerminateCustomerSubscriptionDialog'
import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { Table, TableProps } from '~/components/designSystem/Table/Table'
import { ActionItem } from '~/components/designSystem/Table/types'
import { addToast } from '~/core/apolloClient'
import { subscriptionStatusMapping } from '~/core/constants/statusSubscriptionMapping'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  UPGRADE_DOWNGRADE_SUBSCRIPTION,
  useNavigate,
} from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  NextSubscriptionTypeEnum,
  Plan,
  StatusTypeEnum,
  Subscription,
  TimezoneEnum,
} from '~/generated/graphql'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import { useSubscriptionPermissionsActions } from '~/hooks/useSubscriptionPermissionsActions'

export type AnnotatedSubscription = {
  id: string
  externalId?: Subscription['externalId']
  name: Subscription['name']
  startedAt: Subscription['startedAt']
  endingAt?: Subscription['endingAt']
  terminatedAt?: Subscription['terminatedAt']
  status?: Subscription['status']
  frequency: Plan['interval']
  statusType: StatusProps
  payInAdvance: boolean
  isDowngrade?: boolean
  isScheduled?: boolean
  isOverridden?: boolean
  billingEntityId?: string | null
  customer: {
    id: string
    name?: string
    displayName?: string
    applicableTimezone: TimezoneEnum
    billingEntity?: {
      id: string
      code: string
      name?: string | null
    }
  }
}

const annotateSubscriptions = (
  subscriptions: Subscription[] | null | undefined,
  {
    customerTimezone,
    customerId,
    isStatusEditable,
  }: {
    customerTimezone?: TimezoneEnum
    customerId?: string
    isStatusEditable: (status: StatusTypeEnum | null | undefined) => boolean
  },
): AnnotatedSubscription[] => {
  return (subscriptions || []).reduce<AnnotatedSubscription[]>((subsAcc, subscription) => {
    const {
      id,
      plan,
      status,
      nextPlan,
      nextSubscriptionAt,
      nextSubscriptionType,
      externalId,
      nextName,
      name,
      startedAt,
      subscriptionAt,
      endingAt,
      terminatedAt,
      customer,
      nextSubscription,
      billingEntityId,
    } = subscription || {}

    const isDowngrading = !!nextPlan && nextSubscriptionType === NextSubscriptionTypeEnum.Downgrade

    const _sub = {
      id,
      externalId,
      name: name || plan.name,
      status,
      startedAt: startedAt || subscriptionAt,
      endingAt: endingAt,
      terminatedAt,
      frequency: plan.interval,
      statusType: subscriptionStatusMapping(status),
      payInAdvance: !!plan.payInAdvance,
      billingEntityId: billingEntityId ?? undefined,
      customer: {
        id: customerId || customer?.id,
        name: customer?.name || undefined,
        displayName: customer?.displayName,
        applicableTimezone: customerTimezone || customer?.applicableTimezone,
        billingEntity: customer?.billingEntity ?? undefined,
      },
      isScheduled: status === StatusTypeEnum.Pending,
      isOverridden: !!plan.isOverridden,
    }

    const _subDowngrade = isDowngrading &&
      isStatusEditable(status) &&
      nextPlan && {
        id: nextSubscription?.id || nextPlan.id,
        externalId: nextSubscription?.externalId,
        name: nextSubscription?.name || nextName || nextPlan.name,
        status: nextSubscription?.status,
        frequency: nextPlan.interval,
        startedAt: nextSubscriptionAt,
        statusType: {
          type: StatusType.default,
          label: 'pending',
        } as StatusProps,
        payInAdvance: !!plan.payInAdvance,
        isDowngrade: true,
        isOverridden: !!nextPlan.parent,
        customer: {
          id: customerId || customer?.id,
          name: customer?.name || undefined,
          displayName: customer?.displayName,
          applicableTimezone: customerTimezone || customer?.applicableTimezone,
        },
      }

    return [...subsAcc, _sub, ...(_subDowngrade ? [_subDowngrade] : [])]
  }, [])
}

const generateActionColumn = ({
  subscription,
  hasSubscriptionsUpdatePermission,
  openTerminateDialog,
  translate,
  navigate,
}: {
  subscription: AnnotatedSubscription
  hasSubscriptionsUpdatePermission: boolean
  openTerminateDialog: ReturnType<
    typeof useTerminateCustomerSubscriptionDialog
  >['openTerminateCustomerSubscriptionDialog']
  translate: TranslateFunc
  navigate: NavigateFunction
}) => {
  let actions: ActionItem<AnnotatedSubscription>[] = []

  const copyToClipboardAction: ActionItem<AnnotatedSubscription> = {
    startIcon: 'duplicate',
    title: translate('text_62d7f6178ec94cd09370e65b'),
    onAction: () => {
      if (!subscription.externalId) return

      copyToClipboard(subscription.externalId)

      addToast({
        severity: 'info',
        translateKey: 'text_62d94cc9ccc5eebcc03160a0',
      })
    },
  }

  if (
    subscription.status === StatusTypeEnum.Terminated ||
    subscription.status === StatusTypeEnum.Canceled ||
    subscription.status === StatusTypeEnum.Incomplete
  ) {
    return [copyToClipboardAction]
  }

  if (!subscription.isDowngrade && hasSubscriptionsUpdatePermission) {
    actions = actions.concat([
      {
        startIcon: 'text',
        title: translate('text_62d7f6178ec94cd09370e63c'),
        onAction: () =>
          navigate(
            generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
              customerId: subscription.customer.id,
              subscriptionId: subscription.id,
              tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
            }),
          ),
      },
      {
        startIcon: 'board',
        title: translate('text_17810297639135ya0hmsldpi'),
        onAction: () =>
          navigate(
            generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
              customerId: subscription.customer.id,
              subscriptionId: subscription.id,
              tab: CustomerSubscriptionDetailsTabsOptionsEnum.subscriptionPlan,
            }),
          ),
      },
      {
        startIcon: 'pen',
        title: translate('text_62d7f6178ec94cd09370e64a'),
        onAction: () =>
          navigate(
            generatePath(UPGRADE_DOWNGRADE_SUBSCRIPTION, {
              customerId: subscription.customer.id,
              subscriptionId: subscription.id,
            }),
          ),
      },
    ])
  }

  actions = actions.concat(copyToClipboardAction)

  actions = actions.concat({
    startIcon: 'bell',
    title: translate('text_1746785137190vu5wwlsmzmz'),
    onAction: () => {
      navigate(
        generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
          customerId: subscription.customer.id,
          subscriptionId: subscription.id,
          tab: CustomerSubscriptionDetailsTabsOptionsEnum.alerts,
        }),
      )
    },
  })

  if (hasSubscriptionsUpdatePermission) {
    actions = actions.concat({
      startIcon: 'trash',
      title:
        subscription.status === StatusTypeEnum.Pending
          ? translate('text_64a6d736c23125004817627f')
          : translate('text_62d904b97e690a881f2b867c'),
      onAction: () => {
        openTerminateDialog({
          id: subscription.id,
          name: subscription.name as string,
          status: subscription.status as StatusTypeEnum,
          payInAdvance: subscription.payInAdvance,
        })
      },
    })
  }

  return actions
}

interface SubscriptionsListProps extends Omit<TableProps<AnnotatedSubscription>, 'data'> {
  subscriptions: Subscription[]
  customerTimezone?: TimezoneEnum
  customerId?: string
}

export const SubscriptionsList: FC<SubscriptionsListProps> = ({
  subscriptions,
  customerTimezone,
  customerId,
  ...tableProps
}) => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { isStatusEditable } = useSubscriptionPermissionsActions()

  const { openTerminateCustomerSubscriptionDialog } = useTerminateCustomerSubscriptionDialog()

  const annotatedSubscriptions = annotateSubscriptions(subscriptions, {
    customerTimezone,
    customerId,
    isStatusEditable,
  })

  return (
    <>
      <Table
        {...tableProps}
        data={annotatedSubscriptions || []}
        rowDataTestId={(subscription) => subscription.name || `subscription-${subscription.id}`}
        actionColumn={(subscription) =>
          generateActionColumn({
            subscription,
            navigate,
            translate,
            openTerminateDialog: openTerminateCustomerSubscriptionDialog,
            hasSubscriptionsUpdatePermission: hasPermissions(['subscriptionsUpdate']),
          })
        }
      />
    </>
  )
}
