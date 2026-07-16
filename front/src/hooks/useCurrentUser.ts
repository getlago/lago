import { gql, useReactiveVar } from '@apollo/client'
import { useEffect, useMemo } from 'react'
import { useParams } from 'react-router-dom'

import { currentOrganizationVar } from '~/core/apolloClient/reactiveVars'
import {
  CurrentUserInfosFragment,
  MembershipPermissionsFragmentDoc,
  OrgSlugResolverDataFragmentDoc,
  useGetCurrentUserInfosQuery,
} from '~/generated/graphql'

import { useIsAuthenticated } from './auth/useIsAuthenticated'

gql`
  fragment CurrentUserInfos on User {
    id
    email
    premium
    ...OrgSlugResolverData
    memberships {
      roles
      ...MembershipPermissions
      organization {
        name
        logoUrl
        accessibleByCurrentSession
      }
    }
  }

  query getCurrentUserInfos {
    currentUser {
      ...CurrentUserInfos
    }
  }

  ${MembershipPermissionsFragmentDoc}
  ${OrgSlugResolverDataFragmentDoc}
`

type UseCurrentUser = () => {
  isPremium: boolean
  loading: boolean
  currentUser?: CurrentUserInfosFragment
  currentMembership?: CurrentUserInfosFragment['memberships'][0]
  refetchCurrentUserInfos: () => void
}

export const useCurrentUser: UseCurrentUser = () => {
  const { isAuthenticated } = useIsAuthenticated()
  const currentOrganizationId = useReactiveVar(currentOrganizationVar)
  const { organizationSlug } = useParams<{ organizationSlug: string }>()

  const {
    data,
    loading,
    refetch: refetchCurrentUserInfos,
  } = useGetCurrentUserInfosQuery({
    fetchPolicy: 'cache-first',
    nextFetchPolicy: 'cache-first',
    notifyOnNetworkStatusChange: true,
    skip: !isAuthenticated,
  })

  // `currentMembership` is derived from the URL slug (per-tab source of truth)
  // rather than from `currentOrganizationVar` (LS-backed, browser-global).
  // This makes permission checks, role lookups, and gating UI consistent with
  // the org the URL is pointing at — even when another tab last wrote a
  // different orgId to LS. Falls back to LS-based lookup for routes that
  // don't carry a slug (e.g. `/login`, customer portal) so callers outside
  // the `/:organizationSlug` scope keep working.
  const currentMembership = useMemo(() => {
    const memberships = data?.currentUser?.memberships
    const fromSlug =
      organizationSlug &&
      memberships?.find((membership) => membership.organization.slug === organizationSlug)

    if (fromSlug) return fromSlug

    return memberships?.find((membership) => membership.organization.id === currentOrganizationId)
  }, [data?.currentUser?.memberships, currentOrganizationId, organizationSlug])

  // Recover from a stale cached `currentUser` on a hard reload: `cache-first` can
  // serve a persisted user whose `memberships` don't include the URL slug's org,
  // leaving `currentMembership` undefined and `OrganizationLayout` stuck on
  // Error404. Keyed off the slug (not just the org var, which is null until
  // `OrganizationLayout` resolves the org — a deadlock when no membership matches)
  // so the refetch reconciles against the network.
  useEffect(() => {
    if (isAuthenticated && !currentMembership && (organizationSlug || currentOrganizationId)) {
      refetchCurrentUserInfos()
    }
  }, [
    organizationSlug,
    currentOrganizationId,
    isAuthenticated,
    currentMembership,
    refetchCurrentUserInfos,
  ])

  return {
    currentMembership,
    currentUser: data?.currentUser,
    isPremium: data?.currentUser.premium || false,
    loading: loading,
    refetchCurrentUserInfos,
  }
}
