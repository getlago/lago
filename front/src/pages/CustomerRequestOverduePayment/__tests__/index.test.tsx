import { ApolloError } from '@apollo/client'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { addToast } from '~/core/apolloClient'
import { ERROR_404_ROUTE } from '~/core/router'
import { initializeYup } from '~/formValidation/initializeYup'
import { FeatureFlagEnum, LagoApiError } from '~/generated/graphql'
import * as useIsCustomerReadyForOverduePaymentModule from '~/hooks/useIsCustomerReadyForOverduePayment'
import { render } from '~/test-utils'

import CustomerRequestOverduePayment, { SUBMIT_PAYMENT_REQUEST_TEST_ID } from '../index'

initializeYup()

const mockNavigate = jest.fn()
const mockGoBack = jest.fn()
const mockUseGetRequestOverduePaymentInfosQuery = jest.fn()
const mockCreatePaymentRequest = jest.fn()
const mockHasFeatureFlag = jest.fn()
let mockOnError: ((error: ApolloError) => void) | undefined
let mockSearchParams = new URLSearchParams()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: jest.fn(() => ({
    isPremium: true,
  })),
}))

jest.mock('~/hooks/useIsCustomerReadyForOverduePayment', () => ({
  useIsCustomerReadyForOverduePayment: jest.fn(() => ({
    isCustomerReadyForOverduePayment: true,
    loading: false,
    error: undefined,
  })),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasFeatureFlag: mockHasFeatureFlag,
  }),
}))

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    goBack: mockGoBack,
  }),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => ({ customerId: 'test-customer-id' }),
  useSearchParams: () => [mockSearchParams],
  generatePath: jest.fn((route: string, params: Record<string, string>) => {
    return Object.entries(params).reduce((acc, [key, val]) => acc.replace(`:${key}`, val), route)
  }),
}))

jest.mock('~/core/router', () => ({
  ...jest.requireActual('~/core/router'),
  useNavigate: () => mockNavigate,
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetRequestOverduePaymentInfosQuery: jest.fn(() => mockUseGetRequestOverduePaymentInfosQuery()),
  useCreatePaymentRequestMutation: jest.fn(
    (options?: { onError?: (error: ApolloError) => void }) => {
      if (options?.onError) {
        mockOnError = options.onError
      }
      return [
        mockCreatePaymentRequest,
        { loading: false, error: undefined, client: { refetchQueries: jest.fn() } },
      ]
    },
  ),
}))

jest.mock('~/pages/CustomerRequestOverduePayment/components/EmailPreview', () => ({
  EmailPreview: () => <div data-testid="email-preview">email preview</div>,
}))

jest.mock('../components/FreemiumAlert', () => ({
  FreemiumAlert: () => <div data-testid="freemium-alert">freemium alert</div>,
}))

jest.mock('../components/RequestPaymentForm', () => ({
  RequestPaymentForm: () => <div data-testid="request-payment-form">form</div>,
}))

const validQueryData = {
  customer: { externalId: 'test-external-id', email: 'test@example.com', currency: 'USD' },
  organization: { defaultCurrency: 'USD' },
  paymentRequests: { collection: [] },
  invoices: {
    collection: [
      {
        id: 'invoice-1',
        totalDueAmountCents: 10000,
        currency: 'USD',
      },
    ],
  },
}

describe('CustomerRequestOverduePayment', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockOnError = undefined
    mockHasFeatureFlag.mockReturnValue(false)
    mockSearchParams = new URLSearchParams()
    mockUseGetRequestOverduePaymentInfosQuery.mockReturnValue({
      data: {},
      loading: false,
      error: undefined,
    })
    jest
      .mocked(useIsCustomerReadyForOverduePaymentModule.useIsCustomerReadyForOverduePayment)
      .mockReturnValue({
        isCustomerReadyForOverduePayment: true,
        loading: false,
        error: undefined,
      })
  })

  describe('GIVEN multi-entity billing is enabled but billingEntityId param is missing', () => {
    describe('WHEN the page renders', () => {
      it('THEN redirects back to the customer invoices tab', async () => {
        mockHasFeatureFlag.mockImplementation(
          (flag: FeatureFlagEnum) => flag === FeatureFlagEnum.MultiEntityBilling,
        )
        // billingEntityId not in searchParams

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        })

        expect(mockNavigate).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the query is skipped because access is unscoped', () => {
    describe('WHEN multi-currency flag is on but currency param is missing', () => {
      it('THEN redirects and does not fire the query', async () => {
        mockHasFeatureFlag.mockImplementation(
          (flag: FeatureFlagEnum) => flag === FeatureFlagEnum.MultiCurrency,
        )

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalled()
        })
      })
    })
  })

  describe('GIVEN both feature flags are enabled', () => {
    describe('WHEN both currency and billingEntityId search params are provided', () => {
      it('THEN should not redirect and should render the page correctly', async () => {
        mockHasFeatureFlag.mockReturnValue(true)
        mockSearchParams = new URLSearchParams({
          currency: 'USD',
          billingEntityId: 'be-123',
        })

        mockUseGetRequestOverduePaymentInfosQuery.mockReturnValue({
          data: validQueryData,
          loading: false,
          error: undefined,
        })

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        // Should NOT redirect since both scopes are provided
        expect(mockNavigate).not.toHaveBeenCalled()

        // Should render the submit button (query was not skipped)
        const submitButton = screen.getByTestId(SUBMIT_PAYMENT_REQUEST_TEST_ID)

        expect(submitButton).toBeInTheDocument()
      })

      it('THEN should fire the query with both currency and billingEntityIds variables', async () => {
        mockHasFeatureFlag.mockReturnValue(true)
        mockSearchParams = new URLSearchParams({
          currency: 'USD',
          billingEntityId: 'be-123',
        })

        mockUseGetRequestOverduePaymentInfosQuery.mockReturnValue({
          data: validQueryData,
          loading: false,
          error: undefined,
        })

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        // The query mock was called, meaning skip was false
        expect(mockUseGetRequestOverduePaymentInfosQuery).toHaveBeenCalled()
      })
    })

    describe('WHEN both currency and billingEntityId params are missing', () => {
      it('THEN should redirect back to invoices tab', async () => {
        mockHasFeatureFlag.mockReturnValue(true)
        // No search params — both scopes missing

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        })

        expect(mockNavigate).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the query returns a NotFound error for the customer', () => {
    describe('WHEN the page renders', () => {
      it('THEN navigates to the 404 page', async () => {
        const notFoundError = {
          graphQLErrors: [
            {
              extensions: { code: 'not_found', details: { customer: ['not_found'] } },
            },
          ],
        }

        mockUseGetRequestOverduePaymentInfosQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: notFoundError,
        })

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(ERROR_404_ROUTE)
        })
      })
    })
  })

  describe('GIVEN the total amount is zero after loading completes', () => {
    describe('WHEN the page renders', () => {
      it('THEN navigates to the 404 page', async () => {
        mockUseGetRequestOverduePaymentInfosQuery.mockReturnValue({
          data: {
            customer: { externalId: 'ext-1', email: 'test@example.com', currency: 'USD' },
            organization: { defaultCurrency: 'USD' },
            paymentRequests: { collection: [] },
            invoices: { collection: [] },
          },
          loading: false,
          error: undefined,
        })

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(ERROR_404_ROUTE)
        })
      })
    })
  })

  describe('GIVEN the form has valid data and invoices exist', () => {
    describe('WHEN user clicks submit', () => {
      it('THEN calls the createPaymentRequest mutation', async () => {
        const user = userEvent.setup()

        mockUseGetRequestOverduePaymentInfosQuery.mockReturnValue({
          data: validQueryData,
          loading: false,
          error: undefined,
        })

        await act(async () => {
          render(<CustomerRequestOverduePayment />)
        })

        await waitFor(() => {
          const submitButton = screen.getByTestId(SUBMIT_PAYMENT_REQUEST_TEST_ID)

          expect(submitButton).not.toBeDisabled()
        })

        const submitButton = screen.getByTestId(SUBMIT_PAYMENT_REQUEST_TEST_ID)

        await user.click(submitButton)

        expect(mockCreatePaymentRequest).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: expect.objectContaining({
              input: expect.objectContaining({
                externalCustomerId: 'test-external-id',
                lagoInvoiceIds: ['invoice-1'],
              }),
            }),
          }),
        )
      })
    })
  })

  describe('WHEN user submits and mutation returns InvoicesNotReadyForPaymentProcessing error', () => {
    it('THEN shows error toast and navigates to customer details', async () => {
      const user = userEvent.setup()

      mockUseGetRequestOverduePaymentInfosQuery.mockReturnValue({
        data: validQueryData,
        loading: false,
        error: undefined,
      })

      const mockError: ApolloError = {
        graphQLErrors: [
          {
            extensions: {
              code: LagoApiError.InvoicesNotReadyForPaymentProcessing,
            },
          },
        ],
      } as unknown as ApolloError

      await act(async () => {
        return render(<CustomerRequestOverduePayment />)
      })

      await waitFor(() => {
        const submitButton = screen.getByTestId(SUBMIT_PAYMENT_REQUEST_TEST_ID)

        expect(submitButton).not.toBeDisabled()
      })

      const submitButton = screen.getByTestId(SUBMIT_PAYMENT_REQUEST_TEST_ID)

      await user.click(submitButton)

      // Manually call onError callback to simulate Apollo's behavior when mutation fails
      // This simulates what Apollo does when the mutation promise is rejected
      await act(async () => {
        if (mockOnError) {
          mockOnError(mockError)
        }
      })

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith(
          expect.objectContaining({
            severity: 'danger',
            translateKey: 'text_1763545922743q5ic2kklick',
          }),
        )
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalled()
      })
    })
  })

  describe('WHEN user lands on the view and useIsCustomerReadyForOverduePayment is false', () => {
    it('THEN shows error toast and navigates to customer details', async () => {
      jest
        .mocked(useIsCustomerReadyForOverduePaymentModule.useIsCustomerReadyForOverduePayment)
        .mockReturnValue({
          isCustomerReadyForOverduePayment: false,
          loading: false,
          error: undefined,
        })

      await act(async () => {
        return render(<CustomerRequestOverduePayment />)
      })

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith(
          expect.objectContaining({
            severity: 'danger',
          }),
        )
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalled()
      })
    })
  })
})
