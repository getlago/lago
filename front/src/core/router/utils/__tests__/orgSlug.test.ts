import { OrgSlugResolverDataFragment } from '~/generated/graphql'

import { ensureSlugPrefix, pathHasValidSlug, resolveOrgSlug } from '../orgSlug'

const mockGetCurrentOrganizationId = jest.fn()
const mockGetPersistedOrganizationSlug = jest.fn()

jest.mock('~/core/apolloClient/reactiveVars', () => ({
  getCurrentOrganizationId: () => mockGetCurrentOrganizationId(),
  getPersistedOrganizationSlug: () => mockGetPersistedOrganizationSlug(),
}))

type CurrentUser = OrgSlugResolverDataFragment | undefined

const buildCurrentUser = (
  memberships: Array<{ id: string; organization: { id: string; name: string; slug: string } }>,
): CurrentUser =>
  ({
    memberships,
  }) as unknown as CurrentUser

const defaultMemberships = [
  { id: 'm-1', organization: { id: 'org-a', name: 'Org A', slug: 'org-a' } },
  { id: 'm-2', organization: { id: 'org-b', name: 'Org B', slug: 'org-b' } },
]

describe('resolveOrgSlug', () => {
  beforeEach(() => {
    mockGetCurrentOrganizationId.mockClear()
    mockGetPersistedOrganizationSlug.mockClear()
    mockGetPersistedOrganizationSlug.mockReturnValue(null)
  })

  describe('GIVEN a user with memberships and a matching current org ID', () => {
    it('THEN should return the slug of the matching organization', () => {
      mockGetCurrentOrganizationId.mockReturnValue('org-b')

      const result = resolveOrgSlug(buildCurrentUser(defaultMemberships))

      expect(result).toBe('org-b')
    })
  })

  describe('GIVEN no current org ID (e.g. hard reload) but a persisted last-used slug', () => {
    it('THEN should recover to the persisted org slug, not memberships[0]', () => {
      mockGetCurrentOrganizationId.mockReturnValue(undefined)
      mockGetPersistedOrganizationSlug.mockReturnValue('org-b')

      const result = resolveOrgSlug(buildCurrentUser(defaultMemberships))

      expect(result).toBe('org-b')
    })
  })

  describe('GIVEN the in-memory current org and the persisted slug differ', () => {
    it('THEN should prefer the in-memory current org (per-tab, multi-tab safe)', () => {
      mockGetCurrentOrganizationId.mockReturnValue('org-a')
      mockGetPersistedOrganizationSlug.mockReturnValue('org-b')

      const result = resolveOrgSlug(buildCurrentUser(defaultMemberships))

      expect(result).toBe('org-a')
    })
  })

  describe('GIVEN a user with memberships but no matching current org ID', () => {
    it('THEN should fallback to the first membership slug', () => {
      mockGetCurrentOrganizationId.mockReturnValue('org-nonexistent')

      const result = resolveOrgSlug(buildCurrentUser(defaultMemberships))

      expect(result).toBe('org-a')
    })
  })

  describe('GIVEN a user with memberships and no current org ID nor persisted slug', () => {
    it('THEN should fallback to the first membership slug', () => {
      mockGetCurrentOrganizationId.mockReturnValue(undefined)

      const result = resolveOrgSlug(buildCurrentUser(defaultMemberships))

      expect(result).toBe('org-a')
    })
  })

  describe('GIVEN an undefined user', () => {
    it('THEN should return undefined', () => {
      mockGetCurrentOrganizationId.mockReturnValue('org-a')

      const result = resolveOrgSlug(undefined)

      expect(result).toBeUndefined()
    })
  })

  describe('GIVEN a user with no memberships', () => {
    it('THEN should return undefined', () => {
      mockGetCurrentOrganizationId.mockReturnValue(undefined)

      const result = resolveOrgSlug(buildCurrentUser([]))

      expect(result).toBeUndefined()
    })
  })
})

describe('pathHasValidSlug', () => {
  const currentUser = buildCurrentUser(defaultMemberships)

  describe('GIVEN a path that starts with a valid org slug', () => {
    it('THEN should return true', () => {
      expect(pathHasValidSlug('/org-a/customers', currentUser)).toBe(true)
    })
  })

  describe('GIVEN a path that starts with another valid org slug', () => {
    it('THEN should return true', () => {
      expect(pathHasValidSlug('/org-b/settings', currentUser)).toBe(true)
    })
  })

  describe('GIVEN a path that does not start with any valid slug', () => {
    it('THEN should return false', () => {
      expect(pathHasValidSlug('/unknown-org/customers', currentUser)).toBe(false)
    })
  })

  describe('GIVEN a path without a slug prefix', () => {
    it('THEN should return false', () => {
      expect(pathHasValidSlug('/customers', currentUser)).toBe(false)
    })
  })

  describe('GIVEN an undefined user', () => {
    it('THEN should return false', () => {
      expect(pathHasValidSlug('/org-a/customers', undefined)).toBe(false)
    })
  })

  describe('GIVEN a path that partially matches a slug but is not a prefix', () => {
    it('THEN should return false', () => {
      // "/org-a-extended/..." should not match "/org-a/"
      expect(pathHasValidSlug('/org-a-extended/customers', currentUser)).toBe(false)
    })
  })

  describe('GIVEN a path that is exactly the slug without a trailing slash', () => {
    it('THEN should return false', () => {
      // `/org-a` (no trailing slash, nothing after) intentionally does NOT match.
      // The implementation requires `/${slug}/` to prevent false positives like
      // `/org-a-extended` which would otherwise match `startsWith('/org-a')`.
      expect(pathHasValidSlug('/org-a', currentUser)).toBe(false)
    })
  })

  describe('GIVEN a path that is the slug followed by a trailing slash only', () => {
    it('THEN should return true', () => {
      expect(pathHasValidSlug('/org-a/', currentUser)).toBe(true)
    })
  })
})

describe('ensureSlugPrefix', () => {
  const currentUser = buildCurrentUser(defaultMemberships)

  describe('GIVEN a path that already has a valid slug', () => {
    it('THEN should return the path unchanged', () => {
      expect(ensureSlugPrefix('/org-a/customers', 'org-a', currentUser)).toBe('/org-a/customers')
    })
  })

  describe('GIVEN a path without a slug that starts with /', () => {
    it('THEN should prepend the slug', () => {
      expect(ensureSlugPrefix('/customers', 'org-a', currentUser)).toBe('/org-a/customers')
    })
  })

  describe('GIVEN a path without a slug and without leading /', () => {
    it('THEN should prepend the slug with separators', () => {
      expect(ensureSlugPrefix('customers', 'org-a', currentUser)).toBe('/org-a/customers')
    })
  })

  describe('GIVEN a path with a different valid slug', () => {
    it('THEN should return the path unchanged', () => {
      expect(ensureSlugPrefix('/org-b/settings', 'org-a', currentUser)).toBe('/org-b/settings')
    })
  })
})
