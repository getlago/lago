import { gql, useReactiveVar } from '@apollo/client'
import { getCurrentScope } from '@sentry/react'
import { Settings } from 'luxon'
import { useEffect, useRef } from 'react'

import { addToast } from '~/core/apolloClient'
import { currentOrganizationVar } from '~/core/apolloClient/reactiveVars/currentOrganizationVar'
import { getTimezoneConfig } from '~/core/timezone'
import {
  CurrentUserInfosFragmentDoc,
  MainOrganizationInfosFragmentDoc,
  useUserIdentifierQuery,
} from '~/generated/graphql'
import { useIsAuthenticated } from '~/hooks/auth/useIsAuthenticated'

gql`
  query UserIdentifier {
    me: currentUser {
      id
      email
      ...CurrentUserInfos
    }
    organization {
      ...MainOrganizationInfos
    }
  }

  ${MainOrganizationInfosFragmentDoc}
  ${CurrentUserInfosFragmentDoc}
`

export const UserIdentifier = () => {
  const { isAuthenticated } = useIsAuthenticated()
  // The query includes the org-scoped `organization` field, so it must not run
  // without an org header. Gate it on the current org id (the same signal the
  // auth link uses). On slug-less surfaces (root `/`) it stays idle until
  // `OrganizationLayout` sets the org from the URL slug.
  const currentOrganizationId = useReactiveVar(currentOrganizationVar)
  const { data, refetch } = useUserIdentifierQuery({
    skip: !isAuthenticated || !currentOrganizationId,
  })
  // If for some reason we constantly get null on the meQuery, avoid inifnite refetch
  const refetchCountRef = useRef<number>(0)

  const slugFromPath = window.location.pathname.split('/')[1] ?? ''
  const isOrgDataStale =
    !!slugFromPath && !!data?.organization && data.organization.slug !== slugFromPath

  useEffect(() => {
    if (!isAuthenticated) {
      refetchCountRef.current = 0
      getCurrentScope().setUser(null)
      return
    }

    // No current org yet (e.g. root `/` before the slug resolves): the query is
    // skipped, so don't treat the absent data as an error to refetch/toast on.
    if (!currentOrganizationId) {
      return
    }

    if (!data) {
      if (refetchCountRef.current <= 3) {
        refetch()
        refetchCountRef.current = refetchCountRef.current + 1
      } else {
        addToast({
          severity: 'danger',
          translateKey: 'text_622f7a3dc32ce100c46a5154',
        })
      }
    } else {
      const { id, email } = data?.me || {}

      if (isOrgDataStale) {
        refetch()
      } else {
        Settings.defaultZone = getTimezoneConfig(data?.organization?.timezone).name
      }

      getCurrentScope().setUser({ id, email: email || undefined })
    }
  }, [data, isAuthenticated, currentOrganizationId, isOrgDataStale, refetch])

  return null
}
