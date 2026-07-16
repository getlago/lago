import { IconName } from 'lago-design-system'

export interface NavTab {
  title: string
  icon: IconName
  link?: string
  match?: string[]
  external?: boolean
  onAction?: () => void
  canBeClickedOnActive?: boolean
  hidden?: boolean
  extraComponent?: React.ReactElement
}

interface NavTabsResult {
  tabs: NavTab[]
  allTabsHidden: boolean
}

/**
 * Processes navigation tabs and determines if all tabs are hidden.
 * Use this to conditionally render entire sections when all their tabs are hidden.
 *
 * @param tabs - Array of navigation tab configurations
 * @returns Object containing the tabs and a boolean indicating if all are hidden
 */
export const getNavTabs = (tabs: NavTab[]): NavTabsResult => {
  const allTabsHidden = tabs.every((tab) => tab.hidden === true)

  return {
    tabs,
    allTabsHidden,
  }
}
