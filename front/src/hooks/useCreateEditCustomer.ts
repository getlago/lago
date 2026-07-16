import { FetchResult, gql } from '@apollo/client'
import { useEffect, useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { addToast, hasDefinedGQLError, PspErrorCode } from '~/core/apolloClient'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import {
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMERS_LIST_ROUTE,
  ERROR_404_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  AddCustomerDrawerFragment,
  CreateCustomerInput,
  CreateCustomerMutation,
  CustomerItemFragmentDoc,
  LagoApiError,
  UpdateCustomerInput,
  UpdateCustomerMutation,
  useCreateCustomerMutation,
  useGetSingleCustomerQuery,
  useUpdateCustomerMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment CustomerForExternalAppsAccordion on Customer {
    id
    customerType
    currency
    paymentProvider
    paymentProviderCode
    # Name in the customer is netsuiteCustomer, but it's used as integrationCustomer in the create update inputs
    netsuiteCustomer {
      __typename
      id
      integrationId
      externalCustomerId
      integrationCode
      integrationType
      subsidiaryId
      syncWithProvider
    }
    anrokCustomer {
      __typename
      id
      integrationId
      externalCustomerId
      integrationCode
      integrationType
      syncWithProvider
    }
    avalaraCustomer {
      __typename
      id
      integrationId
      externalCustomerId
      integrationCode
      integrationType
      syncWithProvider
    }
    xeroCustomer {
      __typename
      id
      integrationId
      externalCustomerId
      integrationCode
      integrationType
      syncWithProvider
    }
    hubspotCustomer {
      __typename
      id
      integrationId
      externalCustomerId
      integrationCode
      integrationType
      syncWithProvider
      targetedObject
    }
    salesforceCustomer {
      __typename
      id
      integrationId
      externalCustomerId
      integrationCode
      integrationType
      syncWithProvider
    }
    providerCustomer {
      id
      providerCustomerId
      syncWithProvider
      providerPaymentMethods
    }
  }

  fragment AddCustomerDrawer on Customer {
    id
    addressLine1
    addressLine2
    applicableTimezone
    canEditAttributes
    city
    country
    currency
    email
    externalId
    externalSalesforceId
    legalName
    legalNumber
    taxIdentificationNumber
    customerType
    name
    firstname
    lastname
    phone
    state
    timezone
    zipcode
    accountType
    shippingAddress {
      addressLine1
      addressLine2
      city
      country
      state
      zipcode
    }
    url
    metadata {
      id
      key
      value
      displayInInvoice
    }
    billingEntity {
      id
      code
      name
      euTaxManagement
    }

    ...CustomerForExternalAppsAccordion
  }

  mutation createCustomer($input: CreateCustomerInput!) {
    createCustomer(input: $input) {
      ...AddCustomerDrawer
      ...CustomerItem
    }
  }

  mutation updateCustomer($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      ...AddCustomerDrawer
      ...CustomerItem
    }
  }

  query GetSingleCustomer($id: ID!) {
    customer(id: $id) {
      id
      ...AddCustomerDrawer
    }
  }

  ${CustomerItemFragmentDoc}
`

type UseCreateEditCustomer = () => {
  isEdition: boolean
  loading: boolean
  customer: AddCustomerDrawerFragment | undefined
  onClose: () => void
  onSave: (
    values: CreateCustomerInput | UpdateCustomerInput,
  ) => Promise<
    | FetchResult<UpdateCustomerMutation, Record<string, unknown>, Record<string, unknown>>
    | FetchResult<CreateCustomerMutation, Record<string, unknown>, Record<string, unknown>>
  >
}

export const useCreateEditCustomer: UseCreateEditCustomer = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { customerId } = useParams<{ customerId: string }>()
  // Track if form has integrations configured (used for polling decision after redirect)
  const hasIntegrationsInFormRef = useRef(false)

  const { data, loading, error } = useGetSingleCustomerQuery({
    variables: {
      id: customerId as string,
    },
    skip: !customerId,
    fetchPolicy: 'network-only',
  })

  const customer = data?.customer

  const goToCustomerInformationPage = (
    _customerId: string,
    options?: { shouldPollIntegrations?: boolean },
  ) =>
    navigate(
      generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
        customerId: _customerId,
        tab: CustomerDetailsTabsOptions.information,
      }),
      { state: { shouldPollIntegrations: options?.shouldPollIntegrations } },
    )

  const [create] = useCreateCustomerMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity, PspErrorCode.ThirdPartyError] },
    onCompleted({ createCustomer }) {
      if (!!createCustomer) {
        addToast({
          message: translate('text_6250304370f0f700a8fdc295'),
          severity: 'success',
        })
        navigate(
          generatePath(CUSTOMER_DETAILS_ROUTE, {
            customerId: createCustomer.id,
          }),
        )
      }
    },
  })

  const [update] = useUpdateCustomerMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity, PspErrorCode.ThirdPartyError] },
    update(cache, { data: updateCustomerData }) {
      if (updateCustomerData?.updateCustomer) {
        // Evict the customer from cache to force a fresh fetch when CustomerDetails remounts
        // This is necessary because the getCustomer query is not active during edit (different route)
        cache.evict({ id: cache.identify(updateCustomerData?.updateCustomer) })
        cache.gc()
      }
    },
    onCompleted({ updateCustomer }) {
      if (!!updateCustomer) {
        addToast({
          message: translate('text_626162c62f790600f850b7da'),
          severity: 'success',
        })

        // Use form data to determine if polling is needed (backend processes integrations async)
        goToCustomerInformationPage(updateCustomer.id, {
          shouldPollIntegrations: hasIntegrationsInFormRef.current,
        })
      }
    },
  })

  useEffect(() => {
    if (hasDefinedGQLError('NotFound', error, 'customer')) {
      navigate(ERROR_404_ROUTE)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  const onSave = async (values: CreateCustomerInput | UpdateCustomerInput) => {
    // Check if form has integrations configured (for polling decision after redirect)
    hasIntegrationsInFormRef.current =
      Array.isArray(values.integrationCustomers) && values.integrationCustomers.length > 0

    if (customer && customerId) {
      return await update({
        variables: {
          input: {
            id: customer?.id as string,
            ...values,
          },
        },
      })
    }

    return await create({
      variables: {
        input: values,
      },
    })
  }

  return {
    loading,
    isEdition: !!customerId,
    customer: customer || undefined,
    onClose: () =>
      customerId ? goToCustomerInformationPage(customerId) : navigate(CUSTOMERS_LIST_ROUTE),
    onSave,
  }
}
