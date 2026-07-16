import { renderHook, waitFor } from '@testing-library/react'

import { GetAllMembersForFilterDocument } from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { useGetAllMembers } from '../useGetAllMembers'

const mockMemberships = [
  {
    __typename: 'Membership' as const,
    id: 'membership-1',
    user: {
      __typename: 'User' as const,
      id: 'user-1',
      email: 'alice@example.com',
    },
  },
  {
    __typename: 'Membership' as const,
    id: 'membership-2',
    user: {
      __typename: 'User' as const,
      id: 'user-2',
      email: 'bob@example.com',
    },
  },
]

const membersMock: TestMocksType = [
  {
    request: {
      query: GetAllMembersForFilterDocument,
      variables: { limit: 500 },
    },
    result: {
      data: {
        memberships: {
          __typename: 'MembershipCollection',
          collection: mockMemberships,
        },
      },
    },
  },
]

const emptyMembersMock: TestMocksType = [
  {
    request: {
      query: GetAllMembersForFilterDocument,
      variables: { limit: 500 },
    },
    result: {
      data: {
        memberships: {
          __typename: 'MembershipCollection',
          collection: [],
        },
      },
    },
  },
]

const createWrapper = (mocks: TestMocksType) => {
  return ({ children }: { children: React.ReactNode }) => AllTheProviders({ children, mocks })
}

describe('useGetAllMembers', () => {
  describe('GIVEN the query returns members', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should return the memberships collection', async () => {
        const { result } = renderHook(() => useGetAllMembers(), {
          wrapper: createWrapper(membersMock),
        })

        await waitFor(() => {
          expect(result.current.loading).toBe(false)
        })

        expect(result.current.memberships).toHaveLength(2)
        expect(result.current.memberships[0]).toEqual(
          expect.objectContaining({
            id: 'membership-1',
            user: expect.objectContaining({
              id: 'user-1',
              email: 'alice@example.com',
            }),
          }),
        )
        expect(result.current.memberships[1]).toEqual(
          expect.objectContaining({
            id: 'membership-2',
            user: expect.objectContaining({
              id: 'user-2',
              email: 'bob@example.com',
            }),
          }),
        )
      })
    })
  })

  describe('GIVEN the query returns no members', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should return an empty array', async () => {
        const { result } = renderHook(() => useGetAllMembers(), {
          wrapper: createWrapper(emptyMembersMock),
        })

        await waitFor(() => {
          expect(result.current.loading).toBe(false)
        })

        expect(result.current.memberships).toEqual([])
      })
    })
  })

  describe('GIVEN the query is loading', () => {
    describe('WHEN the hook is first called', () => {
      it('THEN should return loading true and empty memberships', () => {
        const { result } = renderHook(() => useGetAllMembers(), {
          wrapper: createWrapper(membersMock),
        })

        expect(result.current.loading).toBe(true)
        expect(result.current.memberships).toEqual([])
      })
    })
  })
})
