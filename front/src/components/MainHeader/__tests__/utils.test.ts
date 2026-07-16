import { isTabActive } from '../utils'

describe('isTabActive', () => {
  describe('GIVEN a tab with match patterns', () => {
    const tab = {
      title: 'Overview',
      link: '/overview',
      match: ['/overview', '/overview/:id'],
    }

    describe('WHEN the pathname matches one of the patterns', () => {
      it('THEN should return true', () => {
        expect(isTabActive(tab, '/overview')).toBe(true)
      })

      it('THEN should return true for parameterized match', () => {
        expect(isTabActive(tab, '/overview/123')).toBe(true)
      })
    })

    describe('WHEN the pathname does not match any pattern', () => {
      it('THEN should return false', () => {
        expect(isTabActive(tab, '/settings')).toBe(false)
      })
    })
  })

  describe('GIVEN a tab with only a link (no match patterns)', () => {
    const tab = {
      title: 'Settings',
      link: '/settings',
    }

    describe('WHEN the pathname matches the link', () => {
      it('THEN should return true', () => {
        expect(isTabActive(tab, '/settings')).toBe(true)
      })
    })

    describe('WHEN the pathname does not match the link', () => {
      it('THEN should return false', () => {
        expect(isTabActive(tab, '/overview')).toBe(false)
      })
    })
  })

  describe('GIVEN a tab with an empty match array', () => {
    const tab = {
      title: 'Tab',
      link: '/tab-link',
      match: [],
    }

    describe('WHEN the pathname matches the link', () => {
      it('THEN should fall back to link matching and return true', () => {
        expect(isTabActive(tab, '/tab-link')).toBe(true)
      })
    })
  })

  describe('GIVEN a tab with no link and no match', () => {
    const tab = {
      title: 'Empty',
    }

    describe('WHEN called with any pathname', () => {
      it('THEN should return false', () => {
        expect(isTabActive(tab, '/anything')).toBe(false)
      })
    })
  })
})
