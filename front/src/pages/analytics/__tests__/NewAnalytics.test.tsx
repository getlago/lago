import { screen } from '@testing-library/react'
import { generatePath } from 'react-router-dom'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { NewAnalyticsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  ANALYTIC_ROUTE,
  ANALYTIC_TABS_ROUTE,
  ANALYTICS_V2_ROUTE,
  ANALYTICS_V2_TABS_ROUTE,
} from '~/core/router'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import NewAnalytics from '../NewAnalytics'

const ACTIVE_TAB_CONTENT_TEST_ID = 'active-tab-content'

let capturedConfig: MainHeaderConfig | null = null

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: Object.assign(() => null, {
    Configure: (props: MainHeaderConfig) => {
      capturedConfig = props
      return null
    },
  }),
}))

jest.mock('~/components/MainHeader/useMainHeaderTabContent', () => ({
  useMainHeaderTabContent: () => <div data-test="active-tab-content">Tab Content</div>,
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockHasOrganizationPremiumAddon = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
  }),
}))

// Mock child page components to avoid rendering their internals
jest.mock(
  '~/pages/analytics/RevenueStreams',
  () =>
    function MockRevenueStreams() {
      return <div data-test="revenue-streams-mock">RevenueStreams</div>
    },
)
jest.mock(
  '~/pages/analytics/Mrr',
  () =>
    function MockMrr() {
      return <div data-test="mrr-mock">Mrr</div>
    },
)
jest.mock(
  '~/pages/analytics/Usage',
  () =>
    function MockUsage() {
      return <div data-test="usage-mock">Usage</div>
    },
)
jest.mock(
  '~/pages/analytics/PrepaidCredits',
  () =>
    function MockPrepaidCredits() {
      return <div data-test="prepaid-credits-mock">PrepaidCredits</div>
    },
)
jest.mock(
  '~/pages/analytics/Invoices',
  () =>
    function MockInvoices() {
      return <div data-test="invoices-mock">Invoices</div>
    },
)

describe('NewAnalytics', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
    mockHasOrganizationPremiumAddon.mockReturnValue(false)
  })

  describe('GIVEN the page is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should configure MainHeader with entity viewName', () => {
        render(<NewAnalytics />)

        expect(capturedConfig?.entity?.viewName).toBeDefined()
      })

      it('THEN should configure MainHeader with tabs', () => {
        render(<NewAnalytics />)

        expect(capturedConfig?.tabs).toBeDefined()
        expect(capturedConfig?.tabs?.length).toBeGreaterThanOrEqual(4)
      })

      it('THEN should render the active tab content', () => {
        render(<NewAnalytics />)

        expect(screen.getByTestId(ACTIVE_TAB_CONTENT_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN user does not have revenue analytics addon', () => {
      it('THEN should hide the usage tab', () => {
        mockHasOrganizationPremiumAddon.mockReturnValue(false)
        window.history.pushState({}, '', ANALYTICS_V2_ROUTE)

        render(<NewAnalytics />)

        expect(capturedConfig?.tabs).toHaveLength(5)

        const usageTab = capturedConfig?.tabs?.find(
          (tab) =>
            tab.link ===
            generatePath(ANALYTICS_V2_TABS_ROUTE, {
              tab: NewAnalyticsTabsOptionsEnum.usage,
            }),
        )

        expect(usageTab?.hidden).toBe(true)
      })
    })

    describe('WHEN user has revenue analytics addon', () => {
      it('THEN should configure 5 tabs including usage', () => {
        mockHasOrganizationPremiumAddon.mockReturnValue(true)
        window.history.pushState({}, '', ANALYTICS_V2_ROUTE)

        render(<NewAnalytics />)

        expect(capturedConfig?.tabs).toHaveLength(5)

        const tabLinks = capturedConfig?.tabs?.map((tab) => tab.link)

        expect(tabLinks).toContain(
          generatePath(ANALYTICS_V2_TABS_ROUTE, {
            tab: NewAnalyticsTabsOptionsEnum.usage,
          }),
        )
      })

      it('THEN should check for RevenueAnalytics premium addon', () => {
        mockHasOrganizationPremiumAddon.mockReturnValue(true)

        render(<NewAnalytics />)

        expect(mockHasOrganizationPremiumAddon).toHaveBeenCalledWith(
          PremiumIntegrationTypeEnum.RevenueAnalytics,
        )
      })
    })

    describe('WHEN the revenue streams tab is configured', () => {
      it('THEN should include match routes for the analytics-v2 route', () => {
        window.history.pushState({}, '', ANALYTICS_V2_ROUTE)

        render(<NewAnalytics />)

        const revenueStreamsTab = capturedConfig?.tabs?.find(
          (tab) =>
            tab.link ===
            generatePath(ANALYTICS_V2_TABS_ROUTE, {
              tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
            }),
        )

        expect(revenueStreamsTab?.match).toContain(ANALYTICS_V2_ROUTE)
        expect(revenueStreamsTab?.match).toContain(
          generatePath(ANALYTICS_V2_TABS_ROUTE, {
            tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
          }),
        )
      })

      it('THEN should include match routes for the analytics route', () => {
        window.history.pushState({}, '', ANALYTIC_ROUTE)

        render(<NewAnalytics />)

        const revenueStreamsTab = capturedConfig?.tabs?.find(
          (tab) =>
            tab.link ===
            generatePath(ANALYTIC_TABS_ROUTE, {
              tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
            }),
        )

        expect(revenueStreamsTab?.match).toContain(ANALYTIC_ROUTE)
        expect(revenueStreamsTab?.match).toContain(
          generatePath(ANALYTIC_TABS_ROUTE, {
            tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
          }),
        )
      })
    })
  })

  describe('GIVEN the pathname is the base analytics-v2 route', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should redirect to revenue-streams tab', () => {
        window.history.pushState({}, '', ANALYTICS_V2_ROUTE)

        render(<NewAnalytics />)

        expect(testMockNavigateFn).toHaveBeenCalledWith(
          generatePath(ANALYTICS_V2_TABS_ROUTE, {
            tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
          }),
          { replace: true },
        )
      })
    })
  })

  describe('GIVEN the pathname is the base analytics route', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should redirect to revenue-streams tab', () => {
        window.history.pushState({}, '', ANALYTIC_ROUTE)

        render(<NewAnalytics />)

        expect(testMockNavigateFn).toHaveBeenCalledWith(
          generatePath(ANALYTIC_TABS_ROUTE, {
            tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
          }),
          { replace: true },
        )
      })
    })
  })

  describe('GIVEN the pathname is a specific tab route', () => {
    describe('WHEN the component mounts on analytics-v2 tab', () => {
      it('THEN should not redirect', () => {
        window.history.pushState(
          {},
          '',
          generatePath(ANALYTICS_V2_TABS_ROUTE, {
            tab: NewAnalyticsTabsOptionsEnum.mrr,
          }),
        )

        render(<NewAnalytics />)

        expect(testMockNavigateFn).not.toHaveBeenCalled()
      })
    })

    describe('WHEN the component mounts on analytics tab', () => {
      it('THEN should not redirect', () => {
        window.history.pushState(
          {},
          '',
          generatePath(ANALYTIC_TABS_ROUTE, {
            tab: NewAnalyticsTabsOptionsEnum.mrr,
          }),
        )

        render(<NewAnalytics />)

        expect(testMockNavigateFn).not.toHaveBeenCalled()
      })
    })
  })
})
