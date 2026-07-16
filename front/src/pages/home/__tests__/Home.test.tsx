import { renderHook, waitFor } from '@testing-library/react'
import type { Location } from 'react-router-dom'

import { getItemFromLS, removeItemFromLS } from '~/core/utils/localStorage'
import { REDIRECT_AFTER_LOGIN_LS_KEY } from '~/core/utils/localStorageKeys'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'

// Import Home component after all mocks are set up

import Home from '../Home'

const mockNavigate = jest.fn()
const mockUseLocation = jest.fn()
const mockGetItemFromLS = getItemFromLS as jest.Mock
const mockRemoveItemFromLS = removeItemFromLS as jest.Mock
const mockGetCurrentOrganizationId = jest.fn()
const mockHasPermissions = jest.fn()
const mockFindFirstViewPermission = jest.fn()
const mockHasOrganizationPremiumAddon = jest.fn()
const mockGetRouteForPermission = jest.fn()
const mockUseCurrentUser = jest.fn()
const mockUseOrganizationInfos = jest.fn()

const TEST_ORG_SLUG = 'test-org'
const TEST_ORG_ID = 'org-a'

const defaultMemberships = [
  {
    id: 'membership-1',
    organization: { id: TEST_ORG_ID, name: 'Test Org', slug: TEST_ORG_SLUG },
  },
]

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  useLocation: () => mockUseLocation(),
  generatePath: jest.fn((route, params) => {
    return route.replace(':tab', params.tab)
  }),
}))

jest.mock('~/core/utils/localStorage', () => ({
  ...jest.requireActual('~/core/utils/localStorage'),
  getItemFromLS: jest.fn(),
  removeItemFromLS: jest.fn(),
}))

jest.mock('~/core/apolloClient/reactiveVars', () => ({
  ...jest.requireActual('~/core/apolloClient/reactiveVars'),
  getCurrentOrganizationId: () => mockGetCurrentOrganizationId(),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockUseCurrentUser(),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => mockUseOrganizationInfos(),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
    findFirstViewPermission: mockFindFirstViewPermission,
  }),
}))

jest.mock('~/core/router/utils/permissionRouteMap', () => ({
  getRouteForPermission: (permission: string | null) => mockGetRouteForPermission(permission),
}))

jest.mock('~/core/router/legacyPaths', () => ({
  LEGACY_APP_PATH_SEGMENTS: new Set([
    'analytics',
    'customers',
    'plans',
    'invoices',
    'settings',
    'billable-metrics',
    'coupons',
    'add-ons',
    'payments',
    'credit-notes',
    'subscriptions',
    'features',
  ]),
}))

describe('Home', () => {
  beforeEach(() => {
    mockNavigate.mockClear()
    mockGetItemFromLS.mockClear()
    mockRemoveItemFromLS.mockClear()
    mockGetCurrentOrganizationId.mockClear()
    mockHasPermissions.mockClear()
    mockFindFirstViewPermission.mockClear()
    mockHasOrganizationPremiumAddon.mockClear()
    mockGetRouteForPermission.mockClear()
    mockUseCurrentUser.mockClear()
    mockUseOrganizationInfos.mockClear()
    mockUseLocation.mockReturnValue({ state: null })

    // Default: reactive var returns the test org ID
    mockGetCurrentOrganizationId.mockReturnValue(TEST_ORG_ID)

    // Default mock values for a logged-in user with slug
    mockUseCurrentUser.mockReturnValue({
      loading: false,
      currentUser: { memberships: defaultMemberships },
      currentMembership: defaultMemberships[0],
    })
    mockUseOrganizationInfos.mockReturnValue({
      loading: false,
      hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
    })
  })

  describe('redirect from login with saved location', () => {
    const savedLocationWithSlug: Location = {
      pathname: `/${TEST_ORG_SLUG}/customers/123`,
      search: '?tab=overview',
      hash: '',
      state: null,
      key: 'saved-key',
    }

    const savedLocationLegacy: Location = {
      pathname: '/customers/123',
      search: '?tab=overview',
      hash: '',
      state: null,
      key: 'saved-key',
    }

    it('should redirect to saved location when slug belongs to user', async () => {
      mockUseLocation.mockReturnValue({
        state: {
          from: savedLocationWithSlug,
          orgId: TEST_ORG_ID,
        },
      })

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(savedLocationWithSlug, { replace: true })
      })
    })

    it('should prepend slug to legacy saved location and preserve search + hash', async () => {
      mockUseLocation.mockReturnValue({
        state: {
          from: savedLocationLegacy,
          orgId: null,
        },
      })

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/customers/123?tab=overview`, {
          replace: true,
        })
      })
    })

    it('should prepend slug to legacy saved location for multi-membership users (universal recovery)', async () => {
      mockUseCurrentUser.mockReturnValue({
        loading: false,
        currentUser: {
          memberships: [
            ...defaultMemberships,
            {
              id: 'membership-2',
              organization: { id: 'org-b', name: 'Other Org', slug: 'other-org' },
            },
          ],
        },
        currentMembership: defaultMemberships[0],
      })
      mockUseLocation.mockReturnValue({
        state: {
          from: savedLocationLegacy,
          orgId: null,
        },
      })
      mockHasPermissions.mockImplementation((perms: string[]) => perms.includes('customersView'))
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      renderHook(() => Home())

      await waitFor(() => {
        // Multi-org user: now also lands on the original intended path
        // (the legacy gate that previously fell through to default has
        // been removed — see `OrganizationLayout` universal auto-recovery).
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/customers/123?tab=overview`, {
          replace: true,
        })
      })
    })

    it('should fall through to default when saved slug belongs to unknown org', async () => {
      const unknownSlugLocation: Location = {
        pathname: '/unknown-org/customers/123',
        search: '',
        hash: '',
        state: null,
        key: 'saved-key',
      }

      mockUseLocation.mockReturnValue({
        state: {
          from: unknownSlugLocation,
          orgId: 'org-a',
        },
      })
      mockHasPermissions.mockImplementation((perms: string[]) => {
        return perms.includes('customersView')
      })
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/customers`, { replace: true })
      })
    })

    it('should ignore saved location with root pathname', async () => {
      const rootLocation = { ...savedLocationWithSlug, pathname: '/' }

      mockUseLocation.mockReturnValue({
        state: {
          from: rootLocation,
          orgId: TEST_ORG_ID,
        },
      })
      mockHasPermissions.mockImplementation((perms: string[]) => {
        return perms.includes('customersView')
      })
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/customers`, { replace: true })
        expect(mockNavigate).not.toHaveBeenCalledWith(rootLocation, { replace: true })
      })
    })
  })

  describe('GIVEN a redirect path is stored in localStorage from SSO login', () => {
    const ssoRedirectPath = '/customers/123/information'

    beforeEach(() => {
      mockUseLocation.mockReturnValue({ state: null })
      mockGetItemFromLS.mockImplementation((key: string) => {
        if (key === REDIRECT_AFTER_LOGIN_LS_KEY) return ssoRedirectPath

        return undefined
      })
    })

    describe('WHEN the component renders after SSO login', () => {
      it('THEN should navigate to the stored redirect path with slug prepended', async () => {
        renderHook(() => Home())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}${ssoRedirectPath}`, {
            replace: true,
          })
        })
      })

      it('THEN should remove the redirect path from localStorage', async () => {
        renderHook(() => Home())

        await waitFor(() => {
          expect(mockRemoveItemFromLS).toHaveBeenCalledWith(REDIRECT_AFTER_LOGIN_LS_KEY)
        })
      })

      it('THEN should NOT double-prepend slug if path already has it', async () => {
        const pathWithSlug = `/${TEST_ORG_SLUG}/customers/123/information`

        mockGetItemFromLS.mockImplementation((key: string) => {
          if (key === REDIRECT_AFTER_LOGIN_LS_KEY) return pathWithSlug

          return undefined
        })

        renderHook(() => Home())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(pathWithSlug, { replace: true })
        })
      })
    })

    describe('WHEN there is also a saved location in router state', () => {
      it('THEN should prioritize the localStorage redirect over router state', async () => {
        const savedLocation: Location = {
          pathname: '/different-page',
          search: '',
          hash: '',
          state: null,
          key: 'saved-key',
        }

        mockUseLocation.mockReturnValue({
          state: { from: savedLocation, orgId: null },
        })

        renderHook(() => Home())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}${ssoRedirectPath}`, {
            replace: true,
          })
          expect(mockNavigate).not.toHaveBeenCalledWith(savedLocation, { replace: true })
        })
      })
    })

    describe('WHEN deps change after the SSO redirect has fired (race condition)', () => {
      it('THEN should NOT issue a second navigate to the default permission-based route', async () => {
        // First render: SSO LS present, default perms also satisfy analytics
        mockHasPermissions.mockReturnValue(true)
        mockHasOrganizationPremiumAddon.mockReturnValue(false)

        const { rerender } = renderHook(() => Home())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}${ssoRedirectPath}`, {
            replace: true,
          })
        })

        mockGetItemFromLS.mockReturnValue(undefined)
        mockHasOrganizationPremiumAddon.mockReturnValue(true)

        rerender()

        // Wait a tick to give the effect a chance to re-fire
        await new Promise((resolve) => setTimeout(resolve, 50))

        // Only the SSO navigate should have fired — no analytics fallback.
        expect(mockNavigate).toHaveBeenCalledTimes(1)
        expect(mockNavigate).not.toHaveBeenCalledWith(
          `/${TEST_ORG_SLUG}/analytics/revenueStreams`,
          { replace: true },
        )
      })
    })
  })

  describe('GIVEN no redirect path is stored in localStorage', () => {
    beforeEach(() => {
      mockUseLocation.mockReturnValue({ state: null })
      mockGetItemFromLS.mockReturnValue(undefined)
    })

    describe('WHEN the component renders', () => {
      it('THEN should not call removeItemFromLS for redirect key', async () => {
        mockHasPermissions.mockReturnValue(true)
        mockHasOrganizationPremiumAddon.mockReturnValue(false)

        renderHook(() => Home())

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalled()
        })

        expect(mockRemoveItemFromLS).not.toHaveBeenCalledWith(REDIRECT_AFTER_LOGIN_LS_KEY)
      })
    })
  })

  describe('default navigation', () => {
    beforeEach(() => {
      mockUseLocation.mockReturnValue({ state: null })
    })

    it('should redirect to analytics when user has analyticsView and no dashboard feature', async () => {
      mockHasPermissions.mockReturnValue(true)
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/analytics`, { replace: true })
      })
    })

    it('should redirect to analytics dashboards when user has dataApiView and dashboard feature', async () => {
      mockHasPermissions.mockImplementation((perms: string[]) => {
        return perms.includes('dataApiView')
      })
      mockHasOrganizationPremiumAddon.mockImplementation((addon: PremiumIntegrationTypeEnum) => {
        return addon === PremiumIntegrationTypeEnum.AnalyticsDashboards
      })

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/analytics/revenue-streams`, {
          replace: true,
        })
      })
    })

    it('should redirect to customers list when user has customersView but no analytics permissions', async () => {
      mockHasPermissions.mockImplementation((perms: string[]) => {
        return perms.includes('customersView')
      })
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/customers`, { replace: true })
      })
    })

    it('should use findFirstViewPermission when user has no customersView', async () => {
      mockHasPermissions.mockReturnValue(false)
      mockHasOrganizationPremiumAddon.mockReturnValue(false)
      mockFindFirstViewPermission.mockReturnValue('plansView')
      mockGetRouteForPermission.mockReturnValue('plans')

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockFindFirstViewPermission).toHaveBeenCalled()
        expect(mockGetRouteForPermission).toHaveBeenCalledWith('plansView')
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/plans`, { replace: true })
      })
    })

    it('should redirect to forbidden route when no accessible routes exist', async () => {
      mockHasPermissions.mockReturnValue(false)
      mockHasOrganizationPremiumAddon.mockReturnValue(false)
      mockFindFirstViewPermission.mockReturnValue(null)
      mockGetRouteForPermission.mockReturnValue(null)

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden', { replace: true })
      })
    })

    it('should redirect to forbidden when permission has no associated route', async () => {
      mockHasPermissions.mockReturnValue(false)
      mockHasOrganizationPremiumAddon.mockReturnValue(false)
      mockFindFirstViewPermission.mockReturnValue('auditLogsView')
      mockGetRouteForPermission.mockReturnValue(null)

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockGetRouteForPermission).toHaveBeenCalledWith('auditLogsView')
        expect(mockNavigate).toHaveBeenCalledWith('/forbidden', { replace: true })
      })
    })
  })

  describe('loading states', () => {
    it('should not navigate when user is loading', async () => {
      mockUseCurrentUser.mockReturnValue({
        loading: true,
        currentMembership: null,
      })

      renderHook(() => Home())

      // Wait a bit to ensure no navigation happens
      await new Promise((resolve) => setTimeout(resolve, 100))

      expect(mockNavigate).not.toHaveBeenCalled()
    })

    it('should not navigate when organization is loading', async () => {
      mockUseOrganizationInfos.mockReturnValue({
        loading: true,
        hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
      })

      renderHook(() => Home())

      // Wait a bit to ensure no navigation happens
      await new Promise((resolve) => setTimeout(resolve, 100))

      expect(mockNavigate).not.toHaveBeenCalled()
    })

    it('should not navigate when currentMembership is null', async () => {
      mockUseCurrentUser.mockReturnValue({
        loading: false,
        currentMembership: null,
      })

      renderHook(() => Home())

      // Wait a bit to ensure no navigation happens
      await new Promise((resolve) => setTimeout(resolve, 100))

      expect(mockNavigate).not.toHaveBeenCalled()
    })

    it('should navigate only after all loading completes and membership exists', async () => {
      mockHasPermissions.mockImplementation((perms: string[]) => {
        return perms.includes('customersView')
      })
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      // Initially loading
      mockUseCurrentUser.mockReturnValue({
        loading: true,
        currentMembership: null,
      })

      const { rerender } = renderHook(() => Home())

      // Wait a bit to ensure no navigation happens during loading
      await new Promise((resolve) => setTimeout(resolve, 50))
      expect(mockNavigate).not.toHaveBeenCalled()

      // Now loaded
      mockUseCurrentUser.mockReturnValue({
        loading: false,
        currentUser: { memberships: defaultMemberships },
        currentMembership: defaultMemberships[0],
      })

      rerender()

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/customers`, { replace: true })
      })
    })
  })

  describe('permission priority', () => {
    it('should prioritize analyticsView over customersView when no dashboard feature', async () => {
      mockHasPermissions.mockImplementation((perms: string[]) => {
        // User has both analyticsView and customersView
        return perms.includes('analyticsView') || perms.includes('customersView')
      })
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/analytics`, { replace: true })
      })
    })

    it('should prioritize dataApiView + dashboard feature over customersView', async () => {
      mockHasPermissions.mockImplementation((perms: string[]) => {
        // User has both dataApiView and customersView
        return perms.includes('dataApiView') || perms.includes('customersView')
      })
      mockHasOrganizationPremiumAddon.mockImplementation((addon: PremiumIntegrationTypeEnum) => {
        return addon === PremiumIntegrationTypeEnum.AnalyticsDashboards
      })

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/analytics/revenue-streams`, {
          replace: true,
        })
      })
    })

    it('should fall back to customersView when user lacks full analytics permissions but dashboard feature is enabled', async () => {
      // User has analyticsView but NOT dataApiView, and dashboard feature is enabled
      // canSeeAnalytics requires BOTH analyticsView AND dataApiView, so it's false
      // Should fall through to customersView
      mockHasPermissions.mockImplementation((perms: string[]) => {
        // Return false for ['analyticsView', 'dataApiView'] since user lacks dataApiView
        if (perms.includes('analyticsView') && perms.includes('dataApiView')) {
          return false
        }
        return perms.includes('customersView')
      })
      mockHasOrganizationPremiumAddon.mockImplementation((addon: PremiumIntegrationTypeEnum) => {
        return addon === PremiumIntegrationTypeEnum.AnalyticsDashboards
      })

      renderHook(() => Home())

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_ORG_SLUG}/customers`, { replace: true })
      })
    })
  })
})
