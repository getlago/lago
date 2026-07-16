import { renderHook, waitFor } from '@testing-library/react'

import { GetMembersDocument } from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { useGetMembersList } from '../useGetMembersList'

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

const createWrapper = (mocks: TestMocksType) => {
  return ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })
}

describe('useGetMembersList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns loading state initially', () => {
    const { result } = renderHook(() => useGetMembersList(), {
      wrapper: createWrapper([membersListMock]),
    })

    expect(result.current.membersLoading).toBe(true)
    expect(result.current.members).toEqual([])
  })

  it('returns members after loading', async () => {
    const { result } = renderHook(() => useGetMembersList(), {
      wrapper: createWrapper([membersListMock]),
    })

    await waitFor(() => {
      expect(result.current.membersLoading).toBe(false)
    })

    expect(result.current.members).toHaveLength(2)
    expect(result.current.members[0]?.user.email).toBe('admin@example.com')
    expect(result.current.members[1]?.user.email).toBe('finance@example.com')
  })

  it('returns metadata with adminCount', async () => {
    const { result } = renderHook(() => useGetMembersList(), {
      wrapper: createWrapper([membersListMock]),
    })

    await waitFor(() => {
      expect(result.current.membersLoading).toBe(false)
    })

    expect(result.current.metadata).toEqual({
      __typename: 'MembershipsCollectionMetadata',
      currentPage: 1,
      totalPages: 1,
      totalCount: 2,
      adminCount: 1,
    })
  })

  it('returns empty array when no members', async () => {
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

    const { result } = renderHook(() => useGetMembersList(), {
      wrapper: createWrapper([emptyMock]),
    })

    await waitFor(() => {
      expect(result.current.membersLoading).toBe(false)
    })

    expect(result.current.members).toEqual([])
  })

  it('returns error when query fails', async () => {
    const errorMock = {
      request: {
        query: GetMembersDocument,
        variables: { limit: 20 },
      },
      error: new Error('Failed to fetch members'),
    }

    const { result } = renderHook(() => useGetMembersList(), {
      wrapper: createWrapper([errorMock]),
    })

    await waitFor(() => {
      expect(result.current.membersLoading).toBe(false)
    })

    expect(result.current.membersError).toBeDefined()
  })

  it('exposes refetch function', async () => {
    const { result } = renderHook(() => useGetMembersList(), {
      wrapper: createWrapper([membersListMock]),
    })

    await waitFor(() => {
      expect(result.current.membersLoading).toBe(false)
    })

    expect(typeof result.current.membersRefetch).toBe('function')
  })

  it('exposes fetchMore function', async () => {
    const { result } = renderHook(() => useGetMembersList(), {
      wrapper: createWrapper([membersListMock]),
    })

    await waitFor(() => {
      expect(result.current.membersLoading).toBe(false)
    })

    expect(typeof result.current.membersFetchMore).toBe('function')
  })
})
