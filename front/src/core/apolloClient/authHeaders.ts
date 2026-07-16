import { matchPath } from 'react-router-dom'

import {
  AUTH_TOKEN_LS_KEY,
  CUSTOMER_PORTAL_TOKEN_LS_KEY,
  getCurrentOrganizationId,
  TMP_AUTH_TOKEN_LS_KEY,
} from '~/core/apolloClient/reactiveVars'
import { CUSTOMER_PORTAL_ROUTE } from '~/core/router/paths/customerPortal'
import { getItemFromLS } from '~/core/utils/localStorage'

// Credentials are scoped by route: a logged-in admin previewing a customer
// portal keeps both tokens in localStorage, and only the URL tells which
// context the request belongs to. Sending the admin Bearer on portal routes
// breaks the portal when that token is expired (the API rejects it before
// reading customer-portal-token), and sending the portal token on admin
// routes leaks it on every request after visiting any portal link.
export const buildAuthHeaders = (pathname: string): Record<string, string> => {
  const isCustomerPortal = !!matchPath(`${CUSTOMER_PORTAL_ROUTE}/*`, pathname)

  if (isCustomerPortal) {
    const customerPortalToken = getItemFromLS(CUSTOMER_PORTAL_TOKEN_LS_KEY)

    return customerPortalToken ? { 'customer-portal-token': customerPortalToken } : {}
  }

  const token = getItemFromLS(AUTH_TOKEN_LS_KEY) || getItemFromLS(TMP_AUTH_TOKEN_LS_KEY)
  const currentOrganizationId = getCurrentOrganizationId()

  return {
    ...(token ? { authorization: `Bearer ${token}` } : {}),
    ...(currentOrganizationId ? { 'x-lago-organization': currentOrganizationId } : {}),
  }
}
