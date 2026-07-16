import { resolveRedirectTarget } from '../utils'

jest.mock('~/core/router/utils/permissionRouteMap', () => ({
  getRouteForPermission: (permission: string | null) => {
    if (permission === 'plansView') return '/plans'
    if (permission === 'auditLogsView') return null

    return null
  },
}))

jest.mock('~/core/router/legacyPaths', () => ({
  LEGACY_APP_PATH_SEGMENTS: new Set(['customers', 'customer', 'plans', 'features']),
}))

// `resolveOrgSlug` reads the reactive var; mock it via the underlying util.
jest.mock('~/core/apolloClient/reactiveVars', () => ({
  ...jest.requireActual('~/core/apolloClient/reactiveVars'),
  getCurrentOrganizationId: jest.fn(),
}))

const { getCurrentOrganizationId } = jest.requireMock('~/core/apolloClient/reactiveVars')

const SLUG = 'acme'
const ORG_ID = 'org-acme'

const mockHasPermissions = jest.fn()
const mockFindFirstViewPermission = jest.fn()

const buildUser = (memberships = [{ organization: { id: ORG_ID, slug: SLUG } }]) =>
  ({ memberships }) as unknown as Parameters<typeof resolveRedirectTarget>[0]['currentUser']

const baseInput = (overrides: Partial<Parameters<typeof resolveRedirectTarget>[0]> = {}) => ({
  currentUser: buildUser(),
  ssoRedirectPath: undefined,
  savedLocation: undefined,
  hasPermissions: mockHasPermissions,
  findFirstViewPermission: mockFindFirstViewPermission,
  hasAccessToAnalyticsDashboardsFeature: false,
  ...overrides,
})

describe('resolveRedirectTarget()', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    getCurrentOrganizationId.mockReturnValue(ORG_ID)
    mockHasPermissions.mockReturnValue(false)
    mockFindFirstViewPermission.mockReturnValue(null)
  })

  describe('GIVEN the user has no resolvable slug', () => {
    it('THEN returns FORBIDDEN_ROUTE without consuming LS', () => {
      const result = resolveRedirectTarget(baseInput({ currentUser: undefined }))

      expect(result).toEqual({ to: '/forbidden', consumesSsoLs: false })
    })
  })

  describe('GIVEN ssoRedirectPath is present', () => {
    it('THEN returns the path as-is when it already contains a valid user slug', () => {
      const result = resolveRedirectTarget(baseInput({ ssoRedirectPath: `/${SLUG}/features` }))

      expect(result).toEqual({ to: `/${SLUG}/features`, consumesSsoLs: true })
    })

    it('THEN prepends the slug for legacy slug-less paths', () => {
      const result = resolveRedirectTarget(baseInput({ ssoRedirectPath: '/features' }))

      expect(result).toEqual({ to: `/${SLUG}/features`, consumesSsoLs: true })
    })

    it('THEN takes priority over savedLocation from router state', () => {
      const result = resolveRedirectTarget(
        baseInput({
          ssoRedirectPath: `/${SLUG}/features`,
          savedLocation: { pathname: `/${SLUG}/customers` },
        }),
      )

      expect(result).toEqual({ to: `/${SLUG}/features`, consumesSsoLs: true })
    })
  })

  describe('GIVEN savedLocation has a slug belonging to the current user', () => {
    it('THEN returns it as a Location object (preserves any extra fields)', () => {
      const savedLocation = { pathname: `/${SLUG}/customers`, search: '?tab=overview', hash: '' }
      const result = resolveRedirectTarget(baseInput({ savedLocation }))

      expect(result).toEqual({ to: savedLocation, consumesSsoLs: false })
    })
  })

  describe('GIVEN savedLocation has a slug NOT belonging to the user (multi-org leak)', () => {
    it('THEN does NOT use it and falls through to default navigation', () => {
      mockHasPermissions.mockReturnValueOnce(true) // analytics
      const result = resolveRedirectTarget(
        baseInput({ savedLocation: { pathname: '/other-org/features' } }),
      )

      expect(result).toEqual({ to: `/${SLUG}/analytics`, consumesSsoLs: false })
    })
  })

  describe('GIVEN savedLocation is a legacy slug-less path AND the user has a single membership', () => {
    it('THEN prepends the slug and preserves search + hash', () => {
      const result = resolveRedirectTarget(
        baseInput({
          savedLocation: { pathname: '/customers/123', search: '?tab=foo', hash: '#section' },
        }),
      )

      expect(result).toEqual({
        to: `/${SLUG}/customers/123?tab=foo#section`,
        consumesSsoLs: false,
      })
    })
  })

  describe('GIVEN savedLocation is a legacy path AND the user has multiple memberships', () => {
    it('THEN auto-prepends the resolved slug (universal recovery, ambiguity accepted)', () => {
      const result = resolveRedirectTarget(
        baseInput({
          currentUser: buildUser([
            { organization: { id: ORG_ID, slug: SLUG } },
            { organization: { id: 'org-b', slug: 'beta' } },
          ]),
          savedLocation: { pathname: '/customers/123' },
        }),
      )

      expect(result).toEqual({
        to: `/${SLUG}/customers/123`,
        consumesSsoLs: false,
      })
    })
  })

  // Iframe context (Salesforce/Hubspot CRM embeds) — slug-less legacy URLs
  // get auto-recovered using the LS-based slug regardless of membership
  // count, because the iframe hides the chrome and the user has no agency
  // to pick an org manually. Mirrors `OrganizationLayout`'s post-auth fix
  // (LAGO-1443) but for the post-LOGIN flow when session was expired.
  describe('GIVEN a multi-org user logs in with a savedLocation carrying iframe params', () => {
    const multiOrgUser = buildUser([
      { organization: { id: ORG_ID, slug: SLUG } },
      { organization: { id: 'org-b', slug: 'beta' } },
    ])

    it('THEN prepends LS-based slug for `?sfdc=true` (Salesforce) and preserves the iframe param', () => {
      const result = resolveRedirectTarget(
        baseInput({
          currentUser: multiOrgUser,
          savedLocation: {
            pathname: '/customer/abc-123/create/subscription',
            search: '?sfdc=true',
            hash: '',
          },
        }),
      )

      expect(result).toEqual({
        to: `/${SLUG}/customer/abc-123/create/subscription?sfdc=true`,
        consumesSsoLs: false,
      })
    })

    it('THEN prepends LS-based slug for `?ifrm=true` (Hubspot)', () => {
      const result = resolveRedirectTarget(
        baseInput({
          currentUser: multiOrgUser,
          savedLocation: {
            pathname: '/customer/abc-123/create-invoice',
            search: '?ifrm=true',
          },
        }),
      )

      expect(result).toEqual({
        to: `/${SLUG}/customer/abc-123/create-invoice?ifrm=true`,
        consumesSsoLs: false,
      })
    })

    it('THEN preserves additional query params alongside the iframe flag', () => {
      const result = resolveRedirectTarget(
        baseInput({
          currentUser: multiOrgUser,
          savedLocation: {
            pathname: '/customer/abc-123/create/subscription',
            search: '?sfdc=true&plan=foo',
          },
        }),
      )

      expect(result).toEqual({
        to: `/${SLUG}/customer/abc-123/create/subscription?sfdc=true&plan=foo`,
        consumesSsoLs: false,
      })
    })

    it('THEN still auto-prepends when the iframe flag is `false` — universal recovery does not depend on iframe context', () => {
      const result = resolveRedirectTarget(
        baseInput({
          currentUser: multiOrgUser,
          savedLocation: {
            pathname: '/customer/abc-123/create/subscription',
            search: '?sfdc=false',
          },
        }),
      )

      expect(result).toEqual({
        to: `/${SLUG}/customer/abc-123/create/subscription?sfdc=false`,
        consumesSsoLs: false,
      })
    })
  })

  describe('GIVEN no SSO and no savedLocation — default navigation', () => {
    it('THEN returns analytics when user has analytics perms and no dashboard feature', () => {
      mockHasPermissions.mockReturnValueOnce(true)
      const result = resolveRedirectTarget(baseInput())

      expect(result).toEqual({ to: `/${SLUG}/analytics`, consumesSsoLs: false })
    })

    it('THEN returns analytics tabs route when user has both analytics perms AND dashboard feature', () => {
      mockHasPermissions.mockReturnValueOnce(true)
      const result = resolveRedirectTarget(
        baseInput({ hasAccessToAnalyticsDashboardsFeature: true }),
      )

      expect(result).toEqual({
        to: `/${SLUG}/analytics/revenue-streams`,
        consumesSsoLs: false,
      })
    })

    it('THEN returns customers when user lacks analytics but has customersView', () => {
      mockHasPermissions
        .mockReturnValueOnce(false) // analytics check
        .mockReturnValueOnce(true) // customers check
      const result = resolveRedirectTarget(baseInput())

      expect(result).toEqual({ to: `/${SLUG}/customers`, consumesSsoLs: false })
    })

    it('THEN returns first-view-permission route when no analytics nor customers', () => {
      mockHasPermissions.mockReturnValue(false)
      mockFindFirstViewPermission.mockReturnValue('plansView')
      const result = resolveRedirectTarget(baseInput())

      expect(result).toEqual({ to: `/${SLUG}/plans`, consumesSsoLs: false })
    })

    it('THEN returns FORBIDDEN_ROUTE when no permission resolves to a route', () => {
      mockHasPermissions.mockReturnValue(false)
      mockFindFirstViewPermission.mockReturnValue('auditLogsView')
      const result = resolveRedirectTarget(baseInput())

      expect(result).toEqual({ to: '/forbidden', consumesSsoLs: false })
    })
  })
})
