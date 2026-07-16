import { gql, useApolloClient } from '@apollo/client'
import { useCallback, useEffect, useMemo, useState } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { PlanDetailsV2 } from '~/components/plans/details-v2/PlanDetailsV2'
import { PlanDetailsV2Skeleton } from '~/components/plans/details-v2/PlanDetailsV2Skeleton'
import PremiumFeature from '~/components/premium/PremiumFeature'
import {
  GetSubscriptionFixedChargeUnitsOverridesDocument,
  GetSubscriptionFixedChargeUnitsOverridesQuery,
  GetSubscriptionFixedChargeUnitsOverridesQueryVariables,
  LagoApiError,
  PlanDetailsV2FragmentDoc,
  useGetSubscriptionForDetailsV2PlanQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'

gql`
  query getSubscriptionForDetailsV2Plan($subscriptionId: ID!) {
    subscription(id: $subscriptionId) {
      id
      plan {
        id
        parent {
          id
        }
        ...PlanDetailsV2
      }
    }
  }

  # Override-aware units come from Subscription.fixedCharges (the BE returns the
  # effective units for every fixed charge: the override, or the plan default
  # when there is no override). FixedCharge is normalised by id, and
  # Subscription.fixedCharges shares that entity with Plan.fixedCharges, so this
  # is fetched IMPERATIVELY (client.query, fetchPolicy: 'no-cache') and held in
  # local state — see the component. A subscribed useQuery would have its result
  # re-broadcast to the cached plan-default units when the plan queries write the
  # shared FixedCharge; an imperative one-shot read keeps the override value.
  query getSubscriptionFixedChargeUnitsOverrides($subscriptionId: ID!) {
    subscription(id: $subscriptionId) {
      id
      fixedCharges {
        id
        units
      }
    }
  }

  ${PlanDetailsV2FragmentDoc}
`

type Props = {
  subscriptionId: string
}

export const SubscriptionDetailsV2Plan = ({ subscriptionId }: Props) => {
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const client = useApolloClient()
  const { data, loading } = useGetSubscriptionForDetailsV2PlanQuery({
    variables: { subscriptionId },
    skip: !subscriptionId,
    context: { silentError: [LagoApiError.NotFound] },
  })

  // Override units, keyed by FixedCharge id, kept in plain React state and
  // fetched imperatively so the displayed value is fully decoupled from the
  // Apollo cache (see the query comment). refetchOverrides is threaded to the
  // edit mutation so a save re-reads the fresh override units.
  const [subscriptionFixedChargeUnitsById, setSubscriptionFixedChargeUnitsById] = useState<
    Record<string, string>
  >({})
  const [overridesLoaded, setOverridesLoaded] = useState(false)

  const refetchOverrides = useCallback(async () => {
    if (!subscriptionId) return

    try {
      const { data: overridesData } = await client.query<
        GetSubscriptionFixedChargeUnitsOverridesQuery,
        GetSubscriptionFixedChargeUnitsOverridesQueryVariables
      >({
        query: GetSubscriptionFixedChargeUnitsOverridesDocument,
        variables: { subscriptionId },
        fetchPolicy: 'no-cache',
        context: { silentError: [LagoApiError.NotFound] },
      })

      const map: Record<string, string> = {}

      for (const fixedCharge of overridesData?.subscription?.fixedCharges ?? []) {
        map[fixedCharge.id] = fixedCharge.units
      }

      setSubscriptionFixedChargeUnitsById(map)
    } catch {
      // Silent (matches the NotFound handling): fall back to plan-default units.
      setSubscriptionFixedChargeUnitsById({})
    } finally {
      setOverridesLoaded(true)
    }
  }, [client, subscriptionId])

  useEffect(() => {
    refetchOverrides()
  }, [refetchOverrides])

  const plan = data?.subscription?.plan

  const banner = useMemo(() => {
    if (!isPremium) {
      return (
        <PremiumFeature
          feature={translate('text_65118a52df984447c18694d1')}
          title={translate('text_65118a52df984447c18694d0')}
          description={translate('text_65118a52df984447c18694da')}
        />
      )
    }

    if (!plan?.parent) {
      return <Alert type="info">{translate('text_652525609f420d00b83dd602')}</Alert>
    }

    return undefined
  }, [isPremium, plan?.parent, translate])

  if (loading && !plan) {
    return <PlanDetailsV2Skeleton />
  }

  if (!plan) {
    return null
  }

  // The fixed-charge rows derive their units from `override ?? planDefault`.
  // Override units come from the imperative overrides read, which resolves
  // independently of the cached plan data. Holding the skeleton until it has
  // settled avoids rendering the plan default first and then snapping to the
  // override (or vice-versa) — the units flicker seen on initial load.
  if (!overridesLoaded) {
    return <PlanDetailsV2Skeleton />
  }

  return (
    <PlanDetailsV2
      planId={plan.id}
      isInSubscriptionForm
      subscriptionId={subscriptionId}
      subscriptionFixedChargeUnitsById={subscriptionFixedChargeUnitsById}
      refetchOverrides={refetchOverrides}
      banner={banner}
    />
  )
}
