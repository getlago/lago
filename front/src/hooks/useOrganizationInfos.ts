import { gql, useReactiveVar } from '@apollo/client'
import { useEffect } from 'react'
import { useParams } from 'react-router-dom'

import { currentOrganizationVar } from '~/core/apolloClient/reactiveVars/currentOrganizationVar'
import {
  intlFormatDateTime,
  IntlFormatDateTimeOptions,
  TimezoneConfigObject,
  TimeZonesConfig,
} from '~/core/timezone'
import {
  FeatureFlagEnum,
  MainOrganizationInfosFragment,
  OrganizationForDatePickerFragmentDoc,
  PremiumIntegrationTypeEnum,
  TimezoneEnum,
  useGetOrganizationInfosQuery,
} from '~/generated/graphql'
import { useIsAuthenticated } from '~/hooks/auth/useIsAuthenticated'

gql`
  fragment MainOrganizationInfos on CurrentOrganization {
    id
    name
    slug
    logoUrl
    timezone
    defaultCurrency
    featureFlags
    premiumIntegrations
    canCreateBillingEntity
    authenticationMethods
    authenticatedMethod

    ...OrganizationForDatePicker
  }

  query getOrganizationInfos {
    organization {
      ...MainOrganizationInfos
    }
  }

  ${OrganizationForDatePickerFragmentDoc}
`

type UseOrganizationInfos = () => {
  loading: boolean
  organization?: MainOrganizationInfosFragment
  timezone: TimezoneEnum
  timezoneConfig: TimezoneConfigObject
  hasFeatureFlag: (flag: FeatureFlagEnum) => boolean
  hasOrganizationPremiumAddon: (integration: PremiumIntegrationTypeEnum) => boolean
  refetchOrganizationInfos: () => void
  intlFormatDateTimeOrgaTZ: (
    date: string,
    options?: IntlFormatDateTimeOptions,
  ) => { date: string; time: string; timezone: string }
}

export const useOrganizationInfos: UseOrganizationInfos = () => {
  const { isAuthenticated } = useIsAuthenticated()
  const { organizationSlug } = useParams<{ organizationSlug: string }>()
  const currentOrganizationId = useReactiveVar(currentOrganizationVar)
  const { data, loading, refetch } = useGetOrganizationInfosQuery({
    fetchPolicy: 'cache-first',
    nextFetchPolicy: 'cache-first',
    notifyOnNetworkStatusChange: true,
    skip: !isAuthenticated || !currentOrganizationId,
  })

  const isStale =
    !!organizationSlug && !!data?.organization && data.organization.slug !== organizationSlug

  // Defense in depth: when stale data is detected, force a refetch
  useEffect(() => {
    if (isStale) {
      refetch()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isStale])

  const organization = isStale ? undefined : data?.organization || undefined

  const orgaTimezone = organization?.timezone || TimezoneEnum.TzUtc
  const timezoneConfig = TimeZonesConfig[orgaTimezone]

  const featureFlags = organization?.featureFlags
  const premiumIntegrations = organization?.premiumIntegrations

  return {
    loading: loading || isStale,
    organization,
    timezone: orgaTimezone || TimezoneEnum.TzUtc,
    timezoneConfig,
    hasFeatureFlag: (flag: FeatureFlagEnum) => !!featureFlags?.includes(flag),
    hasOrganizationPremiumAddon: (integration: PremiumIntegrationTypeEnum) =>
      !!premiumIntegrations?.includes(integration),
    refetchOrganizationInfos: refetch,
    intlFormatDateTimeOrgaTZ: (date: string, options?: IntlFormatDateTimeOptions) => {
      const appliedOptions = options || {}

      return intlFormatDateTime(date, {
        ...appliedOptions,
        timezone: orgaTimezone,
      })
    },
  }
}
