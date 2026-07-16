import { buildAuthHeaders } from '../authHeaders'

const mockGetCurrentOrganizationId = jest.fn()

jest.mock('../reactiveVars', () => ({
  AUTH_TOKEN_LS_KEY: 'auth_token',
  TMP_AUTH_TOKEN_LS_KEY: 'tmp_auth_token',
  CUSTOMER_PORTAL_TOKEN_LS_KEY: 'customer_portal_token',
  getCurrentOrganizationId: (...args: unknown[]) => mockGetCurrentOrganizationId(...args),
}))

jest.mock('~/hooks/useDeveloperTool', () => ({
  DEVTOOL_AUTO_SAVE_KEY: 'devtool_auto_save',
  resetDevtoolsNavigation: jest.fn(),
}))

const PORTAL_PATH = '/customer-portal/portal-token-abc'
const ADMIN_PATH = '/acme/customers'

describe('buildAuthHeaders', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    localStorage.clear()
    mockGetCurrentOrganizationId.mockReturnValue(null)
  })

  describe('GIVEN a customer portal route', () => {
    describe('WHEN both an admin token and a portal token exist in localStorage', () => {
      it('THEN should send only the customer-portal-token header', () => {
        localStorage.setItem('auth_token', 'expired-admin-jwt')
        localStorage.setItem('customer_portal_token', 'valid-portal-token')
        mockGetCurrentOrganizationId.mockReturnValue('org-123')

        const headers = buildAuthHeaders(PORTAL_PATH)

        expect(headers).toEqual({ 'customer-portal-token': 'valid-portal-token' })
      })
    })

    describe('WHEN the path is a portal sub-route', () => {
      it('THEN should still resolve as a portal route', () => {
        localStorage.setItem('auth_token', 'expired-admin-jwt')
        localStorage.setItem('customer_portal_token', 'valid-portal-token')

        expect(buildAuthHeaders(`${PORTAL_PATH}/usage/item-1`)).toEqual({
          'customer-portal-token': 'valid-portal-token',
        })
        expect(buildAuthHeaders(`${PORTAL_PATH}/wallet/wallet-1`)).toEqual({
          'customer-portal-token': 'valid-portal-token',
        })
      })
    })

    describe('WHEN no portal token exists in localStorage', () => {
      it('THEN should send no headers at all (no admin token fallback)', () => {
        localStorage.setItem('auth_token', 'expired-admin-jwt')
        mockGetCurrentOrganizationId.mockReturnValue('org-123')

        expect(buildAuthHeaders(PORTAL_PATH)).toEqual({})
      })
    })
  })

  describe('GIVEN an admin route', () => {
    describe('WHEN both an admin token and a portal token exist in localStorage', () => {
      it('THEN should send authorization and organization headers but never the portal token', () => {
        localStorage.setItem('auth_token', 'admin-jwt')
        localStorage.setItem('customer_portal_token', 'stale-portal-token')
        mockGetCurrentOrganizationId.mockReturnValue('org-123')

        expect(buildAuthHeaders(ADMIN_PATH)).toEqual({
          authorization: 'Bearer admin-jwt',
          'x-lago-organization': 'org-123',
        })
      })
    })

    describe('WHEN only the temporary auth token exists (login flow)', () => {
      it('THEN should use the temporary token as Bearer', () => {
        localStorage.setItem('tmp_auth_token', 'tmp-jwt')

        expect(buildAuthHeaders('/login')).toEqual({ authorization: 'Bearer tmp-jwt' })
      })
    })

    describe('WHEN both the auth token and the temporary token exist', () => {
      it('THEN should prefer the auth token', () => {
        localStorage.setItem('auth_token', 'admin-jwt')
        localStorage.setItem('tmp_auth_token', 'tmp-jwt')

        expect(buildAuthHeaders(ADMIN_PATH)).toEqual({ authorization: 'Bearer admin-jwt' })
      })
    })

    describe('WHEN no organization id is resolved', () => {
      it('THEN should omit the x-lago-organization header', () => {
        localStorage.setItem('auth_token', 'admin-jwt')
        mockGetCurrentOrganizationId.mockReturnValue(null)

        const headers = buildAuthHeaders(ADMIN_PATH)

        expect(headers).toEqual({ authorization: 'Bearer admin-jwt' })
        expect(headers).not.toHaveProperty('x-lago-organization')
      })
    })

    describe('WHEN no token exists at all', () => {
      it('THEN should send no headers', () => {
        expect(buildAuthHeaders(ADMIN_PATH)).toEqual({})
      })
    })
  })
})
