import { stripOrgSlug } from '../stripOrgSlug'

describe('stripOrgSlug', () => {
  describe('GIVEN a valid organization slug', () => {
    describe('WHEN the pathname starts with /{slug}/', () => {
      it.each([
        ['/acme/customers', '/customers'],
        ['/acme/plans/123', '/plans/123'],
        ['/acme/settings/taxes', '/settings/taxes'],
      ])('THEN should strip the slug from "%s"', (input, expected) => {
        expect(stripOrgSlug(input, 'acme')).toBe(expected)
      })
    })

    describe('WHEN the pathname is exactly /{slug} (no trailing content)', () => {
      it('THEN should return "/"', () => {
        expect(stripOrgSlug('/acme', 'acme')).toBe('/')
      })
    })
  })

  describe('GIVEN no organization slug', () => {
    describe('WHEN slug is undefined', () => {
      it('THEN should return the pathname unchanged', () => {
        expect(stripOrgSlug('/acme/customers', undefined)).toBe('/acme/customers')
      })
    })
  })

  describe('GIVEN the pathname does not start with the slug prefix', () => {
    it.each([
      ['/other-org/customers', '/other-org/customers'],
      ['/customers', '/customers'],
      ['/login', '/login'],
    ])('THEN should return "%s" unchanged', (input, expected) => {
      expect(stripOrgSlug(input, 'acme')).toBe(expected)
    })
  })

  describe('GIVEN a pathname that partially matches the slug', () => {
    describe('WHEN the pathname starts with /{slug} but continues without a slash', () => {
      it('THEN should not strip (no false positive)', () => {
        expect(stripOrgSlug('/acme-extended/customers', 'acme')).toBe('/acme-extended/customers')
      })
    })
  })
})
