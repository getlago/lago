import { act, renderHook } from '@testing-library/react'
import type { Location } from 'react-router-dom'

import { authTokenVar, locationHistoryVar } from '~/core/apolloClient'
import { FeatureFlagEnum } from '~/generated/graphql'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'

const mockNavigate = jest.fn()
const mockHasPermissions = jest.fn()
const mockHasPermissionsOr = jest.fn()
const mockHasFeatureFlag = jest.fn()

const FALLBACK_URL = '/fallback'
const MOCK_HISTORY_VAR = [
  {
    pathname: '/add-ons',
    search: '',
    hash: '',
    state: {
      connectorType: 'source',
      displayConnectionTypeSelector: true,
    },
    key: '8yl13l',
  },
  {
    pathname: '/developers/webhooks',
    search: '',
    hash: '',
    key: 'hq5vj9',
    state: undefined,
  },
  {
    pathname: '/settings',
    search: '',
    hash: '',
    key: '0in8tx',
    state: undefined,
  },
  {
    pathname: '/billable-metrics',
    search: '',
    hash: '',
    key: 'b3ita6',
    state: undefined,
  },
]

jest.mock('react-router-dom', () => {
  const actual = jest.requireActual('react-router-dom')

  return {
    ...actual,
    useNavigate: () => mockNavigate,
    useParams: jest.fn(actual.useParams),
  }
})

const mockUseParams = jest.requireMock('react-router-dom').useParams as jest.Mock

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
    hasPermissionsOr: mockHasPermissionsOr,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasFeatureFlag: mockHasFeatureFlag,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
    loading: false,
    currentUser: {
      id: '1',
      email: 'currentUser@mail.com',
      premium: false,
    },
  }),
}))

describe('useLocationHistory()', () => {
  beforeEach(() => {
    mockNavigate.mockClear()
    mockHasPermissions.mockClear()
    mockHasPermissionsOr.mockClear()
    mockUseParams.mockReturnValue({})
    mockHasFeatureFlag.mockClear()
    authTokenVar(undefined)

    // Default to true for backwards compatibility with existing tests
    mockHasPermissions.mockReturnValue(true)
    mockHasPermissionsOr.mockReturnValue(true)
    mockHasFeatureFlag.mockReturnValue(true)
  })

  describe('onRouteEnter()', () => {
    const mockLocation: Location = {
      pathname: '/customers/123',
      search: '',
      hash: '',
      state: null,
      key: 'test-key',
    }

    describe('when accessing a private route while not authenticated', () => {
      beforeEach(() => {
        authTokenVar(undefined)
      })

      it('should redirect to login storing only the intended destination in router state', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter({ private: true }, mockLocation)
        })

        expect(mockNavigate).toHaveBeenCalledWith('/login', {
          state: {
            from: mockLocation,
          },
          replace: true,
        })
      })

      // Iframe context propagation: Salesforce/Hubspot embed Lago via
      // `?sfdc=true` / `?ifrm=true`. When session expires, the auth guard
      // must carry these flags onto `/login` so `useIframeConfig` (read by
      // Login.tsx) hides Google/Okta — those flows can't complete in an
      // embedded iframe. Without this, the iframe shows the full SSO UI and
      // the user is locked out of the email+password fallback.
      describe('GIVEN the requested URL carries iframe params', () => {
        it('THEN propagates `?sfdc=true` (Salesforce) onto the /login URL', () => {
          const sfdcLocation: Location = {
            pathname: '/customer/abc-123/create/subscription',
            search: '?sfdc=true',
            hash: '',
            state: null,
            key: 'sfdc-key',
          }

          const { result } = renderHook(() => useLocationHistory())

          act(() => {
            result.current.onRouteEnter({ private: true }, sfdcLocation)
          })

          expect(mockNavigate).toHaveBeenCalledWith('/login?sfdc=true', {
            state: { from: sfdcLocation },
            replace: true,
          })
        })

        it('THEN propagates `?ifrm=true` (Hubspot) onto the /login URL', () => {
          const ifrmLocation: Location = {
            pathname: '/customer/abc-123/create-invoice',
            search: '?ifrm=true',
            hash: '',
            state: null,
            key: 'ifrm-key',
          }

          const { result } = renderHook(() => useLocationHistory())

          act(() => {
            result.current.onRouteEnter({ private: true }, ifrmLocation)
          })

          expect(mockNavigate).toHaveBeenCalledWith('/login?ifrm=true', {
            state: { from: ifrmLocation },
            replace: true,
          })
        })

        it('THEN preserves the full search string when other params are present alongside the iframe flag', () => {
          const richLocation: Location = {
            pathname: '/customer/abc-123/create/subscription',
            search: '?sfdc=true&plan=foo',
            hash: '',
            state: null,
            key: 'rich-key',
          }

          const { result } = renderHook(() => useLocationHistory())

          act(() => {
            result.current.onRouteEnter({ private: true }, richLocation)
          })

          expect(mockNavigate).toHaveBeenCalledWith('/login?sfdc=true&plan=foo', {
            state: { from: richLocation },
            replace: true,
          })
        })

        it('THEN does NOT propagate non-iframe search params (avoids leaking unrelated query state to /login)', () => {
          const nonIframeLocation: Location = {
            pathname: '/customers/123',
            search: '?tab=overview&filter=active',
            hash: '',
            state: null,
            key: 'non-iframe-key',
          }

          const { result } = renderHook(() => useLocationHistory())

          act(() => {
            result.current.onRouteEnter({ private: true }, nonIframeLocation)
          })

          expect(mockNavigate).toHaveBeenCalledWith('/login', {
            state: { from: nonIframeLocation },
            replace: true,
          })
        })
      })
    })

    describe('when accessing an onlyPublic route while authenticated', () => {
      beforeEach(() => {
        authTokenVar('test-token')
      })

      it('should redirect to home and preserve router state', () => {
        const locationWithState: Location = {
          ...mockLocation,
          pathname: '/login',
          state: {
            from: { pathname: '/customers/123', search: '', hash: '', state: null, key: 'key' },
          },
        }

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter({ onlyPublic: true }, locationWithState)
        })

        expect(mockNavigate).toHaveBeenCalledWith('/', {
          state: locationWithState.state,
          replace: true,
        })
      })
    })

    describe('permission checking with AND logic (permissions field)', () => {
      beforeEach(() => {
        authTokenVar('test-token')
      })

      it('should allow access when all AND permissions are granted', () => {
        mockHasPermissions.mockReturnValue(true)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['customersView', 'customersUpdate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).toHaveBeenCalledWith(['customersView', 'customersUpdate'])
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })

      it('should deny access when at least one AND permission is missing', () => {
        mockHasPermissions.mockReturnValue(false)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['customersView', 'customersUpdate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).toHaveBeenCalledWith(['customersView', 'customersUpdate'])
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
      })

      it('should allow access when permissions array is empty', () => {
        // Empty array is truthy in JS, so hasPermissions is called with []
        mockHasPermissions.mockReturnValue(true)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: [],
            },
            mockLocation,
          )
        })

        // Empty array still triggers permission check (hasPermissions([]) returns true)
        expect(mockHasPermissions).toHaveBeenCalledWith([])
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })

      it('should allow access when no permissions field is specified', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).not.toHaveBeenCalled()
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })
    })

    describe('permission checking with OR logic (permissionsOr field)', () => {
      beforeEach(() => {
        authTokenVar('test-token')
      })

      it('should allow access when at least one OR permission is granted', () => {
        mockHasPermissionsOr.mockReturnValue(true)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissionsOr: ['customersView', 'customersCreate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissionsOr).toHaveBeenCalledWith(['customersView', 'customersCreate'])
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })

      it('should deny access when no OR permissions are granted', () => {
        mockHasPermissionsOr.mockReturnValue(false)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissionsOr: ['customersView', 'customersCreate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissionsOr).toHaveBeenCalledWith(['customersView', 'customersCreate'])
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
      })

      it('should allow access when all OR permissions are granted', () => {
        mockHasPermissionsOr.mockReturnValue(true)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissionsOr: ['customersView', 'customersCreate', 'customersUpdate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissionsOr).toHaveBeenCalledWith([
          'customersView',
          'customersCreate',
          'customersUpdate',
        ])
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })

      it('should deny access when permissionsOr array is empty', () => {
        // Empty array is truthy in JS, so hasPermissionsOr is called with []
        mockHasPermissionsOr.mockReturnValue(false)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissionsOr: [],
            },
            mockLocation,
          )
        })

        // Empty array triggers permission check (hasPermissionsOr([]) returns false)
        expect(mockHasPermissionsOr).toHaveBeenCalledWith([])
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
      })
    })

    describe('permission checking with combined AND + OR logic', () => {
      beforeEach(() => {
        authTokenVar('test-token')
      })

      it('should allow access when both AND and OR conditions are satisfied', () => {
        mockHasPermissions.mockReturnValue(true) // Has invoicesView
        mockHasPermissionsOr.mockReturnValue(true) // Has at least one of create/update

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['invoicesView'],
              permissionsOr: ['invoicesCreate', 'invoicesUpdate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).toHaveBeenCalledWith(['invoicesView'])
        expect(mockHasPermissionsOr).toHaveBeenCalledWith(['invoicesCreate', 'invoicesUpdate'])
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })

      it('should deny access when AND is satisfied but OR is not', () => {
        mockHasPermissions.mockReturnValue(true) // Has invoicesView
        mockHasPermissionsOr.mockReturnValue(false) // Does not have create/update

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['invoicesView'],
              permissionsOr: ['invoicesCreate', 'invoicesUpdate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).toHaveBeenCalledWith(['invoicesView'])
        expect(mockHasPermissionsOr).toHaveBeenCalledWith(['invoicesCreate', 'invoicesUpdate'])
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
      })

      it('should deny access when OR is satisfied but AND is not', () => {
        mockHasPermissions.mockReturnValue(false) // Does not have invoicesView
        mockHasPermissionsOr.mockReturnValue(true) // Has create/update

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['invoicesView'],
              permissionsOr: ['invoicesCreate', 'invoicesUpdate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).toHaveBeenCalledWith(['invoicesView'])
        // hasPermissionsOr is NOT called due to short-circuit evaluation (AND failed first)
        expect(mockHasPermissionsOr).not.toHaveBeenCalled()
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
      })

      it('should deny access when neither AND nor OR conditions are satisfied', () => {
        mockHasPermissions.mockReturnValue(false)
        mockHasPermissionsOr.mockReturnValue(false)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['invoicesView'],
              permissionsOr: ['invoicesCreate', 'invoicesUpdate'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).toHaveBeenCalledWith(['invoicesView'])
        // hasPermissionsOr is NOT called due to short-circuit evaluation (AND failed first)
        expect(mockHasPermissionsOr).not.toHaveBeenCalled()
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
      })

      it('should handle multiple AND and multiple OR permissions', () => {
        mockHasPermissions.mockReturnValue(true)
        mockHasPermissionsOr.mockReturnValue(true)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['customersView', 'subscriptionsView'],
              permissionsOr: ['customersCreate', 'customersUpdate', 'customersDelete'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).toHaveBeenCalledWith(['customersView', 'subscriptionsView'])
        expect(mockHasPermissionsOr).toHaveBeenCalledWith([
          'customersCreate',
          'customersUpdate',
          'customersDelete',
        ])
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })
    })

    describe('permission checking edge cases', () => {
      beforeEach(() => {
        authTokenVar('test-token')
      })

      it('should not check permissions when user is not authenticated', () => {
        authTokenVar(undefined)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['customersView'],
              permissionsOr: ['customersCreate'],
            },
            mockLocation,
          )
        })

        // Should redirect to login, not check permissions
        expect(mockHasPermissions).not.toHaveBeenCalled()
        expect(mockHasPermissionsOr).not.toHaveBeenCalled()
        expect(mockNavigate).toHaveBeenCalledWith('/login', expect.any(Object))
      })

      it('should not check permissions on public routes', () => {
        authTokenVar(undefined)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              permissions: ['customersView'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).not.toHaveBeenCalled()
        expect(mockHasPermissionsOr).not.toHaveBeenCalled()
        expect(mockNavigate).not.toHaveBeenCalledWith('/forbidden')
      })

      it('should not check permissions on onlyPublic routes', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              onlyPublic: true,
              permissions: ['customersView'],
            },
            mockLocation,
          )
        })

        expect(mockHasPermissions).not.toHaveBeenCalled()
        expect(mockHasPermissionsOr).not.toHaveBeenCalled()
      })
    })

    describe('feature flag gating', () => {
      beforeEach(() => {
        authTokenVar('test-token')
      })

      it('should redirect to home when feature flag is not active', () => {
        mockHasFeatureFlag.mockReturnValue(false)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['quotesView'],
              featureFlag: FeatureFlagEnum.OrderForms,
            },
            mockLocation,
          )
        })

        expect(mockHasFeatureFlag).toHaveBeenCalledWith(FeatureFlagEnum.OrderForms)
        expect(mockNavigate).toHaveBeenCalledWith('/', { replace: true })
      })

      it('should allow access when feature flag is active', () => {
        mockHasFeatureFlag.mockReturnValue(true)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['quotesView'],
              featureFlag: FeatureFlagEnum.OrderForms,
            },
            mockLocation,
          )
        })

        expect(mockHasFeatureFlag).toHaveBeenCalledWith(FeatureFlagEnum.OrderForms)
        expect(mockNavigate).not.toHaveBeenCalledWith('/', { replace: true })
      })

      it('should not check feature flag when no featureFlag field is specified', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['customersView'],
            },
            mockLocation,
          )
        })

        expect(mockHasFeatureFlag).not.toHaveBeenCalled()
      })

      it('should check permissions before feature flag', () => {
        mockHasPermissions.mockReturnValue(false)
        mockHasFeatureFlag.mockReturnValue(false)

        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['quotesView'],
              featureFlag: FeatureFlagEnum.OrderForms,
            },
            mockLocation,
          )
        })

        // Should redirect to forbidden (permission check), not home (feature flag check)
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
        expect(mockNavigate).not.toHaveBeenCalledWith('/', { replace: true })
      })
    })

    describe('location history tracking', () => {
      beforeEach(() => {
        authTokenVar('test-token')
        locationHistoryVar([])
        mockHasPermissions.mockReturnValue(true)
        mockHasPermissionsOr.mockReturnValue(true)
      })

      it('should add location to history when user is authenticated and has permissions', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['customersView'],
            },
            mockLocation,
          )
        })

        expect(locationHistoryVar()).toEqual([mockLocation])
      })

      it('should add location to history when user is authenticated with no permission requirements', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
            },
            mockLocation,
          )
        })

        expect(locationHistoryVar()).toEqual([mockLocation])
      })

      it('should not add location to history when user lacks required permissions', () => {
        mockHasPermissions.mockReturnValue(false)
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              permissions: ['customersView'],
            },
            mockLocation,
          )
        })

        // Should redirect to forbidden and NOT add to history
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden')
        expect(locationHistoryVar()).toEqual([])
      })

      it('should not add layout routes with children to history', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.onRouteEnter(
            {
              private: true,
              children: [{ path: '/child' }],
            },
            mockLocation,
          )
        })

        expect(locationHistoryVar()).toEqual([])
      })
    })
  })

  describe('goBack()', () => {
    describe('when there is no history', () => {
      beforeEach(() => {
        locationHistoryVar([])
      })

      it('should go to the fallback URL if no option', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.goBack(FALLBACK_URL)
        })

        expect(mockNavigate).toHaveBeenCalledWith(FALLBACK_URL)
        expect(locationHistoryVar()).toEqual([])
      })

      it('should go to the fallback URL if previous count is specified', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.goBack(FALLBACK_URL, { previousCount: -3 })
        })

        expect(mockNavigate).toHaveBeenCalledWith(FALLBACK_URL)
        expect(locationHistoryVar()).toEqual([])
      })

      it('should go to the fallback URL even if it is excluded', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => {
          result.current.goBack(FALLBACK_URL, { exclude: FALLBACK_URL })
        })

        expect(mockNavigate).toHaveBeenCalledWith(FALLBACK_URL)
        expect(locationHistoryVar()).toEqual([])
      })
    })

    describe('when there is an history', () => {
      beforeEach(() => {
        locationHistoryVar(MOCK_HISTORY_VAR)
      })

      it('it should redirect to the last visited if no options are specified', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => result.current.goBack(FALLBACK_URL))

        expect(mockNavigate).toHaveBeenCalledWith(MOCK_HISTORY_VAR[1])
        expect(locationHistoryVar()).toEqual(MOCK_HISTORY_VAR.slice(2))
      })

      it('should redirect to the last visited according to the previousCount', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => result.current.goBack(FALLBACK_URL, { previousCount: -2 }))

        expect(mockNavigate).toHaveBeenCalledWith(MOCK_HISTORY_VAR[2])
        expect(locationHistoryVar()).toEqual(MOCK_HISTORY_VAR.slice(3))
      })

      it('should redirect to the last visited that is not excluded', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() => result.current.goBack(FALLBACK_URL, { exclude: MOCK_HISTORY_VAR[1].pathname }))

        expect(mockNavigate).toHaveBeenCalledWith(MOCK_HISTORY_VAR[2])
        expect(locationHistoryVar()).toEqual(MOCK_HISTORY_VAR.slice(3))
      })

      it('should redirect to the last visited when several are excluded', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() =>
          result.current.goBack(FALLBACK_URL, {
            exclude: [MOCK_HISTORY_VAR[1].pathname, MOCK_HISTORY_VAR[2].pathname],
          }),
        )

        expect(mockNavigate).toHaveBeenCalledWith(MOCK_HISTORY_VAR[3])
        expect(locationHistoryVar()).toEqual(MOCK_HISTORY_VAR.slice(4))
      })

      it('should redirect to fallback if all remaining history is excluded', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() =>
          result.current.goBack(FALLBACK_URL, {
            exclude: [
              MOCK_HISTORY_VAR[1].pathname,
              MOCK_HISTORY_VAR[2].pathname,
              MOCK_HISTORY_VAR[3].pathname,
            ],
          }),
        )

        expect(mockNavigate).toHaveBeenCalledWith(FALLBACK_URL)
        expect(locationHistoryVar()).toEqual([])
      })

      it('should redirect to fallback if previousCount excite history length', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() =>
          result.current.goBack(FALLBACK_URL, {
            previousCount: -5,
          }),
        )

        expect(mockNavigate).toHaveBeenCalledWith(FALLBACK_URL)
        expect(locationHistoryVar()).toEqual([])
      })
    })

    describe('GIVEN the user is inside an organization context (slug-aware exclude)', () => {
      const SLUG_HISTORY = [
        { pathname: '/acme/add-ons', search: '', hash: '', state: null, key: 'k1' },
        { pathname: '/acme/settings/taxes', search: '', hash: '', state: null, key: 'k2' },
        { pathname: '/acme/customers', search: '', hash: '', state: null, key: 'k3' },
      ]

      beforeEach(() => {
        mockUseParams.mockReturnValue({ organizationSlug: 'acme' })
        locationHistoryVar(SLUG_HISTORY)
      })

      it('THEN should match slug-unaware exclude patterns against stripped pathnames', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() =>
          result.current.goBack(FALLBACK_URL, {
            exclude: '/settings/taxes',
          }),
        )

        expect(mockNavigate).toHaveBeenCalledWith(SLUG_HISTORY[2])
        expect(locationHistoryVar()).toEqual([])
      })

      it('THEN should fall back when all history entries are excluded (slug prepended to fallback)', () => {
        const { result } = renderHook(() => useLocationHistory())

        act(() =>
          result.current.goBack(FALLBACK_URL, {
            exclude: ['/settings/taxes', '/customers'],
          }),
        )

        // The slug-aware navigate wrapper prepends /acme to the fallback
        expect(mockNavigate).toHaveBeenCalledWith('/acme/fallback')
        expect(locationHistoryVar()).toEqual([])
      })
    })
  })
})
