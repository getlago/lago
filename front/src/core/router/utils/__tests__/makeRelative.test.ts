import { CustomRouteObject } from '../../types'
import { makeRelative, stripLeadingSlash } from '../makeRelative'

describe('stripLeadingSlash', () => {
  describe('GIVEN a path with a leading slash', () => {
    it('THEN should remove the leading slash', () => {
      expect(stripLeadingSlash('/customers')).toBe('customers')
    })
  })

  describe('GIVEN a path without a leading slash', () => {
    it('THEN should return the path unchanged', () => {
      expect(stripLeadingSlash('customers')).toBe('customers')
    })
  })

  describe('GIVEN a root path', () => {
    it('THEN should return an empty string', () => {
      expect(stripLeadingSlash('/')).toBe('')
    })
  })

  describe('GIVEN an empty string', () => {
    it('THEN should return an empty string', () => {
      expect(stripLeadingSlash('')).toBe('')
    })
  })

  describe('GIVEN a nested path', () => {
    it('THEN should only strip the first slash', () => {
      expect(stripLeadingSlash('/settings/taxes')).toBe('settings/taxes')
    })
  })
})

describe('makeRelative', () => {
  describe('GIVEN routes with string paths', () => {
    it('THEN should strip leading slashes from all paths', () => {
      const routes: CustomRouteObject[] = [
        { path: '/customers', element: null },
        { path: '/plans', element: null },
      ]

      const result = makeRelative(routes)

      expect(result[0].path).toBe('customers')
      expect(result[1].path).toBe('plans')
    })
  })

  describe('GIVEN routes with array paths', () => {
    it('THEN should strip leading slashes from each path in the array', () => {
      const routes: CustomRouteObject[] = [
        { path: ['/analytics', '/analytics/:tab'], element: null },
      ]

      const result = makeRelative(routes)

      expect(result[0].path).toEqual(['analytics', 'analytics/:tab'])
    })
  })

  describe('GIVEN routes without a path (layout wrappers)', () => {
    it('THEN should pass through unchanged', () => {
      const routes: CustomRouteObject[] = [{ element: null }]

      const result = makeRelative(routes)

      expect(result[0].path).toBeUndefined()
    })
  })

  describe('GIVEN routes with children', () => {
    it('THEN should recursively convert children to relative paths', () => {
      const routes: CustomRouteObject[] = [
        {
          path: '/settings',
          element: null,
          children: [
            { path: '/settings/taxes', element: null },
            { path: '/settings/team', element: null },
          ],
        },
      ]

      const result = makeRelative(routes)

      expect(result[0].path).toBe('settings')
      expect(result[0].children?.[0].path).toBe('settings/taxes')
      expect(result[0].children?.[1].path).toBe('settings/team')
    })
  })

  describe('GIVEN routes without children', () => {
    it('THEN should preserve undefined children', () => {
      const routes: CustomRouteObject[] = [{ path: '/customers', element: null }]

      const result = makeRelative(routes)

      expect(result[0].children).toBeUndefined()
    })
  })

  describe('GIVEN routes that are already relative', () => {
    it('THEN should return them unchanged', () => {
      const routes: CustomRouteObject[] = [
        { path: 'customers', element: null },
        { path: ['analytics', 'analytics/:tab'], element: null },
      ]

      const result = makeRelative(routes)

      expect(result[0].path).toBe('customers')
      expect(result[1].path).toEqual(['analytics', 'analytics/:tab'])
    })
  })

  describe('GIVEN routes preserve other properties', () => {
    it('THEN should keep private, permissions, and other fields', () => {
      const routes: CustomRouteObject[] = [
        {
          path: '/customers',
          element: null,
          private: true,
          permissions: ['customersView'],
        },
      ]

      const result = makeRelative(routes)

      expect(result[0]).toEqual(
        expect.objectContaining({
          path: 'customers',
          private: true,
          permissions: ['customersView'],
        }),
      )
    })
  })
})
