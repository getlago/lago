import { renderHook, waitFor } from '@testing-library/react'

import { removeItemFromLS, setItemFromLS } from '~/core/utils/localStorage'
import { REDIRECT_AFTER_LOGIN_LS_KEY } from '~/core/utils/localStorageKeys'

// Import after mocks
import GoogleAuthCallback from '../GoogleAuthCallback'

const mockNavigate = jest.fn()
const mockSetItemFromLS = setItemFromLS as jest.Mock
const mockRemoveItemFromLS = removeItemFromLS as jest.Mock
const mockOnLogIn = jest.fn()
const mockGoogleLoginUser = jest.fn()
const mockUseSearchParams = jest.fn()
const mockApolloClient = {}

jest.mock('@apollo/client', () => ({
  ...jest.requireActual('@apollo/client'),
  useApolloClient: () => mockApolloClient,
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  useSearchParams: () => mockUseSearchParams(),
  generatePath: jest.fn((route, params) => {
    return route.replace(':token', params.token)
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  hasDefinedGQLError: jest.fn((code: string, errors: Array<{ extensions?: { code?: string } }>) =>
    errors?.some((e) => e.extensions?.code === code),
  ),
  onLogIn: (...args: unknown[]) => mockOnLogIn(...args),
}))

jest.mock('~/core/utils/localStorage', () => ({
  ...jest.requireActual('~/core/utils/localStorage'),
  setItemFromLS: jest.fn(),
  removeItemFromLS: jest.fn(),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGoogleLoginUserMutation: () => [mockGoogleLoginUser],
}))

const buildSearchParams = (params: Record<string, string>) => {
  const sp = new URLSearchParams()

  Object.entries(params).forEach(([k, v]) => sp.set(k, v))

  return [sp, jest.fn()] as const
}

describe('GoogleAuthCallback', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockOnLogIn.mockResolvedValue(undefined)
  })

  describe('GIVEN a successful Google login with a redirect path', () => {
    const redirectPath = '/customers/123/information'

    beforeEach(() => {
      mockUseSearchParams.mockReturnValue(
        buildSearchParams({
          code: 'google-auth-code',
          state: JSON.stringify({ mode: 'login', redirectPath }),
        }),
      )
      mockGoogleLoginUser.mockResolvedValue({
        data: { googleLoginUser: { token: 'test-token' } },
      })
    })

    describe('WHEN the callback processes', () => {
      it('THEN should store the redirect path in localStorage before onLogIn', async () => {
        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockSetItemFromLS).toHaveBeenCalledWith(REDIRECT_AFTER_LOGIN_LS_KEY, redirectPath)
        })

        // Verify setItemFromLS was called before onLogIn
        const setItemOrder = mockSetItemFromLS.mock.invocationCallOrder[0]
        const onLogInOrder = mockOnLogIn.mock.invocationCallOrder[0]

        expect(setItemOrder).toBeLessThan(onLogInOrder)
      })

      it('THEN should NOT remove redirect path from localStorage (Home.tsx handles cleanup)', async () => {
        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockOnLogIn).toHaveBeenCalled()
        })

        expect(mockRemoveItemFromLS).not.toHaveBeenCalledWith(REDIRECT_AFTER_LOGIN_LS_KEY)
      })

      it('THEN should NOT navigate directly (Home.tsx handles redirect via localStorage bridge)', async () => {
        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockOnLogIn).toHaveBeenCalled()
        })

        expect(mockNavigate).not.toHaveBeenCalledWith({ pathname: redirectPath })
      })
    })
  })

  describe('GIVEN a successful Google login without a redirect path', () => {
    beforeEach(() => {
      mockUseSearchParams.mockReturnValue(
        buildSearchParams({
          code: 'google-auth-code',
          state: JSON.stringify({ mode: 'login' }),
        }),
      )
      mockGoogleLoginUser.mockResolvedValue({
        data: { googleLoginUser: { token: 'test-token' } },
      })
    })

    describe('WHEN the callback processes', () => {
      it('THEN should not store anything in localStorage', async () => {
        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockOnLogIn).toHaveBeenCalled()
        })

        expect(mockSetItemFromLS).not.toHaveBeenCalledWith(
          REDIRECT_AFTER_LOGIN_LS_KEY,
          expect.anything(),
        )
      })

      it('THEN should not navigate to any path', async () => {
        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockOnLogIn).toHaveBeenCalled()
        })

        // Should not navigate to a pathname object (only the !code redirect may fire)
        expect(mockNavigate).not.toHaveBeenCalledWith(
          expect.objectContaining({ pathname: expect.any(String) }),
        )
      })
    })
  })

  describe('GIVEN Google login returns an error', () => {
    beforeEach(() => {
      mockUseSearchParams.mockReturnValue(
        buildSearchParams({
          code: 'google-auth-code',
          state: JSON.stringify({ mode: 'login' }),
        }),
      )
    })

    describe('WHEN LoginMethodNotAuthorized error is returned', () => {
      it('THEN should navigate to login with the error code', async () => {
        mockGoogleLoginUser.mockResolvedValue({
          errors: [{ extensions: { code: 'LoginMethodNotAuthorized' } }],
        })

        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(
            expect.objectContaining({
              pathname: '/login',
              search: expect.stringContaining('lago_error_code'),
            }),
          )
        })
      })
    })

    describe('WHEN a generic error is returned', () => {
      it('THEN should navigate to login with the error details', async () => {
        mockGoogleLoginUser.mockResolvedValue({
          errors: [{ extensions: { code: 'SomeOtherError', details: { base: ['some_error'] } } }],
        })

        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(
            expect.objectContaining({
              pathname: '/login',
              search: expect.stringContaining('lago_error_code'),
            }),
          )
        })
      })
    })
  })

  describe('GIVEN the mode is signup', () => {
    beforeEach(() => {
      mockUseSearchParams.mockReturnValue(
        buildSearchParams({
          code: 'google-auth-code',
          state: JSON.stringify({ mode: 'signup' }),
        }),
      )
    })

    describe('WHEN the callback processes', () => {
      it('THEN should navigate to signup with the code', async () => {
        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(
            expect.objectContaining({
              pathname: '/sign-up',
              search: '?code=google-auth-code',
            }),
          )
        })
      })
    })
  })

  describe('GIVEN the mode is invite', () => {
    beforeEach(() => {
      mockUseSearchParams.mockReturnValue(
        buildSearchParams({
          code: 'google-auth-code',
          state: JSON.stringify({ mode: 'invite', invitationToken: 'inv-token' }),
        }),
      )
    })

    describe('WHEN the callback processes', () => {
      it('THEN should navigate to invitation form with the code', async () => {
        renderHook(() => GoogleAuthCallback())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(
            expect.objectContaining({
              search: '?code=google-auth-code',
            }),
          )
        })
      })
    })
  })
})
