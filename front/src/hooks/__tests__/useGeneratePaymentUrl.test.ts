import { renderHook } from '@testing-library/react'

import { LagoApiError } from '~/generated/graphql'
import { useGeneratePaymentUrl } from '~/hooks/useGeneratePaymentUrl'
import { AllTheProviders } from '~/test-utils'

const mockOpenNewTab = jest.fn()

jest.mock('~/hooks/useDownloadFile', () => ({
  useDownloadFile: () => ({
    openNewTab: mockOpenNewTab,
  }),
}))

const mockGeneratePaymentUrl = jest.fn()

let mutationOptions: {
  context?: { silentErrorCodes?: string[] }
  onCompleted?: (data: { generatePaymentUrl: { paymentUrl: string } | null }) => void
  onError?: (error: { graphQLErrors?: Array<{ extensions?: { code?: string } }> }) => void
} = {}

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGeneratePaymentUrlMutation: (options: typeof mutationOptions) => {
    mutationOptions = options
    return [mockGeneratePaymentUrl]
  },
}))

const mockAddToast = jest.fn()
const mockHasDefinedGQLError = jest.fn()
const mockExtractThirdPartyErrorMessage = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (...args: unknown[]) => mockAddToast(...args),
  hasDefinedGQLError: (...args: unknown[]) => mockHasDefinedGQLError(...args),
  extractThirdPartyErrorMessage: (...args: unknown[]) => mockExtractThirdPartyErrorMessage(...args),
}))

describe('useGeneratePaymentUrl', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockHasDefinedGQLError.mockReturnValue(false)
    mockExtractThirdPartyErrorMessage.mockReturnValue(undefined)
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return a generatePaymentUrl function', () => {
        const { result } = renderHook(() => useGeneratePaymentUrl(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.generatePaymentUrl).toBe('function')
      })

      it('THEN should pass correct silentErrorCodes to mutation context', () => {
        renderHook(() => useGeneratePaymentUrl(), {
          wrapper: customWrapper,
        })

        expect(mutationOptions.context?.silentErrorCodes).toEqual([
          LagoApiError.UnprocessableEntity,
          'third_party_error',
        ])
      })
    })
  })

  describe('GIVEN the mutation completes successfully', () => {
    describe('WHEN a valid paymentUrl is returned', () => {
      it('THEN should call openNewTab with the payment URL', () => {
        renderHook(() => useGeneratePaymentUrl(), {
          wrapper: customWrapper,
        })

        mutationOptions.onCompleted?.({
          generatePaymentUrl: { paymentUrl: 'https://stripe.com/pay/123' },
        })

        expect(mockOpenNewTab).toHaveBeenCalledWith('https://stripe.com/pay/123')
      })
    })

    describe('WHEN paymentUrl is null', () => {
      it('THEN should not call openNewTab', () => {
        renderHook(() => useGeneratePaymentUrl(), {
          wrapper: customWrapper,
        })

        mutationOptions.onCompleted?.({
          generatePaymentUrl: null,
        })

        expect(mockOpenNewTab).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the mutation fails', () => {
    describe('WHEN the error is MissingPaymentProviderCustomer', () => {
      it('THEN should show a danger toast', () => {
        mockHasDefinedGQLError.mockReturnValue(true)

        renderHook(() => useGeneratePaymentUrl(), {
          wrapper: customWrapper,
        })

        const mockError = {
          graphQLErrors: [{ extensions: { code: 'MissingPaymentProviderCustomer' } }],
        }

        mutationOptions.onError?.(mockError)

        expect(mockHasDefinedGQLError).toHaveBeenCalledWith(
          'MissingPaymentProviderCustomer',
          mockError,
        )
        expect(mockAddToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'danger' }))
      })
    })

    describe('WHEN a PSP third-party error message is present', () => {
      it('THEN should show a danger toast with the PSP message', () => {
        const pspMessage = 'Amount must be at least $0.50 usd'

        mockHasDefinedGQLError.mockReturnValue(false)
        mockExtractThirdPartyErrorMessage.mockReturnValue(pspMessage)

        renderHook(() => useGeneratePaymentUrl(), {
          wrapper: customWrapper,
        })

        const mockError = {
          graphQLErrors: [
            {
              extensions: {
                code: 'third_party_error',
                details: { error: pspMessage },
              },
            },
          ],
        }

        mutationOptions.onError?.(mockError)

        expect(mockAddToast).toHaveBeenCalledWith({
          severity: 'danger',
          message: pspMessage,
        })
      })
    })

    describe('WHEN the error is unrecognized', () => {
      it('THEN should not show any toast', () => {
        mockHasDefinedGQLError.mockReturnValue(false)
        mockExtractThirdPartyErrorMessage.mockReturnValue(undefined)

        renderHook(() => useGeneratePaymentUrl(), {
          wrapper: customWrapper,
        })

        mutationOptions.onError?.({
          graphQLErrors: [{ extensions: { code: 'SomeOtherError' } }],
        })

        expect(mockAddToast).not.toHaveBeenCalled()
      })
    })
  })
})
