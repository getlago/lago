import { act, screen } from '@testing-library/react'

import { render } from '~/test-utils'

import RolesList from '../RolesList'

const mockNavigate = jest.fn()
const mockDeleteRole = jest.fn()

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

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: () => true,
  }),
}))

jest.mock('~/hooks/useRolesList', () => ({
  useRolesList: () => ({
    roles: [
      {
        id: '1',
        name: 'Admin',
        description: 'Admin role',
        admin: true,
        memberships: [{ id: '1', name: 'John', email: 'john@test.com' }],
        permissions: [],
      },
      {
        id: '2',
        name: 'custom-role',
        description: 'Custom role',
        admin: false,
        memberships: [],
        permissions: ['plansView'],
      },
    ],
    isLoadingRoles: false,
    deleteRole: mockDeleteRole,
  }),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  generatePath: (path: string, params?: Record<string, string>) => {
    if (params) {
      return Object.entries(params).reduce(
        (acc, [key, value]) => acc.replace(`:${key}`, value),
        path,
      )
    }
    return path
  },
}))

describe('RolesList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasOrganizationPremiumAddon.mockReturnValue(true)
  })

  it('renders page header', async () => {
    await act(() => render(<RolesList />))

    expect(screen.getAllByText('text_1765448879791epmkg4xijkn')).toHaveLength(1)
  })

  it('renders roles table with correct columns', async () => {
    await act(() => render(<RolesList />))

    expect(screen.getByText('text_1765464417018tezju4yvyoo')).toBeInTheDocument()
    expect(screen.getByText('text_1765464417018n3moulidii0')).toBeInTheDocument()
    expect(screen.getByText('text_17654644170188lrzkfyhtkf')).toBeInTheDocument()
  })

  it('renders system role with translated name', async () => {
    await act(() => render(<RolesList />))

    expect(screen.getByText('text_664f035a68227f00e261b7ee')).toBeInTheDocument()
  })

  it('renders custom role with original name', async () => {
    await act(() => render(<RolesList />))

    expect(screen.getByText('custom-role')).toBeInTheDocument()
  })

  it('displays member count for each role', async () => {
    await act(() => render(<RolesList />))

    expect(screen.getByText('1')).toBeInTheDocument()
    expect(screen.getByText('0')).toBeInTheDocument()
  })

  it('displays role type status', async () => {
    await act(() => render(<RolesList />))

    expect(screen.getByText('text_1765464506554l3g5v7dctfv')).toBeInTheDocument()
    expect(screen.getByText('text_6641dd21c0cffd005b5e2a8b')).toBeInTheDocument()
  })

  it('renders action menu button for each role', async () => {
    await act(() => render(<RolesList />))

    const actionButtons = screen.getAllByTestId('open-action-button')

    expect(actionButtons.length).toBeGreaterThan(0)
  })

  describe('with premium addon', () => {
    beforeEach(() => {
      mockHasOrganizationPremiumAddon.mockReturnValue(true)
    })

    it('renders create button as link', async () => {
      await act(() => render(<RolesList />))

      const createButton = screen.getByText('text_1765530400261k7yl3n4kk8h')

      expect(createButton).toBeInTheDocument()
      expect(createButton.closest('a')).toHaveAttribute(
        'href',
        '/settings/team-and-security/roles/create',
      )
    })
  })

  describe('without premium addon', () => {
    beforeEach(() => {
      mockHasOrganizationPremiumAddon.mockReturnValue(false)
    })

    it('renders create button with sparkles icon as button not link', async () => {
      await act(() => render(<RolesList />))

      const createButton = screen.getByText('text_1765530400261k7yl3n4kk8h')

      expect(createButton).toBeInTheDocument()
      // Should be a button, not a link
      expect(createButton.closest('button')).toBeInTheDocument()
      expect(createButton.closest('a')).not.toBeInTheDocument()
    })
  })
})
