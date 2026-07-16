import { getNavTabs, NavTab } from '../utils'

describe('getNavTabs', () => {
  describe('allTabsHidden calculation', () => {
    it('returns allTabsHidden as false when all tabs are visible', () => {
      const tabs: NavTab[] = [
        { title: 'Tab 1', icon: 'settings', link: '/tab1' },
        { title: 'Tab 2', icon: 'user', link: '/tab2' },
      ]

      const result = getNavTabs(tabs)

      expect(result.allTabsHidden).toBe(false)
    })

    it('returns allTabsHidden as false when some tabs are visible', () => {
      const tabs: NavTab[] = [
        { title: 'Tab 1', icon: 'settings', link: '/tab1', hidden: true },
        { title: 'Tab 2', icon: 'user', link: '/tab2', hidden: false },
        { title: 'Tab 3', icon: 'document', link: '/tab3' },
      ]

      const result = getNavTabs(tabs)

      expect(result.allTabsHidden).toBe(false)
    })

    it('returns allTabsHidden as true when all tabs are hidden', () => {
      const tabs: NavTab[] = [
        { title: 'Tab 1', icon: 'settings', link: '/tab1', hidden: true },
        { title: 'Tab 2', icon: 'user', link: '/tab2', hidden: true },
      ]

      const result = getNavTabs(tabs)

      expect(result.allTabsHidden).toBe(true)
    })

    it('returns allTabsHidden as true for empty tabs array', () => {
      const tabs: NavTab[] = []

      const result = getNavTabs(tabs)

      expect(result.allTabsHidden).toBe(true)
    })

    it('returns allTabsHidden as false when hidden is undefined (implicitly visible)', () => {
      const tabs: NavTab[] = [{ title: 'Tab 1', icon: 'settings', link: '/tab1' }]

      const result = getNavTabs(tabs)

      expect(result.allTabsHidden).toBe(false)
    })
  })

  describe('tabs passthrough', () => {
    it('returns the original tabs array unchanged', () => {
      const tabs: NavTab[] = [
        { title: 'Tab 1', icon: 'settings', link: '/tab1', hidden: false },
        { title: 'Tab 2', icon: 'user', link: '/tab2', hidden: true },
      ]

      const result = getNavTabs(tabs)

      expect(result.tabs).toBe(tabs)
      expect(result.tabs).toHaveLength(2)
    })

    it('preserves all tab properties', () => {
      const tabs: NavTab[] = [
        {
          title: 'Tab 1',
          icon: 'settings',
          link: '/tab1',
          match: ['/tab1', '/tab1/:id'],
          external: true,
          canBeClickedOnActive: true,
          hidden: false,
        },
      ]

      const result = getNavTabs(tabs)

      expect(result.tabs[0]).toEqual(tabs[0])
    })
  })
})
