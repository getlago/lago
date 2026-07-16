import { useApolloClient } from '@apollo/client'
import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'

import { Spinner } from '~/components/designSystem/Spinner'
import { onAccessCustomerPortal, pausePersistence } from '~/core/apolloClient'
import CustomerPortal from '~/pages/customerPortal/CustomerPortal'

const PortalInit = () => {
  const { token } = useParams()
  const client = useApolloClient()
  const [isReady, setIsReady] = useState(false)

  useEffect(() => {
    if (!token) {
      return
    }

    const init = async () => {
      // Stop persisting to the shared admin blob (no-op on a fresh portal load
      // where persistence was skipped at setup; stops writes on same-tab
      // admin → portal nav). Do NOT purge — that would delete the admin's
      // at-rest cache, which a different tab may still rely on.
      pausePersistence()

      try {
        await client.clearStore()
      } catch {
        // proceed to grant portal access regardless
      }

      onAccessCustomerPortal(token)
      setIsReady(true)
    }

    init()
  }, [client, token])

  if (!token || !isReady) {
    return <Spinner />
  }

  return <CustomerPortal />
}

export default PortalInit
