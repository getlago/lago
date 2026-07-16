import Tab from '@mui/material/Tab'
import Tabs from '@mui/material/Tabs'
import Typography from '@mui/material/Typography'
import { Icon, IconName } from 'lago-design-system'
import { ReactNode, useEffect, useState } from 'react'
import { matchPath } from 'react-router-dom'

import { useLocation, useNavigate } from '~/core/router'
import { tw } from '~/styles/utils'

import { Skeleton } from './Skeleton'

export enum TabManagedBy {
  URL = 'url',
  INDEX = 'index',
}

type NavigationTabItem = {
  link?: string
  title: string
  match?: string[]
  icon?: IconName
  disabled?: boolean
  hidden?: boolean
  component?: ReactNode
  dataTest?: string
}

type NavigationTabProps = {
  managedBy?: TabManagedBy
  loading?: boolean
  name?: string
  className?: string
  tabPanelClassName?: string
  tabs: Array<NavigationTabItem>
  children?: ReactNode
  onChange?: (index: number) => void
  currentTab?: number
}

interface TabPanelProps {
  children?: React.ReactNode
  index: number
  value: number
  className?: string
}

const CustomTabPanel = (props: TabPanelProps) => {
  const { children, value, index, ...other } = props

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`simple-tabpanel-${index}`}
      aria-labelledby={`simple-tab-${index}`}
      {...other}
    >
      {value === index && <>{children}</>}
    </div>
  )
}

const a11yProps = (index: number) => {
  return {
    id: `simple-tab-${index}`,
    'aria-controls': `simple-tabpanel-${index}`,
  }
}

export const NavigationTab = ({
  className,
  tabPanelClassName,
  loading,
  managedBy = TabManagedBy.URL,
  name = 'Navigation tab',
  tabs,
  children,
  onChange,
  currentTab,
}: NavigationTabProps) => {
  const navigate = useNavigate()
  const { strippedPathname: pathname } = useLocation()
  const nonHiddenTabs = tabs.filter((t) => !t.hidden)

  // Default value is not 0 to prevent useEffect value udpate to flash first component
  const [value, setValue] = useState<number | null>(currentTab || null)

  const handleChange = (event: React.SyntheticEvent, newValue: number) => {
    setValue(newValue)
    onChange?.(newValue)
  }

  // Make sure the active tab is selected when the page is loaded
  useEffect(() => {
    const findActiveTabIndexLookup: Record<
      TabManagedBy,
      ({ tab, tabIndex }: { tab: { link?: string; match?: string[] }; tabIndex: number }) => boolean
    > = {
      [TabManagedBy.URL]: ({ tab }) => {
        // Check if the current URL matches any of the paths in the match array
        if (!!tab?.match?.length) {
          return tab.match.some((matchUrl) => matchPath(matchUrl, pathname))
        }

        // Fall back to direct link comparison
        if (tab.link) {
          return !!matchPath(tab.link, pathname)
        }

        return false
      },
      [TabManagedBy.INDEX]: ({ tabIndex }) => tabIndex === value,
    }
    const activeTab = nonHiddenTabs.findIndex((tab, tabIndex) => {
      return findActiveTabIndexLookup[managedBy]({ tab, tabIndex })
    })

    if (activeTab !== -1) {
      setValue(activeTab)
    } else {
      setValue(0)
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nonHiddenTabs, pathname])

  // Prevent blink on first render
  if (value === null) return null

  return (
    <>
      <div className={tw('flex flex-row shadow-b', className)}>
        <Tabs
          className={tw('min-h-0 w-full flex-1 items-center overflow-visible', {
            'min-h-13': nonHiddenTabs.length > 1,
          })}
          variant="scrollable"
          role="navigation"
          scrollButtons={false}
          aria-label={name}
          onChange={handleChange}
          value={value}
        >
          {nonHiddenTabs.length >= 2
            ? nonHiddenTabs.map((tab, tabIndex) => {
                if (loading) {
                  return (
                    <Skeleton
                      key={`loding-tab-${tabIndex}`}
                      className={tw('mr-0 h-3 w-20', {
                        'mr-2': tabIndex !== nonHiddenTabs.length - 1,
                      })}
                      variant="text"
                    />
                  )
                }

                return (
                  <Tab
                    key={`tab-${tabIndex}`}
                    disableFocusRipple
                    disableRipple
                    role="tab"
                    component="button"
                    className="relative my-2 h-9 justify-between gap-1 overflow-visible rounded-xl p-2 text-grey-600 no-underline [min-height:unset] [min-width:unset] first:-ml-2 last:-mr-2 hover:bg-grey-100 hover:text-grey-700"
                    disabled={loading || tab.disabled}
                    icon={!!tab.icon ? <Icon name={tab.icon} /> : undefined}
                    iconPosition="start"
                    label={<Typography variant="captionHl">{tab.title}</Typography>}
                    value={tabIndex}
                    onClick={() => {
                      const onClickActionLookup: Record<TabManagedBy, () => void> = {
                        [TabManagedBy.URL]: () => {
                          if (!!tab.link && !matchPath(tab.link, pathname)) {
                            navigate(tab.link)
                          }
                        },
                        [TabManagedBy.INDEX]: () => {
                          if (tabIndex !== value) {
                            setValue(tabIndex)
                          }
                        },
                      }

                      onClickActionLookup[managedBy]()
                    }}
                    {...a11yProps(tabIndex)}
                    data-test={tab.dataTest || undefined}
                  />
                )
              })
            : null}
        </Tabs>
        {children && (
          <div className="flex flex-row flex-nowrap items-center justify-end gap-3 bg-white pl-4 shadow-b">
            {children}
          </div>
        )}
      </div>

      {value !== null &&
        nonHiddenTabs.map((tab, index) => {
          return (
            <CustomTabPanel
              key={`custom-tab-panel-${index}`}
              value={value}
              index={index}
              className={tabPanelClassName}
            >
              {tab.component}
            </CustomTabPanel>
          )
        })}
    </>
  )
}
