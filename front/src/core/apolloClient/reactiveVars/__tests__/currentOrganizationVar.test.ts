import {
  currentOrganizationVar,
  getCurrentOrganizationId,
  getPersistedOrganizationSlug,
  setCurrentOrganizationId,
  setPersistedOrganizationSlug,
} from '../currentOrganizationVar'

const LAST_USED_KEY = 'lastUsedOrganizationSlug'

describe('currentOrganizationVar', () => {
  beforeEach(() => {
    localStorage.clear()
    currentOrganizationVar(null)
  })

  describe('getCurrentOrganizationId', () => {
    it('THEN returns null when the var has not been set', () => {
      expect(getCurrentOrganizationId()).toBeNull()
    })

    it('THEN returns the var value when set', () => {
      currentOrganizationVar('org-123')

      expect(getCurrentOrganizationId()).toBe('org-123')
    })
  })

  describe('setCurrentOrganizationId (in-memory only)', () => {
    it('THEN updates the in-memory var', () => {
      setCurrentOrganizationId('org-456')

      expect(currentOrganizationVar()).toBe('org-456')
    })

    it('THEN does NOT write the current org to localStorage', () => {
      setCurrentOrganizationId('org-456')

      expect(localStorage.getItem(LAST_USED_KEY)).toBeNull()
    })

    it('THEN clearing the var with null leaves the persisted last-used slug untouched', () => {
      localStorage.setItem(LAST_USED_KEY, 'acme')
      currentOrganizationVar('org-existing')

      setCurrentOrganizationId(null)

      expect(currentOrganizationVar()).toBeNull()
      expect(localStorage.getItem(LAST_USED_KEY)).toBe('acme')
    })
  })

  describe('persisted organization slug (localStorage-only "last used")', () => {
    it('THEN reads the last-used slug from localStorage', () => {
      localStorage.setItem(LAST_USED_KEY, 'acme')

      expect(getPersistedOrganizationSlug()).toBe('acme')
    })

    it('THEN returns null when nothing is persisted', () => {
      expect(getPersistedOrganizationSlug()).toBeNull()
    })

    it('THEN persists a slug', () => {
      setPersistedOrganizationSlug('acme')

      expect(localStorage.getItem(LAST_USED_KEY)).toBe('acme')
    })

    it('THEN removes the persisted slug when set to null', () => {
      localStorage.setItem(LAST_USED_KEY, 'acme')

      setPersistedOrganizationSlug(null)

      expect(localStorage.getItem(LAST_USED_KEY)).toBeNull()
    })

    it('THEN does NOT update the in-memory var', () => {
      setPersistedOrganizationSlug('acme')

      expect(currentOrganizationVar()).toBeNull()
    })
  })
})
