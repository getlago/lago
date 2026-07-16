import { gql } from '@apollo/client'
import { useEffect, useRef } from 'react'
import { useParams } from 'react-router-dom'

import {
  AddCouponToCustomerDialog,
  AddCouponToCustomerDialogRef,
} from '~/components/customers/AddCouponToCustomerDialog'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { CUSTOMERS_LIST_ROUTE, useLocation, useNavigate } from '~/core/router'
import {
  AddCustomerDrawerFragmentDoc,
  CustomerMainInfosFragmentDoc,
  LagoApiError,
  useGetCustomerQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerDetailsHeaderActions } from '~/hooks/customer/useCustomerDetailsHeaderActions'
import { useCustomerDetailsHeaderEntity } from '~/hooks/customer/useCustomerDetailsHeaderEntity'
import { useCustomerDetailsHeaderTabs } from '~/hooks/customer/useCustomerDetailsHeaderTabs'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  fragment CustomerDetails on Customer {
    id
    customerType
    name
    displayName
    firstname
    lastname
    externalId
    hasActiveWallet
    currency
    hasCreditNotes
    creditNotesBalances {
      currency
      billingEntityId
      amountCents
      creditsAvailableCount
    }
    applicableTimezone
    hasOverdueInvoices
    accountType
    ...AddCustomerDrawer
    ...CustomerMainInfos
  }

  query getCustomer($id: ID!) {
    customer(id: $id) {
      ...CustomerDetails
    }
  }

  mutation generateCustomerPortalUrl($input: GenerateCustomerPortalUrlInput!) {
    generateCustomerPortalUrl(input: $input) {
      url
    }
  }

  ${AddCustomerDrawerFragmentDoc}
  ${CustomerMainInfosFragmentDoc}
`

const POLLING_INTERVAL = 1000
const MAX_POLLING_ATTEMPTS = 3

const CustomerDetails = () => {
  const addCouponDialogRef = useRef<AddCouponToCustomerDialogRef>(null)
  const pollingAttemptsRef = useRef(0)
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const location = useLocation()
  const { customerId } = useParams()

  const shouldPollIntegrations = (location.state as { shouldPollIntegrations?: boolean })
    ?.shouldPollIntegrations

  const { data, loading, error, startPolling, stopPolling } = useGetCustomerQuery({
    variables: { id: customerId as string },
    skip: !customerId,
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  const customer = data?.customer
  const hasAnyIntegrationCustomer =
    !!customer?.netsuiteCustomer ||
    !!customer?.anrokCustomer ||
    !!customer?.xeroCustomer ||
    !!customer?.hubspotCustomer ||
    !!customer?.salesforceCustomer

  // Start polling when coming from edit page with integrations (backend may process them async)
  useEffect(() => {
    if (shouldPollIntegrations && !hasAnyIntegrationCustomer) {
      pollingAttemptsRef.current = 0
      startPolling(POLLING_INTERVAL)
    }

    return () => {
      stopPolling()
    }
    // Only run on mount when shouldPollIntegrations is true
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shouldPollIntegrations])

  // Stop polling when integrations are loaded or max attempts reached
  useEffect(() => {
    if (!shouldPollIntegrations) return

    pollingAttemptsRef.current += 1

    if (hasAnyIntegrationCustomer || pollingAttemptsRef.current >= MAX_POLLING_ATTEMPTS) {
      stopPolling()
      navigate(location.pathname, { replace: true, state: {} })
    }
  }, [shouldPollIntegrations, hasAnyIntegrationCustomer, stopPolling, navigate, location.pathname])

  useNotFoundRedirect({
    error,
    loading,
    redirectTo: CUSTOMERS_LIST_ROUTE,
    translateKey: 'text_17701996981731m5uguxyg8b',
  })

  const actions = useCustomerDetailsHeaderActions({
    customerId: customerId as string,
    customer,
    addCouponDialogRef,
  })

  const entity = useCustomerDetailsHeaderEntity({ customer, loading })

  const tabs = useCustomerDetailsHeaderTabs({
    customerId: customerId as string,
    customer,
    loading,
  })

  const activeTabContent = useMainHeaderTabContent()

  return (
    <div>
      {/* Header */}
      <MainHeader.Configure
        breadcrumb={[
          { label: translate('text_624efab67eb2570101d117a5'), path: CUSTOMERS_LIST_ROUTE },
        ]}
        actions={{ items: actions, loading }}
        entity={entity}
        tabs={tabs}
      />

      {/* Tab content */}
      {activeTabContent && <div className="p-4 md:p-12">{activeTabContent}</div>}

      {/* Error state (non-404) */}
      {!!error && !hasDefinedGQLError('NotFound', error) && (
        <div className="px-4 pb-20 pt-12 md:px-12">
          <GenericPlaceholder
            title={translate('text_6250304370f0f700a8fdc270')}
            subtitle={translate('text_6250304370f0f700a8fdc274')}
            buttonTitle={translate('text_6250304370f0f700a8fdc278')}
            buttonVariant="primary"
            buttonAction={() => window.location.reload()}
            image={<ErrorImage width="136" height="104" />}
          />
        </div>
      )}

      <AddCouponToCustomerDialog ref={addCouponDialogRef} customer={customer} />
    </div>
  )
}

export default CustomerDetails
