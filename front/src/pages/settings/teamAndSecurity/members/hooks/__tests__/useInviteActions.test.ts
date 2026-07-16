import { act, renderHook, waitFor } from '@testing-library/react'

import {
  CreateInviteDocument,
  RevokeInviteDocument,
  UpdateInviteRoleDocument,
} from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { useInviteActions } from '../useInviteActions'

const mockAddToast = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (params: unknown) => mockAddToast(params),
}))

const createWrapper = (mocks: TestMocksType) => {
  return ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })
}

describe('useInviteActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('createInvite', () => {
    it('returns createInvite function', () => {
      const { result } = renderHook(() => useInviteActions(), {
        wrapper: createWrapper([]),
      })

      expect(typeof result.current.createInvite).toBe('function')
    })

    it('sets inviteToken on successful creation', async () => {
      const createInviteMock = {
        request: {
          query: CreateInviteDocument,
          variables: {
            input: {
              email: 'test@example.com',
              roles: ['admin'],
            },
          },
        },
        result: {
          data: {
            createInvite: {
              __typename: 'Invite',
              id: 'invite-1',
              token: 'new-token-123',
              email: 'test@example.com',
              roles: ['admin'],
              organization: {
                __typename: 'Organization',
                id: 'org-1',
                name: 'Test Org',
              },
            },
          },
        },
      }

      const { result } = renderHook(() => useInviteActions(), {
        wrapper: createWrapper([createInviteMock]),
      })

      expect(result.current.inviteToken).toBe('')

      await act(async () => {
        await result.current.createInvite({
          variables: {
            input: {
              email: 'test@example.com',
              roles: ['admin'],
            },
          },
        })
      })

      await waitFor(() => {
        expect(result.current.inviteToken).toBe('new-token-123')
      })
    })

    it('exposes setInviteToken function', () => {
      const { result } = renderHook(() => useInviteActions(), {
        wrapper: createWrapper([]),
      })

      expect(typeof result.current.setInviteToken).toBe('function')
    })
  })

  describe('updateInviteRole', () => {
    it('returns updateInviteRole function', () => {
      const { result } = renderHook(() => useInviteActions(), {
        wrapper: createWrapper([]),
      })

      expect(typeof result.current.updateInviteRole).toBe('function')
    })

    it('shows success toast on successful update', async () => {
      const updateInviteRoleMock = {
        request: {
          query: UpdateInviteRoleDocument,
          variables: {
            input: {
              id: 'invite-1',
              roles: ['finance'],
            },
          },
        },
        result: {
          data: {
            updateInvite: {
              __typename: 'Invite',
              id: 'invite-1',
              roles: ['finance'],
              email: 'test@example.com',
            },
          },
        },
      }

      const { result } = renderHook(() => useInviteActions(), {
        wrapper: createWrapper([updateInviteRoleMock]),
      })

      await act(async () => {
        await result.current.updateInviteRole({
          variables: {
            input: {
              id: 'invite-1',
              roles: ['finance'],
            },
          },
        })
      })

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith({
          severity: 'success',
          translateKey: 'text_664f3562b7caf600e5246883',
        })
      })
    })
  })

  describe('revokeInvite', () => {
    it('returns revokeInvite function', () => {
      const { result } = renderHook(() => useInviteActions(), {
        wrapper: createWrapper([]),
      })

      expect(typeof result.current.revokeInvite).toBe('function')
    })

    it('shows success toast on successful revoke', async () => {
      const revokeInviteMock = {
        request: {
          query: RevokeInviteDocument,
          variables: {
            input: {
              id: 'invite-1',
            },
          },
        },
        result: {
          data: {
            revokeInvite: {
              __typename: 'Invite',
              id: 'invite-1',
            },
          },
        },
      }

      const { result } = renderHook(() => useInviteActions(), {
        wrapper: createWrapper([revokeInviteMock]),
      })

      await act(async () => {
        await result.current.revokeInvite({
          variables: {
            input: {
              id: 'invite-1',
            },
          },
        })
      })

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith({
          translateKey: 'text_63208c711ce25db781407523',
          severity: 'success',
        })
      })
    })
  })
})
