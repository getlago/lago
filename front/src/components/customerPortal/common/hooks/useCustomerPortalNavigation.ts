import { generatePath, useParams } from 'react-router-dom'

import { useLocation, useNavigate } from '~/core/router'
import {
  CUSTOMER_PORTAL_CUSTOMER_EDIT_INFORMATION_ROUTE,
  CUSTOMER_PORTAL_ROUTE,
  CUSTOMER_PORTAL_USAGE_ROUTE,
  CUSTOMER_PORTAL_WALLET_ROUTE,
} from '~/core/router/paths/customerPortal'

const useCustomerPortalNavigation = () => {
  const { token } = useParams()
  const navigate = useNavigate()
  const { pathname } = useLocation()

  const goHome = () => {
    navigate(generatePath(CUSTOMER_PORTAL_ROUTE, { token: token as string }))
  }

  const viewSubscription = (id: string) =>
    navigate(
      generatePath(CUSTOMER_PORTAL_USAGE_ROUTE, {
        token: token as string,
        itemId: id,
      }),
    )

  const viewWallet = (walletId: string) =>
    navigate(
      generatePath(CUSTOMER_PORTAL_WALLET_ROUTE, {
        token: token as string,
        walletId,
      }),
    )

  const viewEditInformation = () =>
    navigate(
      generatePath(CUSTOMER_PORTAL_CUSTOMER_EDIT_INFORMATION_ROUTE, {
        token: token as string,
      }),
    )

  return {
    pathname,
    goHome,
    viewSubscription,
    viewWallet,
    viewEditInformation,
  }
}

export default useCustomerPortalNavigation
