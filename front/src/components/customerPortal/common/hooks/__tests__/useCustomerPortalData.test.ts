import { renderHook } from '@testing-library/react'

import { useCustomerPortalData } from '../useCustomerPortalData'

const mockUseParams = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => mockUseParams(),
}))

const mockUseIsAuthenticated = jest.fn()

jest.mock('~/hooks/auth/useIsAuthenticated', () => ({
  useIsAuthenticated: () => mockUseIsAuthenticated(),
}))

const mockUseGetCustomerPortalDataQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomerPortalDataQuery: (...args: unknown[]) => mockUseGetCustomerPortalDataQuery(...args),
}))

describe('useCustomerPortalData', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseParams.mockReturnValue({ token: 'test-token' })
    mockUseIsAuthenticated.mockReturnValue({ isPortalAuthenticated: true })
    mockUseGetCustomerPortalDataQuery.mockReturnValue({
      data: undefined,
      error: undefined,
      loading: false,
    })
  })

  describe('GIVEN the user is authenticated with a token', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should call the query with cache-first policy and skip=false', () => {
        renderHook(() => useCustomerPortalData())

        expect(mockUseGetCustomerPortalDataQuery).toHaveBeenCalledWith({
          fetchPolicy: 'cache-first',
          nextFetchPolicy: 'cache-first',
          skip: false,
        })
      })
    })

    describe('WHEN the query is loading', () => {
      it('THEN should return loading state', () => {
        mockUseGetCustomerPortalDataQuery.mockReturnValue({
          data: undefined,
          error: undefined,
          loading: true,
        })

        const { result } = renderHook(() => useCustomerPortalData())

        expect(result.current.loading).toBe(true)
        expect(result.current.data).toBeUndefined()
      })
    })

    describe('WHEN the query returns data', () => {
      it('THEN should return both user and organization data', () => {
        const mockData = {
          customerPortalUser: {
            id: 'user-1',
            name: 'Test User',
            currency: 'USD',
            premium: true,
            applicableTimezone: 'UTC',
          },
          customerPortalOrganization: {
            id: 'org-1',
            name: 'Test Org',
            logoUrl: 'https://example.com/logo.png',
            premiumIntegrations: [],
          },
        }

        mockUseGetCustomerPortalDataQuery.mockReturnValue({
          data: mockData,
          error: undefined,
          loading: false,
        })

        const { result } = renderHook(() => useCustomerPortalData())

        expect(result.current.data).toEqual(mockData)
        expect(result.current.loading).toBe(false)
        expect(result.current.error).toBeUndefined()
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

        const { result } = renderHook(() => useCustomerPortalData())

        expect(result.current.error).toBe(mockError)
      })
    })
  })

  describe('GIVEN the user is not authenticated', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should skip the query', () => {
        mockUseIsAuthenticated.mockReturnValue({ isPortalAuthenticated: false })

        renderHook(() => useCustomerPortalData())

        expect(mockUseGetCustomerPortalDataQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
      })
    })
  })

  describe('GIVEN there is no token', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should skip the query', () => {
        mockUseParams.mockReturnValue({ token: undefined })

        renderHook(() => useCustomerPortalData())

        expect(mockUseGetCustomerPortalDataQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
      })
    })
  })

  describe('GIVEN there is no token and user is not authenticated', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should skip the query', () => {
        mockUseParams.mockReturnValue({ token: undefined })
        mockUseIsAuthenticated.mockReturnValue({ isPortalAuthenticated: false })

        renderHook(() => useCustomerPortalData())

        expect(mockUseGetCustomerPortalDataQuery).toHaveBeenCalledWith(
          expect.objectContaining({ skip: true }),
        )
      })
    })
  })
})
