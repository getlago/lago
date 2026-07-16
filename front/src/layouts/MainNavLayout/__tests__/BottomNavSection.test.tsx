import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { BOTTOM_NAV_SECTION_TEST_ID, BottomNavSection } from '../BottomNavSection'

const mockHasPermissions = jest.fn()
const mockHasPermissionsOr = jest.fn()
const mockOpenInspector = jest.fn()

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
    hasPermissionsOr: mockHasPermissionsOr,
  }),
}))

jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({
    openPanel: mockOpenInspector,
  }),
}))

jest.mock('~/core/apolloClient', () => {
  const actual = jest.requireActual('~/core/apolloClient')

  return {
    ...actual,
    envGlobalVar: jest.fn(() => ({ appEnv: 'development' })),
  }
})

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

// Import the mocked function after jest.mock is defined
const { envGlobalVar } = jest.requireMock('~/core/apolloClient')

describe('BottomNavSection', () => {
  const defaultProps = {
    isLoading: false,
    onItemClick: jest.fn(),
  }

  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
    mockHasPermissionsOr.mockReturnValue(true)
    envGlobalVar.mockReturnValue({ appEnv: 'development' })
  })

  describe('Test ID constants', () => {
    it('exports expected test ID constants', () => {
      expect(BOTTOM_NAV_SECTION_TEST_ID).toBe('bottom-nav-section')
    })

    it('test ID constants follow kebab-case naming convention', () => {
      expect(BOTTOM_NAV_SECTION_TEST_ID).toMatch(/^[a-z-]+$/)
    })
  })

  describe('Component rendering', () => {
    it('renders the bottom nav section', () => {
      render(<BottomNavSection {...defaultProps} />)

      expect(screen.getByTestId(BOTTOM_NAV_SECTION_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Section visibility based on tab permissions', () => {
    it('does not render section when all tabs are hidden in production with no permissions', () => {
      // Mock production environment where design system tab is hidden
      envGlobalVar.mockReturnValue({ appEnv: 'production' })

      // No permissions for settings or developer tools
      mockHasPermissions.mockReturnValue(false)
      mockHasPermissionsOr.mockReturnValue(false)

      const { container } = render(<BottomNavSection {...defaultProps} />)

      // When all tabs are hidden (production env + no permissions), component should return null
      expect(screen.queryByTestId(BOTTOM_NAV_SECTION_TEST_ID)).not.toBeInTheDocument()
      expect(container.firstChild).toBeNull()
    })

    it('does not render section when all tabs are hidden in staging with no permissions', () => {
      // Mock staging environment where design system tab is hidden
      envGlobalVar.mockReturnValue({ appEnv: 'staging' })

      // No permissions for settings or developer tools
      mockHasPermissions.mockReturnValue(false)
      mockHasPermissionsOr.mockReturnValue(false)

      const { container } = render(<BottomNavSection {...defaultProps} />)

      // Design system tab should be visible in staging, so section renders
      // All tabs should be hidden
      expect(screen.queryByTestId(BOTTOM_NAV_SECTION_TEST_ID)).not.toBeInTheDocument()
      expect(container.firstChild).toBeNull()
    })

    it('renders section when at least one tab is visible (settings)', () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        // Only allow organizationView (settings)
        return permissions.includes('organizationView')
      })
      mockHasPermissionsOr.mockReturnValue(false)

      render(<BottomNavSection {...defaultProps} />)

      expect(screen.getByTestId(BOTTOM_NAV_SECTION_TEST_ID)).toBeInTheDocument()
    })

    it('renders section when at least one tab is visible (developer tools)', () => {
      // Production environment (design system hidden)
      envGlobalVar.mockReturnValue({ appEnv: 'production' })

      mockHasPermissions.mockReturnValue(false)
      mockHasPermissionsOr.mockImplementation((permissions: string[]) => {
        // Only allow developersManage (developer tools)
        return permissions.includes('developersManage')
      })

      render(<BottomNavSection {...defaultProps} />)

      expect(screen.getByTestId(BOTTOM_NAV_SECTION_TEST_ID)).toBeInTheDocument()
    })

    it('renders section when at least one tab is visible (design system in QA)', () => {
      // QA environment where design system tab is visible
      envGlobalVar.mockReturnValue({ appEnv: 'qa' })

      // No permissions for settings or developer tools
      mockHasPermissions.mockReturnValue(false)
      mockHasPermissionsOr.mockReturnValue(false)

      render(<BottomNavSection {...defaultProps} />)

      // Design system tab should be visible in QA, so section renders
      expect(screen.getByTestId(BOTTOM_NAV_SECTION_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Permission-based visibility', () => {
    it('calls hasPermissions for settings visibility', () => {
      render(<BottomNavSection {...defaultProps} />)

      expect(mockHasPermissions).toHaveBeenCalledWith(['organizationView'])
    })

    it('calls hasPermissionsOr for developer tools visibility', () => {
      render(<BottomNavSection {...defaultProps} />)

      expect(mockHasPermissionsOr).toHaveBeenCalledWith([
        'developersManage',
        'developersKeysManage',
      ])
    })
  })

  describe('Component exports', () => {
    it('exports successfully', () => {
      expect(BottomNavSection).toBeDefined()
      expect(typeof BottomNavSection).toBe('function')
    })
  })
})
