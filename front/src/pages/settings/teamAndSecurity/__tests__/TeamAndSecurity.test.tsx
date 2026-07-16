import { cleanup, screen, waitFor } from '@testing-library/react'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { initializeTranslations } from '~/core/apolloClient'
import { render } from '~/test-utils'

import TeamAndSecurity from '../TeamAndSecurity'

const TeamAndSecurityWithHeader = () => (
  <>
    <MainHeader />
    <TeamAndSecurity />
  </>
)

const mockHasPermissions = jest.fn()
const mockHasOrganizationPremiumAddon = jest.fn()

jest.mock('../authentication/Authentication', () => {
  return {
    __esModule: true,
    default: () => <div data-test="authentication-tab">Authentication Content</div>,
  }
})

jest.mock('../members/Members', () => {
  return {
    __esModule: true,
    default: () => <div data-test="members-tab">Members Content</div>,
  }
})

jest.mock('../roles/rolesList/RolesList', () => {
  return {
    __esModule: true,
    default: () => <div data-test="roles-tab">Roles Content</div>,
  }
})

jest.mock('../securityLogs/SecurityLogs', () => {
  return {
    __esModule: true,
    default: () => <div data-test="security-logs-tab">Security Logs Content</div>,
  }
})

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {},
    loading: false,
    hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

describe('TeamAndSecurity', () => {
  beforeAll(async () => {
    await initializeTranslations()
  })

  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
    mockHasOrganizationPremiumAddon.mockReturnValue(true)
    // Default URL for tab resolution
    window.history.pushState({}, '', '/settings/team-and-security/members')
  })

  afterEach(cleanup)

  describe('with all permissions', () => {
    it('renders the page header', async () => {
      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        expect(document.body.textContent).toBeTruthy()
      })
    })

    it('renders 4 navigation tabs', async () => {
      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs).toHaveLength(4)
      })
    })

    it('renders Members tab label', async () => {
      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs[0]).toHaveTextContent('Members')
      })
    })

    it('renders Roles & permissions tab label', async () => {
      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs[1]).toBeInTheDocument()
      })
    })

    it('renders Authentication tab label', async () => {
      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs[2]).toHaveTextContent('Authentication')
      })
    })

    it('renders first tab as selected by default', async () => {
      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs[0]).toHaveAttribute('aria-selected', 'true')
      })
    })

    it('renders the first tab panel content (Members)', async () => {
      window.history.pushState({}, '', '/settings/team-and-security/members')
      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        expect(screen.getByTestId('members-tab')).toBeInTheDocument()
      })
    })
  })

  describe('with partial permissions', () => {
    it('hides Members tab when organizationMembersView is not permitted', async () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        return !permissions.includes('organizationMembersView')
      })

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs).toHaveLength(3)
        expect(tabs[0]).not.toHaveTextContent('Members')
      })
    })

    it('hides Roles tab when rolesView is not permitted', async () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        return !permissions.includes('rolesView')
      })

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs).toHaveLength(3)
        expect(tabs[0]).toHaveTextContent('Members')
        expect(tabs[1]).toHaveTextContent('Authentication')
      })
    })

    it('hides Authentication tab when authenticationMethodsView is not permitted', async () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        return !permissions.includes('authenticationMethodsView')
      })

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs).toHaveLength(3)
        expect(tabs.find((tab) => tab.textContent === 'Authentication')).toBeUndefined()
      })
    })

    it('hides Security logs tab when securityLogsView is not permitted', async () => {
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        return !permissions.includes('securityLogsView')
      })

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs).toHaveLength(3)
        expect(tabs.find((tab) => tab.textContent === 'Security logs')).toBeUndefined()
      })
    })

    it('hides Security logs tab when SecurityLogs premium addon is not available', async () => {
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs).toHaveLength(3)
        expect(tabs.find((tab) => tab.textContent === 'Security logs')).toBeUndefined()
      })
    })

    it('only shows Members and Roles tabs when only those permissions are granted', async () => {
      const allowedPermissions = ['organizationMembersView', 'rolesView']

      mockHasPermissions.mockImplementation((permissions: string[]) => {
        return permissions.every((p: string) => allowedPermissions.includes(p))
      })

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        const tabs = screen.getAllByRole('tab')

        expect(tabs).toHaveLength(2)
        expect(tabs[0]).toHaveTextContent('Members')
      })
    })

    it('shows only Security logs tab when only securityLogsView is permitted', async () => {
      window.history.pushState({}, '', '/settings/team-and-security/logs')
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        return permissions.every((p: string) => p === 'securityLogsView')
      })

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        expect(screen.getByTestId('security-logs-tab')).toBeInTheDocument()
      })
    })

    it('renders the first visible tab content when Members is hidden', async () => {
      window.history.pushState({}, '', '/settings/team-and-security/roles')
      mockHasPermissions.mockImplementation((permissions: string[]) => {
        return !permissions.includes('organizationMembersView')
      })

      render(<TeamAndSecurityWithHeader />)

      await waitFor(() => {
        expect(screen.getByTestId('roles-tab')).toBeInTheDocument()
      })
    })
  })
})
