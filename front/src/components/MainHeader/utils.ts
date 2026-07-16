import { matchPath } from 'react-router-dom'

import { NavigationTabBarItem } from './NavigationTabBar'

/**
 * Check if a tab matches the current pathname.
 * Shared predicate used by NavigationTabBar (for active index)
 * and useMainHeaderTabContent (for active content).
 */
export const isTabActive = (tab: NavigationTabBarItem, pathname: string): boolean => {
  if (tab.match?.length) {
    return tab.match.some((pattern) => matchPath(pattern, pathname))
  }

  if (tab.link) {
    return !!matchPath(tab.link, pathname)
  }

  return false
}
