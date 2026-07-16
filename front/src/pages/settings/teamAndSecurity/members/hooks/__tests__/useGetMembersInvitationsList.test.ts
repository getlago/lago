import { renderHook, waitFor } from '@testing-library/react'

import { GetInvitesDocument } from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { useGetMembersInvitationList } from '../useGetMembersInvitationsList'

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

const createWrapper = (mocks: TestMocksType) => {
  return ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })
}

describe('useGetMembersInvitationList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns loading state initially', () => {
    const { result } = renderHook(() => useGetMembersInvitationList(), {
      wrapper: createWrapper([invitesListMock]),
    })

    expect(result.current.invitesLoading).toBe(true)
    expect(result.current.invitations).toEqual([])
  })

  it('returns invitations after loading', async () => {
    const { result } = renderHook(() => useGetMembersInvitationList(), {
      wrapper: createWrapper([invitesListMock]),
    })

    await waitFor(() => {
      expect(result.current.invitesLoading).toBe(false)
    })

    expect(result.current.invitations).toHaveLength(2)
    expect(result.current.invitations[0]?.email).toBe('test1@example.com')
    expect(result.current.invitations[1]?.email).toBe('test2@example.com')
  })

  it('returns metadata', async () => {
    const { result } = renderHook(() => useGetMembersInvitationList(), {
      wrapper: createWrapper([invitesListMock]),
    })

    await waitFor(() => {
      expect(result.current.invitesLoading).toBe(false)
    })

    expect(result.current.metadata).toEqual({
      __typename: 'CollectionMetadata',
      currentPage: 1,
      totalPages: 1,
      totalCount: 2,
    })
  })

  it('returns empty array when no invitations', async () => {
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

    const { result } = renderHook(() => useGetMembersInvitationList(), {
      wrapper: createWrapper([emptyMock]),
    })

    await waitFor(() => {
      expect(result.current.invitesLoading).toBe(false)
    })

    expect(result.current.invitations).toEqual([])
  })

  it('returns error when query fails', async () => {
    const errorMock = {
      request: {
        query: GetInvitesDocument,
        variables: { limit: 20 },
      },
      error: new Error('Failed to fetch invitations'),
    }

    const { result } = renderHook(() => useGetMembersInvitationList(), {
      wrapper: createWrapper([errorMock]),
    })

    await waitFor(() => {
      expect(result.current.invitesLoading).toBe(false)
    })

    expect(result.current.invitesError).toBeDefined()
  })

  it('exposes refetch function', async () => {
    const { result } = renderHook(() => useGetMembersInvitationList(), {
      wrapper: createWrapper([invitesListMock]),
    })

    await waitFor(() => {
      expect(result.current.invitesLoading).toBe(false)
    })

    expect(typeof result.current.invitesRefetch).toBe('function')
  })

  it('exposes fetchMore function', async () => {
    const { result } = renderHook(() => useGetMembersInvitationList(), {
      wrapper: createWrapper([invitesListMock]),
    })

    await waitFor(() => {
      expect(result.current.invitesLoading).toBe(false)
    })

    expect(typeof result.current.invitesFetchMore).toBe('function')
  })
})
