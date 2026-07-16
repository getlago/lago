import { renderHook, waitFor } from '@testing-library/react'

import { GetRoleDocument, PermissionEnum } from '~/generated/graphql'
import { allRoles } from '~/hooks/__tests__/mock/allRoles'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { useRoleDetails } from '../useRoleDetails'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: () => true,
  }),
}))

const createWrapper = (roleId: string) => {
  const role = allRoles.find((r) => r?.id === roleId)

  const mocks: TestMocksType = [
    {
      request: {
        query: GetRoleDocument,
        variables: { id: roleId },
      },
      result: {
        data: {
          role: role ?? null,
        },
      },
    },
  ]

  return ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })
}

describe('useRoleDetails', () => {
  it('returns loading state initially', () => {
    const { result } = renderHook(() => useRoleDetails({ roleId: '1' }), {
      wrapper: createWrapper('1'),
    })

    expect(result.current.isLoadingRole).toBe(true)
    expect(result.current.role).toBeUndefined()
  })

  it('returns role data after loading', async () => {
    const { result } = renderHook(() => useRoleDetails({ roleId: '1' }), {
      wrapper: createWrapper('1'),
    })

    await waitFor(() => {
      expect(result.current.isLoadingRole).toBe(false)
    })

    expect(result.current.role?.id).toBe('1')
    expect(result.current.role?.name).toBe('Admin')
  })

  it('returns undefined role when roleId is undefined', async () => {
    const mocks: TestMocksType = []
    const wrapper = ({ children }: { children: React.ReactNode }) =>
      AllTheProviders({
        children,
        mocks,
        forceTypenames: true,
      })

    const { result } = renderHook(() => useRoleDetails({ roleId: undefined }), {
      wrapper,
    })

    await waitFor(() => {
      expect(result.current.isLoadingRole).toBe(false)
    })

    expect(result.current.role).toBeUndefined()
  })

  describe('system roles', () => {
    it('identifies Admin as a system role', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '1' }), {
        wrapper: createWrapper('1'),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('Admin')
      expect(result.current.isSystem).toBe(true)
    })

    it('identifies Manager as a system role', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '2' }), {
        wrapper: createWrapper('2'),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('Manager')
      expect(result.current.isSystem).toBe(true)
    })

    it('identifies Finance as a system role', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '3' }), {
        wrapper: createWrapper('3'),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('Finance')
      expect(result.current.isSystem).toBe(true)
    })
  })

  describe('canBeDeleted', () => {
    it('returns true when role has no memberships', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '2' }), {
        wrapper: createWrapper('2'),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('Manager')
      expect(result.current.role?.memberships).toHaveLength(0)
      expect(result.current.canBeDeleted).toBe(true)
    })

    it('returns false when role has memberships', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '1' }), {
        wrapper: createWrapper('1'),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('Admin')
      expect(result.current.role?.memberships.length).toBeGreaterThan(0)
      expect(result.current.canBeDeleted).toBe(false)
    })
  })

  describe('custom roles', () => {
    const customRoleWithoutMembers = {
      __typename: 'Role' as const,
      id: '100',
      name: 'custom-role',
      description: 'A custom role',
      admin: false,
      memberships: [],
      permissions: [PermissionEnum.PlansView],
    }

    const customRoleWithMembers = {
      __typename: 'Role' as const,
      id: '101',
      name: 'custom-role-with-members',
      description: 'A custom role with members',
      admin: false,
      memberships: [
        {
          __typename: 'Membership' as const,
          id: '10',
          user: {
            __typename: 'User' as const,
            id: '10',
            email: 'test@example.com',
          },
        },
      ],
      permissions: [PermissionEnum.PlansView],
    }

    const createCustomRoleWrapper = (
      role: typeof customRoleWithoutMembers | typeof customRoleWithMembers,
    ) => {
      const mocks: TestMocksType = [
        {
          request: {
            query: GetRoleDocument,
            variables: { id: role.id },
          },
          result: {
            data: {
              role,
            },
          },
        },
      ]

      return ({ children }: { children: React.ReactNode }) =>
        AllTheProviders({
          children,
          mocks,
          forceTypenames: true,
        })
    }

    it('identifies custom role as not a system role', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '100' }), {
        wrapper: createCustomRoleWrapper(customRoleWithoutMembers),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('custom-role')
      expect(result.current.isSystem).toBe(false)
    })

    it('allows deleting custom role without members', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '100' }), {
        wrapper: createCustomRoleWrapper(customRoleWithoutMembers),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('custom-role')
      expect(result.current.canBeDeleted).toBe(true)
    })

    it('does not allow deleting custom role with members', async () => {
      const { result } = renderHook(() => useRoleDetails({ roleId: '101' }), {
        wrapper: createCustomRoleWrapper(customRoleWithMembers),
      })

      await waitFor(() => {
        expect(result.current.isLoadingRole).toBe(false)
      })

      expect(result.current.role?.name).toBe('custom-role-with-members')
      expect(result.current.canBeDeleted).toBe(false)
    })
  })
})
