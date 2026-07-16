import { act, screen, waitFor } from '@testing-library/react'
import { GraphQLError } from 'graphql'

import { MainHeaderProvider } from '~/components/MainHeader/MainHeaderContext'
import { SETTINGS_ROUTE } from '~/core/router'
import { render } from '~/test-utils'

import BillingEntityPage, {
  BILLING_ENTITY_HEADER_TEST_ID,
  BILLING_ENTITY_MAIN_TEST_ID,
} from '../BillingEntity'

const BillingEntityWithProvider = () => (
  <MainHeaderProvider>
    <BillingEntityPage />
  </MainHeaderProvider>
)

const mockNavigate = jest.fn()
const mockUseGetBillingEntityQuery = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: jest.fn(() => ({
    billingEntityCode: 'test-billing-entity',
  })),
  useNavigate: jest.fn(() => mockNavigate),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetBillingEntityQuery: jest.fn(() => mockUseGetBillingEntityQuery()),
}))

const createMockBillingEntity = (overrides = {}) => ({
  id: 'test-id',
  code: 'test-billing-entity',
  name: 'Test Billing Entity',
  addressLine1: '123 Test St',
  addressLine2: null,
  city: 'Test City',
  country: 'US',
  email: 'test@example.com',
  legalName: null,
  legalNumber: null,
  state: null,
  taxIdentificationNumber: null,
  zipcode: '12345',
  logoUrl: null,
  invoiceFooter: null,
  timezone: 'UTC',
  __typename: 'BillingEntity' as const,
  ...overrides,
})

const mockQueryResult = {
  loading: (data?: { billingEntity: ReturnType<typeof createMockBillingEntity> | null }) => ({
    data,
    loading: true,
    error: undefined,
  }),
  success: (
    billingEntity: ReturnType<typeof createMockBillingEntity> | null = createMockBillingEntity(),
  ) => ({
    data: { billingEntity },
    loading: false,
    error: undefined,
  }),
}

describe('BillingEntityPage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      billingEntityCode: 'test-billing-entity',
    })
  })

  describe('loading state', () => {
    it('should hide main content while loading', async () => {
      mockUseGetBillingEntityQuery.mockReturnValue(mockQueryResult.loading())

      await act(async () => {
        return render(<BillingEntityWithProvider />)
      })

      expect(screen.queryByTestId(BILLING_ENTITY_MAIN_TEST_ID)).not.toBeInTheDocument()
      expect(mockNavigate).not.toHaveBeenCalled()
    })
  })

  describe('successful data load', () => {
    it('should render header and main content with billing entity name', async () => {
      mockUseGetBillingEntityQuery.mockReturnValue(mockQueryResult.success())

      await act(async () => {
        return render(<BillingEntityWithProvider />)
      })

      expect(screen.getByTestId(BILLING_ENTITY_HEADER_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(BILLING_ENTITY_MAIN_TEST_ID)).toBeInTheDocument()
      expect(mockNavigate).not.toHaveBeenCalled()
    })
  })

  describe('navigation behavior', () => {
    it.each([
      ['null', null, undefined],
      ['undefined with error', undefined, new GraphQLError('Not found')],
    ])(
      'should navigate to settings route when billing entity is %s',
      async (_, billingEntity, error) => {
        mockUseGetBillingEntityQuery.mockReturnValue({
          data: { billingEntity },
          loading: false,
          error,
        })

        render(<BillingEntityWithProvider />)

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(SETTINGS_ROUTE, { replace: true })
        })
      },
    )

    it('should not navigate when billing entity exists', async () => {
      mockUseGetBillingEntityQuery.mockReturnValue(mockQueryResult.success())

      render(<BillingEntityWithProvider />)

      await waitFor(() => {
        expect(screen.getByTestId(BILLING_ENTITY_MAIN_TEST_ID)).toBeInTheDocument()
      })

      expect(mockNavigate).not.toHaveBeenCalled()
    })

    it('should not navigate while loading', async () => {
      mockUseGetBillingEntityQuery.mockReturnValue(mockQueryResult.loading())

      render(<BillingEntityWithProvider />)

      await waitFor(() => {
        expect(screen.getByTestId(BILLING_ENTITY_HEADER_TEST_ID)).toBeInTheDocument()
      })

      expect(mockNavigate).not.toHaveBeenCalled()
    })
  })

  describe('query behavior', () => {
    it('should render header when billingEntityCode is not in params', () => {
      const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

      useParamsMock.mockReturnValue({
        billingEntityCode: undefined,
      })

      mockUseGetBillingEntityQuery.mockReturnValue(mockQueryResult.success(null))

      render(<BillingEntityWithProvider />)

      expect(screen.getByTestId(BILLING_ENTITY_HEADER_TEST_ID)).toBeInTheDocument()
    })
  })
})
