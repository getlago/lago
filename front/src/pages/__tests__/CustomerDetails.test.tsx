import { act, waitFor } from '@testing-library/react'
// eslint-disable-next-line lago/no-direct-rrd-nav-import
import { useLocation } from 'react-router-dom'

import { initializeYup } from '~/formValidation/initializeYup'
import { render } from '~/test-utils'

import CustomerDetails from '../CustomerDetails'

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: {
    Configure: () => null,
  },
}))

jest.mock('~/components/MainHeader/useMainHeaderTabContent', () => ({
  useMainHeaderTabContent: () => null,
}))

initializeYup()

const mockUseGetCustomerQuery = jest.fn()
const mockAddToast = jest.fn()
const mockHasDefinedGQLError = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (...args: unknown[]) => mockAddToast(...args),
  hasDefinedGQLError: (...args: unknown[]) => mockHasDefinedGQLError(...args),
}))

jest.mock('~/hooks/useIsCustomerReadyForOverduePayment', () => ({
  useIsCustomerReadyForOverduePayment: jest.fn(() => ({
    isCustomerReadyForOverduePayment: true,
    loading: false,
    error: undefined,
  })),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: jest.fn(() => ({
    hasPermissions: jest.fn(() => true),
  })),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: jest.fn(() => ({
    isPremium: true,
  })),
}))

jest.mock('~/hooks/useDownloadFile', () => ({
  useDownloadFile: jest.fn(() => ({
    handleDownloadFile: jest.fn(),
  })),
}))

const mockNavigate = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: jest.fn(() => ({
    customerId: 'test-customer-id',
    tab: 'overview',
  })),
  useNavigate: jest.fn(() => mockNavigate),
  useLocation: jest.fn(() => ({
    pathname: '/customers/test-customer-id/information',
    state: null,
  })),
  generatePath: jest.fn((route: string, params: { customerId: string; tab?: string }) => {
    let result = route.replace(':customerId', params.customerId)

    if (params.tab) {
      result = result.replace(':tab', params.tab)
    }

    return result
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomerQuery: jest.fn(() => mockUseGetCustomerQuery()),
  useGenerateCustomerPortalUrlMutation: jest.fn(() => [
    jest.fn(),
    { loading: false, error: undefined },
  ]),
}))

describe('CustomerDetails', () => {
  const mockStartPolling = jest.fn()
  const mockStopPolling = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()

    mockUseGetCustomerQuery.mockReturnValue({
      data: {
        customer: {
          id: 'test-customer-id',
          displayName: 'Test Customer',
          externalId: 'ext-123',
          hasOverdueInvoices: true,
          hasActiveWallet: false,
          hasCreditNotes: false,
          currency: 'USD',
          applicableTimezone: 'UTC',
          accountType: 'standard',
        },
      },
      loading: false,
      error: undefined,
      startPolling: mockStartPolling,
      stopPolling: mockStopPolling,
    })
  })

  describe('Integration polling', () => {
    it('should start polling when shouldPollIntegrations is true and no integrations exist', async () => {
      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id/information',
        state: { shouldPollIntegrations: true },
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: {
          customer: {
            id: 'test-customer-id',
            displayName: 'Test Customer',
            externalId: 'ext-123',
            hasOverdueInvoices: false,
            hasActiveWallet: false,
            hasCreditNotes: false,
            currency: 'USD',
            applicableTimezone: 'UTC',
            accountType: 'standard',
            netsuiteCustomer: null,
            anrokCustomer: null,
            xeroCustomer: null,
            hubspotCustomer: null,
            salesforceCustomer: null,
          },
        },
        loading: false,
        error: undefined,
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      await waitFor(() => {
        expect(mockStartPolling).toHaveBeenCalledWith(1000)
      })
    })

    it('should not start polling when shouldPollIntegrations is false', async () => {
      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id/information',
        state: { shouldPollIntegrations: false },
        search: '',
        hash: '',
        key: 'default',
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      // Wait a tick to ensure effects have run
      await waitFor(() => {
        expect(mockStartPolling).not.toHaveBeenCalled()
      })
    })

    it('should not start polling when shouldPollIntegrations is not present in state', async () => {
      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id/information',
        state: null,
        search: '',
        hash: '',
        key: 'default',
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      await waitFor(() => {
        expect(mockStartPolling).not.toHaveBeenCalled()
      })
    })

    it('should not start polling when integrations already exist at mount', async () => {
      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id/information',
        state: { shouldPollIntegrations: true },
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: {
          customer: {
            id: 'test-customer-id',
            displayName: 'Test Customer',
            externalId: 'ext-123',
            hasOverdueInvoices: false,
            hasActiveWallet: false,
            hasCreditNotes: false,
            currency: 'USD',
            applicableTimezone: 'UTC',
            accountType: 'standard',
            netsuiteCustomer: { id: 'netsuite-123' },
            anrokCustomer: null,
            xeroCustomer: null,
            hubspotCustomer: null,
            salesforceCustomer: null,
          },
        },
        loading: false,
        error: undefined,
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      // startPolling should NOT be called because integrations already exist
      expect(mockStartPolling).not.toHaveBeenCalled()

      // But stopPolling and navigate should be called to clean up the state
      await waitFor(() => {
        expect(mockStopPolling).toHaveBeenCalled()
      })
    })

    it('should stop polling and clear state when integrations are loaded', async () => {
      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id/information',
        state: { shouldPollIntegrations: true },
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: {
          customer: {
            id: 'test-customer-id',
            displayName: 'Test Customer',
            externalId: 'ext-123',
            hasOverdueInvoices: false,
            hasActiveWallet: false,
            hasCreditNotes: false,
            currency: 'USD',
            applicableTimezone: 'UTC',
            accountType: 'standard',
            netsuiteCustomer: { id: 'netsuite-123' },
            anrokCustomer: null,
            xeroCustomer: null,
            hubspotCustomer: null,
            salesforceCustomer: null,
          },
        },
        loading: false,
        error: undefined,
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      await waitFor(() => {
        expect(mockStopPolling).toHaveBeenCalled()
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith('/customers/test-customer-id/information', {
          replace: true,
          state: {},
        })
      })
    })

    it('should stop polling when any integration customer exists', async () => {
      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id/information',
        state: { shouldPollIntegrations: true },
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: {
          customer: {
            id: 'test-customer-id',
            displayName: 'Test Customer',
            externalId: 'ext-123',
            hasOverdueInvoices: false,
            hasActiveWallet: false,
            hasCreditNotes: false,
            currency: 'USD',
            applicableTimezone: 'UTC',
            accountType: 'standard',
            netsuiteCustomer: null,
            anrokCustomer: null,
            xeroCustomer: { id: 'xero-123' },
            hubspotCustomer: null,
            salesforceCustomer: null,
          },
        },
        loading: false,
        error: undefined,
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      await waitFor(() => {
        expect(mockStopPolling).toHaveBeenCalled()
      })
    })

    it('should call stopPolling on component unmount', async () => {
      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id/information',
        state: { shouldPollIntegrations: true },
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: {
          customer: {
            id: 'test-customer-id',
            displayName: 'Test Customer',
            externalId: 'ext-123',
            hasOverdueInvoices: false,
            hasActiveWallet: false,
            hasCreditNotes: false,
            currency: 'USD',
            applicableTimezone: 'UTC',
            accountType: 'standard',
            netsuiteCustomer: null,
            anrokCustomer: null,
            xeroCustomer: null,
            hubspotCustomer: null,
            salesforceCustomer: null,
          },
        },
        loading: false,
        error: undefined,
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      let unmount: () => void

      await act(async () => {
        const result = render(<CustomerDetails />)

        unmount = result.unmount
      })

      // Wait for effects to run
      await waitFor(() => {
        expect(mockStartPolling).toHaveBeenCalled()
      })

      // Clear mock to isolate unmount behavior
      mockStopPolling.mockClear()

      await act(async () => {
        unmount()
      })

      // stopPolling is called in cleanup
      expect(mockStopPolling).toHaveBeenCalled()
    })
  })

  describe('Customer not found handling', () => {
    it('should redirect to customers list and show toast when customer is not found', async () => {
      mockHasDefinedGQLError.mockReturnValue(true)

      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/non-existent-id',
        state: null,
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: undefined,
        loading: false,
        error: { graphQLErrors: [{ extensions: { code: 'not_found' } }] },
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith('/customers', { replace: true })
      })
    })

    it('should not redirect when customer is found', async () => {
      mockHasDefinedGQLError.mockReturnValue(false)

      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id',
        state: null,
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: {
          customer: {
            id: 'test-customer-id',
            displayName: 'Test Customer',
            externalId: 'ext-123',
            hasOverdueInvoices: false,
            hasActiveWallet: false,
            hasCreditNotes: false,
            currency: 'USD',
            applicableTimezone: 'UTC',
            accountType: 'standard',
          },
        },
        loading: false,
        error: undefined,
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      expect(mockAddToast).not.toHaveBeenCalled()
      expect(mockNavigate).not.toHaveBeenCalledWith('/customers', expect.anything())
    })

    it('should not redirect while loading', async () => {
      mockHasDefinedGQLError.mockReturnValue(true)

      jest.mocked(useLocation).mockReturnValue({
        pathname: '/customers/test-customer-id',
        state: null,
        search: '',
        hash: '',
        key: 'default',
      })

      mockUseGetCustomerQuery.mockReturnValue({
        data: undefined,
        loading: true,
        error: undefined,
        startPolling: mockStartPolling,
        stopPolling: mockStopPolling,
      })

      await act(async () => {
        render(<CustomerDetails />)
      })

      expect(mockAddToast).not.toHaveBeenCalled()
      expect(mockNavigate).not.toHaveBeenCalledWith('/customers', expect.anything())
    })
  })
})
