import { renderHook } from '@testing-library/react'

import useCustomerPortalTranslate from '../useCustomerPortalTranslate'

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => ({ token: 'test-token' }),
}))

jest.mock('~/hooks/auth/useIsAuthenticated', () => ({
  useIsAuthenticated: () => ({
    isPortalAuthenticated: true,
  }),
}))

const mockUseGetCustomerPortalDataQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomerPortalDataQuery: (...args: unknown[]) => mockUseGetCustomerPortalDataQuery(...args),
}))

jest.mock('~/hooks/core/useContextualLocale', () => ({
  useContextualLocale: () => ({
    translateWithContextualLocal: jest.fn((key: string) => key),
  }),
}))

describe('useCustomerPortalTranslate', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is used in a portal context', () => {
    describe('WHEN the query is still loading', () => {
      it('THEN should return isUnauthenticated as false', () => {
        mockUseGetCustomerPortalDataQuery.mockReturnValue({
          data: undefined,
          error: undefined,
          loading: true,
        })

        const { result } = renderHook(() => useCustomerPortalTranslate())

        expect(result.current.isUnauthenticated).toBe(false)
        expect(result.current.loading).toBe(true)
      })
    })

    describe('WHEN the query returns a valid user', () => {
      it('THEN should return isUnauthenticated as false', () => {
        mockUseGetCustomerPortalDataQuery.mockReturnValue({
          data: {
            customerPortalUser: {
              id: 'user-1',
              billingConfiguration: { id: 'bc-1', documentLocale: 'en' },
              billingEntityBillingConfiguration: null,
            },
          },
          error: undefined,
          loading: false,
        })

        const { result } = renderHook(() => useCustomerPortalTranslate())

        expect(result.current.isUnauthenticated).toBe(false)
        expect(result.current.loading).toBe(false)
      })
    })

    describe('WHEN the query returns null for customerPortalUser', () => {
      it('THEN should return isUnauthenticated as true', () => {
        mockUseGetCustomerPortalDataQuery.mockReturnValue({
          data: { customerPortalUser: null },
          error: undefined,
          loading: false,
        })

        const { result } = renderHook(() => useCustomerPortalTranslate())

        expect(result.current.isUnauthenticated).toBe(true)
      })
    })

    describe('WHEN the query returns no data at all', () => {
      it('THEN should return isUnauthenticated as false', () => {
        mockUseGetCustomerPortalDataQuery.mockReturnValue({
          data: undefined,
          error: undefined,
          loading: false,
        })

        const { result } = renderHook(() => useCustomerPortalTranslate())

        expect(result.current.isUnauthenticated).toBe(false)
      })
    })

    describe('WHEN the query returns an error', () => {
      it('THEN should return the error', () => {
        const mockError = new Error('Network error')

        mockUseGetCustomerPortalDataQuery.mockReturnValue({
          data: undefined,
          error: mockError,
          loading: false,
        })

        const { result } = renderHook(() => useCustomerPortalTranslate())

        expect(result.current.error).toBe(mockError)
      })
    })
  })
})
