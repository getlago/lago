import { ReactNode, useMemo } from 'react'

import { useLocation } from '~/core/router'

import { useMainHeaderReader } from './MainHeaderContext'
import { MainHeaderTab } from './types'
import { isTabActive } from './utils'

/**
 * Hook to resolve the active tab's content from the MainHeader config.
 * Matches the current URL against each tab's link/match patterns.
 * Returns the content of the first matching tab, or the first visible
 * tab's content as a fallback to prevent blank pages.
 *
 * Safe to use in pages that also mount <MainHeader.Configure> because
 * Configure only calls setConfig when its serializable fingerprint changes,
 * preventing the re-render loop structurally. No useMemo required from pages.
 */
export const useMainHeaderTabContent = (): ReactNode | null => {
  const { config } = useMainHeaderReader()
  // Tab constants are slug-unaware; strip the slug from pathname for matching.
  const { strippedPathname } = useLocation()

  return useMemo(() => {
    if (!config?.tabs) return null

    const visibleTabs = config.tabs.filter((tab: MainHeaderTab) => !tab.hidden)
    const activeTab = visibleTabs.find((tab: MainHeaderTab) => isTabActive(tab, strippedPathname))

    return activeTab?.content ?? visibleTabs[0]?.content ?? null
  }, [config?.tabs, strippedPathname])
}
