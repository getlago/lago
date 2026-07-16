import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import WalletAlertForm from '../WalletAlertForm'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { id: 'org-1', defaultCurrency: 'USD' },
  }),
}))

// Mock AlertThresholds to avoid complex rendering
jest.mock('~/components/alerts/Thresholds', () => ({
  __esModule: true,
  default: () => <div data-test="mock-alert-thresholds" />,
  isThresholdValueValid: () => false,
}))

jest.mock('~/styles/mainObjectsForm', () => ({
  FormLoadingSkeleton: ({ id }: { id: string }) => (
    <div data-test={`form-loading-skeleton-${id}`} />
  ),
}))

const mockUseGetWalletDetailsQuery = jest.fn()
const mockUseGetWalletAlertsQuery = jest.fn()
const mockUseGetWalletAlertToEditQuery = jest.fn()
const mockCreateWalletAlert = jest.fn()
const mockUpdateWalletAlert = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetWalletDetailsQuery: (...args: unknown[]) => mockUseGetWalletDetailsQuery(...args),
  useGetWalletAlertsQuery: (...args: unknown[]) => mockUseGetWalletAlertsQuery(...args),
  useGetWalletAlertToEditQuery: (...args: unknown[]) => mockUseGetWalletAlertToEditQuery(...args),
  useCreateWalletAlertMutation: () => [mockCreateWalletAlert, { error: undefined }],
  useUpdateWalletAlertMutation: () => [mockUpdateWalletAlert, { error: undefined }],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
  hasDefinedGQLError: jest.fn(() => false),
}))

describe('WalletAlertForm', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      walletId: 'wallet-1',
      customerId: 'customer-1',
    })
  })

  describe('GIVEN loading state', () => {
    describe('WHEN queries are loading', () => {
      it('THEN should show loading skeleton', () => {
        mockUseGetWalletDetailsQuery.mockReturnValue({ data: undefined, loading: true })
        mockUseGetWalletAlertsQuery.mockReturnValue({ data: undefined, loading: true })
        mockUseGetWalletAlertToEditQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        render(<WalletAlertForm />)

        expect(screen.getByTestId('form-loading-skeleton-create-wallet-alert')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN create mode', () => {
    describe('WHEN form is loaded', () => {
      it('THEN should render the form without loading skeleton', () => {
        mockUseGetWalletDetailsQuery.mockReturnValue({
          data: { wallet: { id: 'wallet-1', currency: 'USD' } },
          loading: false,
        })
        mockUseGetWalletAlertsQuery.mockReturnValue({
          data: { walletAlerts: { collection: [] } },
          loading: false,
        })
        mockUseGetWalletAlertToEditQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        render(<WalletAlertForm />)

        expect(
          screen.queryByTestId('form-loading-skeleton-create-wallet-alert'),
        ).not.toBeInTheDocument()
      })
    })
  })
})
