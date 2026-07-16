import { gql } from '@apollo/client'
import { useParams } from 'react-router-dom'

import { useGetCustomerPortalDataQuery } from '~/generated/graphql'
import { useIsAuthenticated } from '~/hooks/auth/useIsAuthenticated'

gql`
  query getCustomerPortalData {
    customerPortalUser {
      id
      billingConfiguration {
        id
        documentLocale
      }
      billingEntityBillingConfiguration {
        id
        documentLocale
      }
      applicableTimezone
      premium
      customerType
      name
      firstname
      lastname
      legalName
      legalNumber
      taxIdentificationNumber
      email
      addressLine1
      addressLine2
      state
      country
      city
      zipcode
      shippingAddress {
        addressLine1
        addressLine2
        city
        country
        state
        zipcode
      }
      currency
    }
    customerPortalOrganization {
      id
      name
      logoUrl
      premiumIntegrations
    }
  }
`

export const useCustomerPortalData = () => {
  const { token } = useParams()
  const { isPortalAuthenticated } = useIsAuthenticated()

  return useGetCustomerPortalDataQuery({
    fetchPolicy: 'cache-first',
    nextFetchPolicy: 'cache-first',
    skip: !isPortalAuthenticated || !token,
  })
}
