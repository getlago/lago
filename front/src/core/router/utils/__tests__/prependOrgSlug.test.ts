import { prependOrgSlug } from '../prependOrgSlug'

describe('prependOrgSlug', () => {
  describe('GIVEN a valid organization slug and an absolute path', () => {
    describe('WHEN the path is a standard in-app route', () => {
      it.each([
        ['/customers', '/acme/customers'],
        ['/plans/123', '/acme/plans/123'],
        ['/settings/taxes', '/acme/settings/taxes'],
      ])('THEN should prepend the slug to %s', (input, expected) => {
        expect(prependOrgSlug(input, 'acme')).toBe(expected)
      })
    })
  })

  describe('GIVEN no organization slug', () => {
    describe('WHEN slug is undefined', () => {
      it('THEN should return the path unchanged', () => {
        expect(prependOrgSlug('/customers', undefined)).toBe('/customers')
      })
    })

    describe('WHEN slug is empty string', () => {
      it('THEN should return the path unchanged', () => {
        expect(prependOrgSlug('/customers', '')).toBe('/customers')
      })
    })
  })

  describe('GIVEN the path is not absolute', () => {
    it.each([
      ['customers', 'customers'],
      ['./customers', './customers'],
      ['', ''],
    ])('THEN should return "%s" unchanged', (input, expected) => {
      expect(prependOrgSlug(input, 'acme')).toBe(expected)
    })
  })

  describe('GIVEN the path is the root "/"', () => {
    describe('WHEN navigating to HOME_ROUTE', () => {
      it('THEN should return "/" unchanged', () => {
        expect(prependOrgSlug('/', 'acme')).toBe('/')
      })
    })
  })

  describe('GIVEN the path is already slug-prefixed', () => {
    describe('WHEN the path starts with /{slug}/', () => {
      it('THEN should not double-prepend', () => {
        expect(prependOrgSlug('/acme/customers', 'acme')).toBe('/acme/customers')
      })
    })

    describe('WHEN the path is exactly /{slug}', () => {
      it('THEN should not double-prepend', () => {
        expect(prependOrgSlug('/acme', 'acme')).toBe('/acme')
      })
    })
  })

  describe('GIVEN the path starts with a NEVER_SLUG_PREFIX', () => {
    it.each([
      ['/customer-portal', '/customer-portal'],
      ['/customer-portal/invoices', '/customer-portal/invoices'],
      ['/forbidden', '/forbidden'],
      ['/404', '/404'],
      ['/login', '/login'],
      ['/login/okta', '/login/okta'],
    ])('THEN should return "%s" unchanged', (input, expected) => {
      expect(prependOrgSlug(input, 'acme')).toBe(expected)
    })
  })
})
