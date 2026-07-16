import { act, cleanup, fireEvent, screen, waitFor } from '@testing-library/react'

import { GetInvitesDocument, GetRolesListDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import MembersInvitationList from '../MembersInvitationList'

// Mock IntersectionObserver for jsdom
const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})
window.IntersectionObserver = mockIntersectionObserver

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: () => true,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useRolesList', () => ({
  useRolesList: () => ({
    roles: [
      {
        id: 'role-1',
        name: 'Admin',
        code: 'admin',
        description: 'Administrator role',
        admin: true,
        memberships: [],
        permissions: [],
      },
      {
        id: 'role-2',
        name: 'Finance',
        code: 'finance',
        description: 'Finance role',
        admin: false,
        memberships: [],
        permissions: [],
      },
    ],
    isLoadingRoles: false,
  }),
}))

// Mock dialog components to avoid complexity
jest.mock('../dialogs/EditInviteRoleDialog', () => ({
  useEditInviteRoleDialog: () => ({
    openEditInviteRoleDialog: jest.fn(),
  }),
}))

jest.mock('../dialogs/RevokeInviteDialog', () => ({
  useRevokeInviteDialog: () => ({
    openRevokeInviteDialog: jest.fn(),
  }),
}))

jest.mock('../dialogs/CreateInviteDialog', () => ({
  useCreateInviteDialog: () => ({
    openCreateInviteDialog: jest.fn(),
  }),
}))

const mockInvitations = [
  {
    __typename: 'Invite',
    id: 'invite-1',
    email: 'test1@example.com',
    token: 'token-1',
    roles: ['admin'],
    organization: {
      __typename: 'Organization',
      id: 'org-1',
      name: 'Test Organization',
    },
  },
  {
    __typename: 'Invite',
    id: 'invite-2',
    email: 'test2@example.com',
    token: 'token-2',
    roles: ['finance'],
    organization: {
      __typename: 'Organization',
      id: 'org-1',
      name: 'Test Organization',
    },
  },
]

const invitesListMock = {
  request: {
    query: GetInvitesDocument,
    variables: { limit: 20 },
  },
  result: {
    data: {
      invites: {
        __typename: 'InviteCollection',
        metadata: {
          __typename: 'CollectionMetadata',
          currentPage: 1,
          totalPages: 1,
          totalCount: 2,
        },
        collection: mockInvitations,
      },
    },
  },
}

const rolesListMock = {
  request: {
    query: GetRolesListDocument,
  },
  result: {
    data: {
      roles: [
        {
          __typename: 'Role',
          id: 'role-1',
          name: 'Admin',
          code: 'admin',
          description: 'Administrator role',
          permissions: [],
          admin: true,
          memberships: [],
        },
        {
          __typename: 'Role',
          id: 'role-2',
          name: 'Finance',
          code: 'finance',
          description: 'Finance role',
          permissions: [],
          admin: false,
          memberships: [],
        },
      ],
    },
  },
}

async function prepare({
  mocks = [invitesListMock, rolesListMock],
}: { mocks?: TestMocksType } = {}) {
  await act(() =>
    render(<MembersInvitationList />, {
      mocks,
    }),
  )
}

describe('MembersInvitationList', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    it('renders the filters section', async () => {
      await prepare()

      // Search input should be present - check by placeholder text (uses translation key)
      expect(screen.getByPlaceholderText('text_1767713872664lwivpxg5xlb')).toBeInTheDocument()
    })

    it('renders invitations table after loading', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })

      expect(screen.getByText('test2@example.com')).toBeInTheDocument()
    })

    it('renders role chips for invitations', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })

      // Role chips should be displayed - uses translation keys for system roles
      expect(screen.getByText('text_664f035a68227f00e261b7ee')).toBeInTheDocument() // Admin
      expect(screen.getByText('text_664f035a68227f00e261b7f2')).toBeInTheDocument() // Finance
    })
  })

  describe('Loading State', () => {
    it('shows loading state while fetching data', async () => {
      const loadingMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        delay: Infinity,
        result: {
          data: null,
        },
      }

      await act(() =>
        render(<MembersInvitationList />, {
          mocks: [loadingMock, rolesListMock],
        }),
      )

      // During loading, invitation emails should not be visible
      expect(screen.queryByText('test1@example.com')).not.toBeInTheDocument()
    })
  })

  describe('Empty State', () => {
    it('shows empty state when no invitations', async () => {
      const emptyMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            invites: {
              __typename: 'InviteCollection',
              metadata: {
                __typename: 'CollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        // Empty state title should be visible
        expect(screen.getByText('text_17671750294886x8eq8lizmt')).toBeInTheDocument()
      })
    })
  })

  describe('Error State', () => {
    it('shows error state when query fails', async () => {
      const errorMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        error: new Error('Failed to fetch invitations'),
      }

      await prepare({ mocks: [errorMock, rolesListMock] })

      await waitFor(() => {
        // Error state title uses translation key
        expect(screen.getByText('text_6321a076b94bd1b32494e9ee')).toBeInTheDocument()
      })
    })

    it('shows error state subtitle when query fails', async () => {
      const errorMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        error: new Error('Failed to fetch invitations'),
      }

      await prepare({ mocks: [errorMock, rolesListMock] })

      await waitFor(() => {
        // Error state subtitle translation key
        expect(screen.getByText('text_6321a076b94bd1b32494e9e8')).toBeInTheDocument()
      })
    })

    it('shows retry button when query fails', async () => {
      const errorMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        error: new Error('Failed to fetch invitations'),
      }

      await prepare({ mocks: [errorMock, rolesListMock] })

      await waitFor(() => {
        // Retry button translation key
        expect(screen.getByText('text_6321a076b94bd1b32494e9f2')).toBeInTheDocument()
      })
    })
  })

  describe('Search Filtering', () => {
    it('filters invitations by search query', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
        expect(screen.getByText('test2@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664lwivpxg5xlb')

      fireEvent.change(searchInput, { target: { value: 'test1' } })

      // Only test1 should be visible after filtering
      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
        expect(screen.queryByText('test2@example.com')).not.toBeInTheDocument()
      })
    })

    it('shows all invitations when search is cleared', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664lwivpxg5xlb')

      fireEvent.change(searchInput, { target: { value: 'test1' } })

      await waitFor(() => {
        expect(screen.queryByText('test2@example.com')).not.toBeInTheDocument()
      })

      fireEvent.change(searchInput, { target: { value: '' } })

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
        expect(screen.getByText('test2@example.com')).toBeInTheDocument()
      })
    })

    it('search is case insensitive', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664lwivpxg5xlb')

      fireEvent.change(searchInput, { target: { value: 'TEST1' } })

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
        expect(screen.queryByText('test2@example.com')).not.toBeInTheDocument()
      })
    })

    it('shows no results when search matches nothing', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664lwivpxg5xlb')

      fireEvent.change(searchInput, { target: { value: 'nonexistent' } })

      await waitFor(() => {
        expect(screen.queryByText('test1@example.com')).not.toBeInTheDocument()
        expect(screen.queryByText('test2@example.com')).not.toBeInTheDocument()
      })
    })
  })

  describe('Table Structure', () => {
    it('renders email column header', async () => {
      await prepare()

      await waitFor(() => {
        // Email column header translation key
        expect(screen.getByText('text_63208b630aaf8df6bbfb2655')).toBeInTheDocument()
      })
    })

    it('renders role column header', async () => {
      await prepare()

      await waitFor(() => {
        // Role column header translation key
        expect(screen.getByText('text_664f035a68227f00e261b7ec')).toBeInTheDocument()
      })
    })

    it('renders invitation avatar', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })

      // Avatar should be rendered for each invitation
      const avatars = document.querySelectorAll('[class*="avatar"]')

      expect(avatars.length).toBeGreaterThan(0)
    })
  })

  describe('Empty State Content', () => {
    it('shows empty state title when no invitations', async () => {
      const emptyMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            invites: {
              __typename: 'InviteCollection',
              metadata: {
                __typename: 'CollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        // Empty state title translation key (no pending invitations)
        expect(screen.getByText('text_17671750294886x8eq8lizmt')).toBeInTheDocument()
      })
    })

    it('shows empty state subtitle when no invitations', async () => {
      const emptyMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            invites: {
              __typename: 'InviteCollection',
              metadata: {
                __typename: 'CollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        // Empty state subtitle translation key
        expect(screen.getByText('text_1767175029488r5limdbdwm5')).toBeInTheDocument()
      })
    })

    it('shows invite button in empty state', async () => {
      const emptyMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            invites: {
              __typename: 'InviteCollection',
              metadata: {
                __typename: 'CollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        // Invite button translation key - use getAllByText since it appears in both MembersFilters and Table placeholder
        expect(screen.getAllByText('text_63208b630aaf8df6bbfb265b').length).toBeGreaterThanOrEqual(
          1,
        )
      })
    })
  })

  describe('Action Column', () => {
    it('renders action menu for invitations', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })

      // Action buttons should be present
      const actionButtons = screen.getAllByRole('button')

      expect(actionButtons.length).toBeGreaterThan(0)
    })
  })

  describe('Pagination', () => {
    it('handles paginated results', async () => {
      const paginatedMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            invites: {
              __typename: 'InviteCollection',
              metadata: {
                __typename: 'CollectionMetadata',
                currentPage: 1,
                totalPages: 3,
                totalCount: 50,
              },
              collection: mockInvitations,
            },
          },
        },
      }

      await prepare({ mocks: [paginatedMock, rolesListMock] })

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
      })
    })
  })

  describe('Invitation Count', () => {
    it('renders correct number of invitations', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
        expect(screen.getByText('test2@example.com')).toBeInTheDocument()
      })
    })

    it('handles single invitation', async () => {
      const singleInviteMock = {
        request: {
          query: GetInvitesDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            invites: {
              __typename: 'InviteCollection',
              metadata: {
                __typename: 'CollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 1,
              },
              collection: [mockInvitations[0]],
            },
          },
        },
      }

      await prepare({ mocks: [singleInviteMock, rolesListMock] })

      await waitFor(() => {
        expect(screen.getByText('test1@example.com')).toBeInTheDocument()
        expect(screen.queryByText('test2@example.com')).not.toBeInTheDocument()
      })
    })
  })
})
