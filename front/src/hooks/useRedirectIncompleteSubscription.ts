import { useEffect } from 'react'
import { generatePath } from 'react-router-dom'

import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, useNavigate } from '~/core/router'
import { StatusTypeEnum } from '~/generated/graphql'

interface UseRedirectIncompleteSubscriptionArgs {
  customerId?: string
  subscriptionId?: string | null
  subscriptionStatus?: StatusTypeEnum | null
}

/**
 * `incomplete` subscriptions are not editable, so redirect away from the
 * create/edit form to the subscription overview when one is opened.
 */
export const useRedirectIncompleteSubscription = ({
  customerId,
  subscriptionId,
  subscriptionStatus,
}: UseRedirectIncompleteSubscriptionArgs): void => {
  const navigate = useNavigate()

  useEffect(() => {
    if (!customerId || !subscriptionId || subscriptionStatus !== StatusTypeEnum.Incomplete) {
      return
    }

    navigate(
      generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
        customerId,
        subscriptionId,
        tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
      }),
      { replace: true },
    )
  }, [customerId, navigate, subscriptionId, subscriptionStatus])
}
