import { gql } from '@apollo/client'
import { useMemo, useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { ResetProgressiveBillingDialogRef } from '~/components/subscriptions/ResetProgressiveBillingDialog'
import {
  EDIT_PROGRESSIVE_BILLING_CUSTOMER_SUBSCRIPTION_ROUTE,
  EDIT_PROGRESSIVE_BILLING_PLAN_SUBSCRIPTION_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  SubscriptionForUseProgressiveBillingTabThresholdsHeaderFragment,
  useSwitchProgressiveBillingDisabledValueMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  fragment SubscriptionForUseProgressiveBillingTabThresholdsHeader on Subscription {
    id
    progressiveBillingDisabled
    usageThresholds {
      id
    }
    plan {
      id
      applicableUsageThresholds {
        id
      }
    }
  }

  mutation switchProgressiveBillingDisabledValue($input: UpdateSubscriptionInput!) {
    updateSubscription(input: $input) {
      id
      progressiveBillingDisabled
    }
  }
`

interface UseSubscriptionProgressiveBillingTabThresholdsHeaderProps {
  subscription?: SubscriptionForUseProgressiveBillingTabThresholdsHeaderFragment | null
}

export const useSubscriptionProgressiveBillingTabThresholdsHeader = ({
  subscription,
}: UseSubscriptionProgressiveBillingTabThresholdsHeaderProps) => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { customerId = '', planId = '' } = useParams()

  const resetDialogRef = useRef<ResetProgressiveBillingDialogRef>(null)
  const canEditSubscription = hasPermissions(['subscriptionsUpdate'])

  const hasSubscriptionThresholds = (subscription?.usageThresholds?.length || 0) > 0
  const shouldDisplayOverriddenBadge =
    hasSubscriptionThresholds ||
    (subscription?.progressiveBillingDisabled &&
      (subscription.plan?.applicableUsageThresholds?.length || 0) > 0)

  const [
    switchProgressiveBillingDisabledValue,
    { loading: switchingProgressiveBillingDisabledValueLoading },
  ] = useSwitchProgressiveBillingDisabledValueMutation()

  const editProgressiveBillingFormPath = useMemo(() => {
    if (customerId) {
      return generatePath(EDIT_PROGRESSIVE_BILLING_CUSTOMER_SUBSCRIPTION_ROUTE, {
        customerId,
        subscriptionId: subscription?.id || '',
      })
    }
    return generatePath(EDIT_PROGRESSIVE_BILLING_PLAN_SUBSCRIPTION_ROUTE, {
      planId,
      subscriptionId: subscription?.id || '',
    })
  }, [customerId, planId, subscription?.id])

  const tooltipTitle = useMemo(() => {
    const enableDisableCopy = subscription?.progressiveBillingDisabled
      ? translate('text_17521580166150wyrhvd2u56')
      : translate('text_17521580166150wyrhvd2u57')

    if (hasSubscriptionThresholds) {
      return translate('text_1769642763701xwuflld9biu', {
        enableDisableCopy: enableDisableCopy.toLocaleLowerCase(),
      })
    }

    return translate('text_17696427637012io81h0jc2w', {
      enableDisableCopy: enableDisableCopy.toLocaleLowerCase(),
    })
  }, [hasSubscriptionThresholds, subscription?.progressiveBillingDisabled, translate])

  const toggleProgressiveBilling = async () => {
    if (!subscription?.id) return

    await switchProgressiveBillingDisabledValue({
      variables: {
        input: {
          id: subscription.id,
          progressiveBillingDisabled: !subscription.progressiveBillingDisabled,
        },
      },
    })
  }

  const openResetDialog = () => {
    if (subscription?.id) {
      resetDialogRef.current?.openDialog({
        subscriptionId: subscription.id,
      })
    }
  }

  const navigateToEditForm = () => {
    navigate(editProgressiveBillingFormPath)
  }

  return {
    // State
    canEditSubscription,
    hasSubscriptionThresholds,
    shouldDisplayOverriddenBadge,
    tooltipTitle,
    switchingProgressiveBillingDisabledValueLoading,

    // Refs
    resetDialogRef,

    // Actions
    navigateToEditForm,
    openResetDialog,
    toggleProgressiveBilling,

    // Translation helper
    translate,
  }
}
