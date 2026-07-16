import { FC } from 'react'

import { ActionsBlock } from './ActionRenderer'
import { Breadcrumb } from './Breadcrumb'
import { EntitySection } from './EntitySection'
import { MainHeaderConfigure } from './MainHeaderConfigure'
import { useMainHeaderReader } from './MainHeaderContext'
import {
  ACTIONS_BLOCK_TEST_ID,
  MAIN_HEADER_FILTERS_TEST_ID,
  MAIN_HEADER_TEST_ID,
} from './mainHeaderTestIds'
import { NavigationTabBar } from './NavigationTabBar'

/**
 * MainHeader — layout-level component that reads from MainHeaderContext.
 * Renders the actual header based on the config provided by the nearest <MainHeader.Configure>.
 */
const MainHeaderComponent: FC = () => {
  const { config } = useMainHeaderReader()

  if (!config) return null

  const { breadcrumb, actions, entity, tabs, filtersSection } = config

  const hasBreadcrumb = breadcrumb && breadcrumb.length > 0
  const hasEntity = !!entity

  return (
    <header data-test={MAIN_HEADER_TEST_ID}>
      {/* Entity + actions */}
      <div className="flex items-start justify-between gap-4 px-4 pb-4 pt-17 md:px-12 md:pb-6 md:pt-12">
        <div className="flex min-w-0 flex-col gap-2">
          {hasBreadcrumb && <Breadcrumb items={breadcrumb} />}

          {hasEntity && <EntitySection entity={entity} />}
        </div>

        <ActionsBlock actions={actions} dataTest={ACTIONS_BLOCK_TEST_ID} />
      </div>

      {/* Tab bar */}
      {tabs && tabs.length >= 2 && <NavigationTabBar className="mx-4 md:mx-12" tabs={tabs} />}

      {/* Filter section */}
      {filtersSection && (
        <div className="px-4 pb-4 md:px-12" data-test={MAIN_HEADER_FILTERS_TEST_ID}>
          {filtersSection}
        </div>
      )}
    </header>
  )
}

export const MainHeader = Object.assign(MainHeaderComponent, {
  Configure: MainHeaderConfigure,
})
