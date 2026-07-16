import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { AllTheProviders, testMockNavigateFn } from '~/test-utils'

import { useApproveQuote } from '../useApproveQuote'

const mockApproveQuoteMutation = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useApproveQuoteVersionMutation: () => [mockApproveQuoteMutation],
}))

const wrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders>{children}</AllTheProviders>
)

describe('useApproveQuote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return goToApproveQuote and approveQuote functions', () => {
        const { result } = renderHook(() => useApproveQuote(), { wrapper })

        expect(typeof result.current.goToApproveQuote).toBe('function')
        expect(typeof result.current.approveQuote).toBe('function')
      })
    })
  })

  describe('GIVEN goToApproveQuote is called', () => {
    it.each([
      ['quote-123', 'version-1', '/quote/quote-123/version/version-1/approve'],
      ['quote-456', 'version-2', '/quote/quote-456/version/version-2/approve'],
    ])(
      'WHEN called with %s and %s THEN should navigate to %s',
      (quoteId, versionId, expectedPath) => {
        const { result } = renderHook(() => useApproveQuote(), { wrapper })

        act(() => {
          result.current.goToApproveQuote(quoteId, versionId)
        })

        expect(testMockNavigateFn).toHaveBeenCalledWith(expectedPath)
      },
    )
  })

  describe('GIVEN approveQuote is called', () => {
    describe('WHEN invoked with variables', () => {
      it('THEN should call the mutation with correct input', async () => {
        mockApproveQuoteMutation.mockResolvedValueOnce({
          data: { approveQuoteVersion: { id: 'version-1', status: 'approved' } },
        })

        const { result } = renderHook(() => useApproveQuote(), { wrapper })

        await act(async () => {
          await result.current.approveQuote({
            variables: { input: { id: 'version-1' } },
          })
        })

        expect(mockApproveQuoteMutation).toHaveBeenCalledWith({
          variables: { input: { id: 'version-1' } },
        })
      })
    })
  })
})
