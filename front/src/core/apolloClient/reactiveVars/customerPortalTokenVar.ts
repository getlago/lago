import { makeVar } from '@apollo/client'

import { getItemFromLS, setItemFromLS } from '~/core/utils/localStorage'

export const CUSTOMER_PORTAL_TOKEN_LS_KEY = 'customerPortalToken'

/** ----------------- VAR ----------------- */
export const customerPortalTokenVar = makeVar<string>(getItemFromLS(CUSTOMER_PORTAL_TOKEN_LS_KEY))

export const updateCustomerPortalTokenVar = (token?: string) => {
  setItemFromLS(CUSTOMER_PORTAL_TOKEN_LS_KEY, token)
  customerPortalTokenVar(token)
}
