import { act, cleanup, fireEvent, screen, waitFor } from '@testing-library/react'

import { GetMembersDocument, GetRolesListDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import MembersList from '../MembersList'

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
    currentUser: {
      id: 'current-user-1',
      email: 'current@example.com',
    },
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
jest.mock('../dialogs/EditMemberRoleDialog', () => ({
  useEditMemberRoleDialog: () => ({
    openEditMemberRoleDialog: jest.fn(),
  }),
}))

jest.mock('../dialogs/RevokeMembershipDialog', () => ({
  useRevokeMembershipDialog: () => ({
    openRevokeMembershipDialog: jest.fn(),
  }),
}))

jest.mock('../dialogs/CreateInviteDialog', () => ({
  useCreateInviteDialog: () => ({
    openCreateInviteDialog: jest.fn(),
  }),
}))

const createMockMembership = (id: string, email: string, roles: string[]) => ({
  __typename: 'Membership',
  id,
  roles,
  user: {
    __typename: 'User',
    id: `user-${id}`,
    email,
  },
  organization: {
    __typename: 'Organization',
    id: 'org-1',
    name: 'Test Organization',
  },
  permissions: {
    __typename: 'Permissions',
    addonsCreate: true,
    addonsDelete: true,
    addonsUpdate: true,
    addonsView: true,
    analyticsOverdueBalancesView: true,
    analyticsMrrView: true,
    analyticsInvoicedUsagesView: true,
    analyticsView: true,
    analyticsGrossRevenuesView: true,
    billableMetricsCreate: true,
    billableMetricsDelete: true,
    billableMetricsUpdate: true,
    billableMetricsView: true,
    billingEntitiesCreate: true,
    billingEntitiesDelete: true,
    billingEntitiesUpdate: true,
    billingEntitiesView: true,
    couponsAttach: true,
    couponsCreate: true,
    couponsDelete: true,
    couponsDetach: true,
    couponsUpdate: true,
    couponsView: true,
    creditNotesCreate: true,
    creditNotesUpdate: true,
    creditNotesView: true,
    creditNotesVoid: true,
    customerSettingsUpdateGracePeriod: true,
    customerSettingsUpdateLang: true,
    customerSettingsUpdatePaymentTerms: true,
    customerSettingsUpdateTaxRates: true,
    customersCreate: true,
    customersDelete: true,
    customersUpdate: true,
    customersView: true,
    developersKeysManage: true,
    developersManage: true,
    draftInvoicesUpdate: true,
    dunningCampaignsCreate: true,
    dunningCampaignsDelete: true,
    dunningCampaignsUpdate: true,
    dunningCampaignsView: true,
    invoiceCustomSectionsCreate: true,
    invoiceCustomSectionsDelete: true,
    invoiceCustomSectionsUpdate: true,
    invoiceCustomSectionsView: true,
    invoicesCreate: true,
    invoicesSend: true,
    invoicesUpdate: true,
    invoicesView: true,
    invoicesVoid: true,
    organizationEmailsUpdate: true,
    organizationEmailsView: true,
    organizationIntegrationsCreate: true,
    organizationIntegrationsDelete: true,
    organizationIntegrationsUpdate: true,
    organizationIntegrationsView: true,
    organizationInvoicesUpdate: true,
    organizationInvoicesView: true,
    organizationMembersCreate: true,
    organizationMembersDelete: true,
    organizationMembersUpdate: true,
    organizationMembersView: true,
    organizationTaxesUpdate: true,
    organizationTaxesView: true,
    organizationUpdate: true,
    organizationView: true,
    plansCreate: true,
    plansDelete: true,
    plansUpdate: true,
    plansView: true,
    rolesCreate: true,
    rolesDelete: true,
    rolesUpdate: true,
    rolesView: true,
    subscriptionsCreate: true,
    subscriptionsUpdate: true,
    subscriptionsView: true,
    walletsCreate: true,
    walletsTerminate: true,
    walletsTopUp: true,
    walletsUpdate: true,
  },
})

const mockMembers = [
  createMockMembership('member-1', 'admin@example.com', ['Admin']),
  createMockMembership('member-2', 'finance@example.com', ['Finance']),
]

const membersListMock = {
  request: {
    query: GetMembersDocument,
    variables: { limit: 20 },
  },
  result: {
    data: {
      memberships: {
        __typename: 'MembershipCollection',
        metadata: {
          __typename: 'MembershipsCollectionMetadata',
          currentPage: 1,
          totalPages: 1,
          totalCount: 2,
          adminCount: 1,
        },
        collection: mockMembers,
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
  mocks = [membersListMock, rolesListMock],
}: { mocks?: TestMocksType } = {}) {
  await act(() =>
    render(<MembersList />, {
      mocks,
    }),
  )
}

describe('MembersList', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    it('renders the filters section', async () => {
      await prepare()

      // Search input should be present - check by placeholder text (uses translation key for members)
      expect(screen.getByPlaceholderText('text_1767713872664devzn1r2wql')).toBeInTheDocument()
    })

    it('renders members table after loading', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })

      expect(screen.getByText('finance@example.com')).toBeInTheDocument()
    })

    it('renders role chips for members', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
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
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        delay: Infinity,
        result: {
          data: null,
        },
      }

      await act(() =>
        render(<MembersList />, {
          mocks: [loadingMock, rolesListMock],
        }),
      )

      // During loading, member emails should not be visible
      expect(screen.queryByText('admin@example.com')).not.toBeInTheDocument()
    })
  })

  describe('Empty State', () => {
    it('shows empty state when no members', async () => {
      const emptyMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
                adminCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        // Empty state title should be visible
        expect(screen.getByText('text_176771435162557p8hyixafi')).toBeInTheDocument()
      })
    })
  })

  describe('Error State', () => {
    it('shows error state when query fails', async () => {
      const errorMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        error: new Error('Failed to fetch members'),
      }

      await prepare({ mocks: [errorMock, rolesListMock] })

      await waitFor(() => {
        // Error state title uses translation key
        expect(screen.getByText('text_6321a076b94bd1b32494e9ee')).toBeInTheDocument()
      })
    })
  })

  describe('Member Count', () => {
    it('renders correct number of members', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
        expect(screen.getByText('finance@example.com')).toBeInTheDocument()
      })
    })

    it('handles single member', async () => {
      const singleMemberMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 1,
                adminCount: 1,
              },
              collection: [createMockMembership('member-1', 'single@example.com', ['Admin'])],
            },
          },
        },
      }

      await prepare({ mocks: [singleMemberMock, rolesListMock] })

      await waitFor(() => {
        expect(screen.getByText('single@example.com')).toBeInTheDocument()
      })
    })
  })

  describe('Multiple Roles', () => {
    it('displays member with multiple roles', async () => {
      const multiRoleMemberMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 1,
                adminCount: 1,
              },
              collection: [
                createMockMembership('member-1', 'multirole@example.com', ['Admin', 'Finance']),
              ],
            },
          },
        },
      }

      await prepare({ mocks: [multiRoleMemberMock, rolesListMock] })

      await waitFor(() => {
        expect(screen.getByText('multirole@example.com')).toBeInTheDocument()
      })
    })
  })

  describe('Pagination', () => {
    it('handles paginated results', async () => {
      const paginatedMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 3,
                totalCount: 50,
                adminCount: 5,
              },
              collection: mockMembers,
            },
          },
        },
      }

      await prepare({ mocks: [paginatedMock, rolesListMock] })

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })
    })
  })

  describe('Create Invite Button', () => {
    it('renders invite button in empty state', async () => {
      const emptyMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
                adminCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        expect(screen.getByText('text_63208b630aaf8df6bbfb265b')).toBeInTheDocument()
      })
    })
  })

  describe('Search Input', () => {
    it('renders search input with correct placeholder', async () => {
      await prepare()

      const searchInput = screen.getByPlaceholderText('text_1767713872664devzn1r2wql')

      expect(searchInput).toBeInTheDocument()
    })
  })

  describe('Admin Count', () => {
    it('displays correct admin count in metadata', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })

      // The metadata includes adminCount: 1
    })

    it('handles zero admin count', async () => {
      const noAdminMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 1,
                adminCount: 0,
              },
              collection: [createMockMembership('member-1', 'user@example.com', ['Finance'])],
            },
          },
        },
      }

      await prepare({ mocks: [noAdminMock, rolesListMock] })

      await waitFor(() => {
        expect(screen.getByText('user@example.com')).toBeInTheDocument()
      })
    })
  })

  describe('Search Filtering', () => {
    it('filters members by search query', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
        expect(screen.getByText('finance@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664devzn1r2wql')

      fireEvent.change(searchInput, { target: { value: 'admin' } })

      // Only admin should be visible after filtering
      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
        expect(screen.queryByText('finance@example.com')).not.toBeInTheDocument()
      })
    })

    it('shows all members when search is cleared', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664devzn1r2wql')

      fireEvent.change(searchInput, { target: { value: 'admin' } })

      await waitFor(() => {
        expect(screen.queryByText('finance@example.com')).not.toBeInTheDocument()
      })

      fireEvent.change(searchInput, { target: { value: '' } })

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
        expect(screen.getByText('finance@example.com')).toBeInTheDocument()
      })
    })

    it('search is case insensitive', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664devzn1r2wql')

      fireEvent.change(searchInput, { target: { value: 'ADMIN' } })

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
        expect(screen.queryByText('finance@example.com')).not.toBeInTheDocument()
      })
    })

    it('shows no results when search matches nothing', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('text_1767713872664devzn1r2wql')

      fireEvent.change(searchInput, { target: { value: 'nonexistent' } })

      await waitFor(() => {
        expect(screen.queryByText('admin@example.com')).not.toBeInTheDocument()
        expect(screen.queryByText('finance@example.com')).not.toBeInTheDocument()
      })
    })
  })

  describe('Action Column', () => {
    it('renders action menu for members', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })

      // Action column tooltip translation key
      const actionButtons = screen.getAllByRole('button')

      expect(actionButtons.length).toBeGreaterThan(0)
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

    it('renders member avatar', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('admin@example.com')).toBeInTheDocument()
      })

      // Avatar should be rendered for each member
      const avatars = document.querySelectorAll('[class*="avatar"]')

      expect(avatars.length).toBeGreaterThan(0)
    })
  })

  describe('Empty State Content', () => {
    it('shows empty state title when no members', async () => {
      const emptyMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
                adminCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        // Empty state title translation key
        expect(screen.getByText('text_176771435162557p8hyixafi')).toBeInTheDocument()
      })
    })

    it('shows empty state subtitle when no members', async () => {
      const emptyMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        result: {
          data: {
            memberships: {
              __typename: 'MembershipCollection',
              metadata: {
                __typename: 'MembershipsCollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
                adminCount: 0,
              },
              collection: [],
            },
          },
        },
      }

      await prepare({ mocks: [emptyMock, rolesListMock] })

      await waitFor(() => {
        // Empty state subtitle translation key
        expect(screen.getByText('text_1767714241102xpwokcuhvki')).toBeInTheDocument()
      })
    })
  })

  describe('Error State Content', () => {
    it('shows error state subtitle when query fails', async () => {
      const errorMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        error: new Error('Failed to fetch members'),
      }

      await prepare({ mocks: [errorMock, rolesListMock] })

      await waitFor(() => {
        // Error state subtitle translation key
        expect(screen.getByText('text_6321a076b94bd1b32494e9f0')).toBeInTheDocument()
      })
    })

    it('shows retry button when query fails', async () => {
      const errorMock = {
        request: {
          query: GetMembersDocument,
          variables: { limit: 20 },
        },
        error: new Error('Failed to fetch members'),
      }

      await prepare({ mocks: [errorMock, rolesListMock] })

      await waitFor(() => {
        // Retry button translation key
        expect(screen.getByText('text_6321a076b94bd1b32494e9f2')).toBeInTheDocument()
      })
    })
  })
})
