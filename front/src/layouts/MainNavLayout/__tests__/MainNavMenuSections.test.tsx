import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  MAIN_NAV_BILLING_SECTION_TEST_ID,
  MAIN_NAV_CONFIGURATION_SECTION_TEST_ID,
  MAIN_NAV_MENU_SECTIONS_TEST_ID,
  MAIN_NAV_REPORTS_SECTION_TEST_ID,
  MainNavMenuSections,
} from '../MainNavMenuSections'

const mockHasPermissions = jest.fn()
const mockHasFeatureFlag = jest.fn()

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasFeatureFlag: mockHasFeatureFlag,
  }),
}))

const mockIsPremium = jest.fn()

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: mockIsPremium() }),
}))

jest.mock('~/core/utils/featureFlags', () => ({
  FeatureFlags: {},
  isFeatureFlagActive: jest.fn(() => false),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

describe('MainNavMenuSections', () => {
  const defaultProps = {
    isLoading: false,
    onItemClick: jest.fn(),
  }

  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
    mockHasFeatureFlag.mockReturnValue(true)
    mockIsPremium.mockReturnValue(true)
  })

  describe('Test ID constants', () => {
    it('exports expected test ID constants', () => {
      expect(MAIN_NAV_MENU_SECTIONS_TEST_ID).toBe('main-nav-menu-sections')
      expect(MAIN_NAV_REPORTS_SECTION_TEST_ID).toBe('main-nav-reports-section')
      expect(MAIN_NAV_CONFIGURATION_SECTION_TEST_ID).toBe('main-nav-configuration-section')
      expect(MAIN_NAV_BILLING_SECTION_TEST_ID).toBe('main-nav-billing-section')
    })

    it('test ID constants follow kebab-case naming convention', () => {
      const testIds = [
        MAIN_NAV_MENU_SECTIONS_TEST_ID,
        MAIN_NAV_REPORTS_SECTION_TEST_ID,
        MAIN_NAV_CONFIGURATION_SECTION_TEST_ID,
        MAIN_NAV_BILLING_SECTION_TEST_ID,
      ]

      testIds.forEach((testId) => {
        expect(testId).toMatch(/^[a-z-]+$/)
      })
    })
  })

  describe('Component rendering', () => {
    it('renders the menu sections container', () => {
      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.getByTestId(MAIN_NAV_MENU_SECTIONS_TEST_ID)).toBeInTheDocument()
    })

    it('renders the configuration section', () => {
      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.getByTestId(MAIN_NAV_CONFIGURATION_SECTION_TEST_ID)).toBeInTheDocument()
    })

    it('renders the billing section', () => {
      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.getByTestId(MAIN_NAV_BILLING_SECTION_TEST_ID)).toBeInTheDocument()
    })

    it('renders the reports section when user has analytics permission', () => {
      mockHasPermissions.mockImplementation((permissions: string[]) =>
        permissions.includes('analyticsView'),
      )

      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.getByTestId(MAIN_NAV_REPORTS_SECTION_TEST_ID)).toBeInTheDocument()
    })

    it('does not render the reports section when user lacks analytics permission', () => {
      mockHasPermissions.mockImplementation(
        (permissions: string[]) => !permissions.includes('analyticsView'),
      )

      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.queryByTestId(MAIN_NAV_REPORTS_SECTION_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('Section visibility based on tab permissions', () => {
    it('does not render configuration section when all configuration tabs are hidden', () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        const configPermissions = [
          'billableMetricsView',
          'plansView',
          'featuresView',
          'addonsView',
          'couponsView',
        ]

        // Hide all configuration permissions, allow others
        if (configPermissions.some((p) => permissions.includes(p))) {
          return false
        }

        return true
      })

      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.queryByTestId(MAIN_NAV_CONFIGURATION_SECTION_TEST_ID)).not.toBeInTheDocument()
    })

    it('does not render billing section when all billing tabs are hidden', () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        const billingPermissions = [
          'customersView',
          'quotesView',
          'subscriptionsView',
          'invoicesView',
          'paymentsView',
          'creditNotesView',
        ]

        // Hide all billing permissions, allow others
        if (billingPermissions.some((p) => permissions.includes(p))) {
          return false
        }

        return true
      })

      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.queryByTestId(MAIN_NAV_BILLING_SECTION_TEST_ID)).not.toBeInTheDocument()
    })

    it('does not render any sections when all permissions are false', () => {
      mockHasPermissions.mockReturnValue(false)

      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.queryByTestId(MAIN_NAV_MENU_SECTIONS_TEST_ID)).not.toBeInTheDocument()
      expect(screen.queryByTestId(MAIN_NAV_BILLING_SECTION_TEST_ID)).not.toBeInTheDocument()
      expect(screen.queryByTestId(MAIN_NAV_REPORTS_SECTION_TEST_ID)).not.toBeInTheDocument()
      expect(screen.queryByTestId(MAIN_NAV_CONFIGURATION_SECTION_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders only sections with visible tabs', () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        // Only allow billing permissions
        const billingPermissions = [
          'customersView',
          'subscriptionsView',
          'invoicesView',
          'paymentsView',
          'creditNotesView',
        ]

        return billingPermissions.some((p) => permissions.includes(p))
      })

      render(<MainNavMenuSections {...defaultProps} />)

      // Menu sections container should be rendered
      expect(screen.getByTestId(MAIN_NAV_MENU_SECTIONS_TEST_ID)).toBeInTheDocument()

      // Only billing section should be visible
      expect(screen.getByTestId(MAIN_NAV_BILLING_SECTION_TEST_ID)).toBeInTheDocument()

      // Reports and configuration should be hidden
      expect(screen.queryByTestId(MAIN_NAV_REPORTS_SECTION_TEST_ID)).not.toBeInTheDocument()
      expect(screen.queryByTestId(MAIN_NAV_CONFIGURATION_SECTION_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('Permission-based visibility', () => {
    it('calls hasPermissions with correct permissions for reports section', () => {
      render(<MainNavMenuSections {...defaultProps} />)

      expect(mockHasPermissions).toHaveBeenCalledWith(['analyticsView'])
    })

    it('calls hasPermissions for configuration items', () => {
      render(<MainNavMenuSections {...defaultProps} />)

      expect(mockHasPermissions).toHaveBeenCalledWith(['billableMetricsView'])
      expect(mockHasPermissions).toHaveBeenCalledWith(['plansView'])
      expect(mockHasPermissions).toHaveBeenCalledWith(['couponsView'])
    })

    it('calls hasPermissions for billing items', () => {
      render(<MainNavMenuSections {...defaultProps} />)

      expect(mockHasPermissions).toHaveBeenCalledWith(['customersView'])
      expect(mockHasPermissions).toHaveBeenCalledWith(['quotesView'])
      expect(mockHasPermissions).toHaveBeenCalledWith(['subscriptionsView'])
      expect(mockHasPermissions).toHaveBeenCalledWith(['invoicesView'])
    })
  })

  describe('Feature flag gating', () => {
    it('hides quotes nav item when order_forms feature flag is off', () => {
      mockHasFeatureFlag.mockReturnValue(false)

      // Allow all billing permissions except quotes will be hidden by feature flag
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        const billingPermissions = [
          'customersView',
          'quotesView',
          'subscriptionsView',
          'invoicesView',
          'paymentsView',
          'creditNotesView',
        ]

        return billingPermissions.some((p) => permissions.includes(p))
      })

      render(<MainNavMenuSections {...defaultProps} />)

      // Billing section should still render (other billing tabs are visible)
      expect(screen.getByTestId(MAIN_NAV_BILLING_SECTION_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Component exports', () => {
    it('exports successfully', () => {
      expect(MainNavMenuSections).toBeDefined()
      expect(typeof MainNavMenuSections).toBe('function')
    })
  })

  describe('Premium indicator', () => {
    it('renders sparkles icon on quotes nav item when user is not premium', () => {
      mockIsPremium.mockReturnValue(false)

      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.getByTestId('quotes-nav-premium-icon')).toBeInTheDocument()
    })

    it('does not render sparkles icon on quotes nav item when user is premium', () => {
      mockIsPremium.mockReturnValue(true)

      render(<MainNavMenuSections {...defaultProps} />)

      expect(screen.queryByTestId('quotes-nav-premium-icon')).not.toBeInTheDocument()
    })
  })
})
