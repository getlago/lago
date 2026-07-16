import { act, screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { createMockCustomerDetails } from './factories/CustomerDetails.factory'
import { createMockLinkedPaymentProvider } from './factories/LinkedPaymentProvider.factory'

import { CustomerIntegrationRows } from '../CustomerIntegrationRows'

const mockPaymentProvidersData = {
  data: {
    paymentProviders: {
      collection: [{ __typename: 'StripeProvider', id: '1', name: 'Stripe', code: 'stripe' }],
    },
  },
}

const mockIntegrationsData = {
  data: {
    integrations: {
      collection: [
        {
          __typename: 'HubspotIntegration',
          id: 'HubspotIntegration',
          name: 'HubSpot',
          portalId: '12345',
        },
        {
          __typename: 'SalesforceIntegration',
          id: 'SalesforceIntegration',
          name: 'Salesforce',
          instanceId: 'salesforce-instanceId',
        },
        {
          __typename: 'NetsuiteIntegration',
          id: 'NetsuiteIntegration',
          name: 'Netsuite',
          accountId: 'netsuite-123',
        },
        {
          __typename: 'AnrokIntegration',
          id: 'AnrokIntegration',
          name: 'Anrok',
          apiKey: 'anrok-api-key',
          externalAccountId: 'anrok-account-123',
        },
        {
          __typename: 'AvalaraIntegration',
          id: 'AvalaraIntegration',
          name: 'Avalara',
          accountId: 'avalara-123',
        },
        {
          __typename: 'XeroIntegration',
          id: 'XeroIntegration',
          name: 'Xero',
        },
      ],
    },
  },
  loading: false,
}

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  usePaymentProvidersListForCustomerMainInfosQuery: jest.fn(() => mockPaymentProvidersData),
  useIntegrationsListForCustomerMainInfosQuery: jest.fn(() => mockIntegrationsData),
}))

describe('CustomerIntegrationRows', () => {
  it('renders payment providers and integrations', async () => {
    const customer = createMockCustomerDetails()
    const linkedPaymentProvider = createMockLinkedPaymentProvider()

    await act(() =>
      render(
        <CustomerIntegrationRows
          customer={customer}
          linkedPaymentProvider={linkedPaymentProvider}
        />,
      ),
    )

    // Payment Providers
    expect(screen.getByTestId(/Stripe/i)).toBeInTheDocument()

    // Integrations
    expect(screen.getByTestId(/HubspotIntegration/i)).toBeInTheDocument()
    expect(screen.getByTestId(/Salesforce/i)).toBeInTheDocument()
    expect(screen.getByTestId(/Netsuite/i)).toBeInTheDocument()
    expect(screen.getByTestId(/Anrok/i)).toBeInTheDocument()
    expect(screen.getByTestId(/Avalara/i)).toBeInTheDocument()
    expect(screen.getByTestId(/Xero/i)).toBeInTheDocument()
  })

  it('does not render a provider not received from GraphQL', async () => {
    const customer = createMockCustomerDetails()
    const linkedPaymentProvider = createMockLinkedPaymentProvider()

    await act(() =>
      render(
        <CustomerIntegrationRows
          customer={customer}
          linkedPaymentProvider={linkedPaymentProvider}
        />,
      ),
    )

    // Ensure a non-existent provider is not in the document
    expect(screen.queryByTestId(/NonExistentProvider/i)).not.toBeInTheDocument()
  })

  it('navigates to the correct URL when clicking on InlineLink', async () => {
    const customer = createMockCustomerDetails()
    const linkedPaymentProvider = createMockLinkedPaymentProvider()

    await act(() =>
      render(
        <CustomerIntegrationRows
          customer={customer}
          linkedPaymentProvider={linkedPaymentProvider}
        />,
      ),
    )

    const hubspotLink = screen
      .getByTestId(/HubspotIntegration/i)
      .querySelector('[data-test="external-integration-link"]')

    const salesforceLink = screen
      .getByTestId(/SalesforceIntegration/i)
      .querySelector('[data-test="external-integration-link"]')

    const netsuiteLink = screen
      .getByTestId(/NetsuiteIntegration/i)
      .querySelector('[data-test="external-integration-link"]')

    const anrokLink = screen
      .getByTestId(/AnrokIntegration/i)
      .querySelector('[data-test="external-integration-link"]')

    const avalaraLink = screen
      .getByTestId(/AvalaraIntegration/i)
      .querySelector('[data-test="external-integration-link"]')

    const xeroLink = screen
      .getByTestId(/XeroIntegration/i)
      .querySelector('[data-test="external-integration-link"]')

    expect(hubspotLink).toHaveAttribute('href', expect.stringContaining('hubspot.com'))
    expect(salesforceLink).toHaveAttribute('href', expect.stringContaining('salesforce-instanceId'))
    expect(netsuiteLink).toHaveAttribute('href', expect.stringContaining('netsuite.com'))
    expect(anrokLink).toHaveAttribute('href', expect.stringContaining('anrok.com'))
    expect(avalaraLink).toHaveAttribute('href', expect.stringContaining('avalara.com'))
    expect(xeroLink).toHaveAttribute('href', expect.stringContaining('xero.com'))
  })
})
