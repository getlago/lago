import { renderHook, waitFor } from '@testing-library/react'

import { RoleItem } from '~/core/constants/roles'
import { GetRolesListDocument } from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { allRoles } from './mock/allRoles'

import { useRolesList } from '../useRolesList'

const mocks: TestMocksType = [
  {
    request: {
      query: GetRolesListDocument,
    },
    result: {
      data: {
        roles: allRoles,
      },
    },
  },
]

const wrapper = ({ children }: { children: React.ReactNode }) =>
  AllTheProviders({
    children,
    mocks,
    forceTypenames: true,
  })

describe('useRolesList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns loading state initially', () => {
    const { result } = renderHook(() => useRolesList(), { wrapper })

    expect(result.current.isLoadingRoles).toBe(true)
    expect(result.current.roles).toEqual([])
  })

  it('returns roles after loading', async () => {
    const { result } = renderHook(() => useRolesList(), { wrapper })

    await waitFor(() => {
      expect(result.current.isLoadingRoles).toBe(false)
    })

    expect(result.current.roles).toHaveLength(allRoles.length)
  })

  it('returns all three system roles', async () => {
    const { result } = renderHook(() => useRolesList(), { wrapper })

    await waitFor(() => {
      expect(result.current.isLoadingRoles).toBe(false)
    })

    const roleNames = result.current.roles.map((r: RoleItem) => r?.name)

    expect(roleNames).toContain('Admin')
    expect(roleNames).toContain('Manager')
    expect(roleNames).toContain('Finance')
  })

  describe('Ordering', () => {
    it('sorts system roles in the correct order: Admin, Finance, Manager', async () => {
      const { result } = renderHook(() => useRolesList(), { wrapper })

      await waitFor(() => {
        expect(result.current.isLoadingRoles).toBe(false)
      })

      const roleNames = result.current.roles.map((r: RoleItem) => r?.name)

      // System roles should be ordered: Admin, Finance, Manager
      expect(roleNames[0]).toBe('Admin')
      expect(roleNames[1]).toBe('Finance')
      expect(roleNames[2]).toBe('Manager')
    })

    it('places custom roles after system roles', async () => {
      const customRole: RoleItem = {
        __typename: 'Role',
        id: 'custom-1',
        name: 'Custom Role',
        description: 'A custom role',
        admin: false,
        code: 'CUSTOM',
        memberships: [],
        permissions: [],
      }

      const rolesWithCustom = [...allRoles, customRole]

      const customMocks: TestMocksType = [
        {
          request: {
            query: GetRolesListDocument,
          },
          result: {
            data: {
              roles: rolesWithCustom,
            },
          },
        },
      ]

      const customWrapper = ({ children }: { children: React.ReactNode }) =>
        AllTheProviders({
          children,
          mocks: customMocks,
          forceTypenames: true,
        })

      const { result } = renderHook(() => useRolesList(), { wrapper: customWrapper })

      await waitFor(() => {
        expect(result.current.isLoadingRoles).toBe(false)
      })

      const roleNames = result.current.roles.map((r: RoleItem) => r?.name)

      // System roles should come first in order, then custom role
      expect(roleNames[0]).toBe('Admin')
      expect(roleNames[1]).toBe('Finance')
      expect(roleNames[2]).toBe('Manager')
      expect(roleNames[3]).toBe('Custom Role')
    })

    it('maintains order when roles come in different order from API', async () => {
      // Reverse the order from API
      const reversedRoles = [...allRoles].reverse()

      const reversedMocks: TestMocksType = [
        {
          request: {
            query: GetRolesListDocument,
          },
          result: {
            data: {
              roles: reversedRoles,
            },
          },
        },
      ]

      const reversedWrapper = ({ children }: { children: React.ReactNode }) =>
        AllTheProviders({
          children,
          mocks: reversedMocks,
          forceTypenames: true,
        })

      const { result } = renderHook(() => useRolesList(), { wrapper: reversedWrapper })

      await waitFor(() => {
        expect(result.current.isLoadingRoles).toBe(false)
      })

      const roleNames = result.current.roles.map((r: RoleItem) => r?.name)

      // Should still be in the correct order regardless of API order
      expect(roleNames[0]).toBe('Admin')
      expect(roleNames[1]).toBe('Finance')
      expect(roleNames[2]).toBe('Manager')
    })

    it('handles only custom roles correctly', async () => {
      const customRoles: RoleItem[] = [
        {
          __typename: 'Role',
          id: 'custom-1',
          name: 'Custom A',
          description: 'Custom role A',
          admin: false,
          code: 'CUSTOM_A',
          memberships: [],
          permissions: [],
        },
        {
          __typename: 'Role',
          id: 'custom-2',
          name: 'Custom B',
          description: 'Custom role B',
          admin: false,
          code: 'CUSTOM_B',
          memberships: [],
          permissions: [],
        },
      ]

      const customOnlyMocks: TestMocksType = [
        {
          request: {
            query: GetRolesListDocument,
          },
          result: {
            data: {
              roles: customRoles,
            },
          },
        },
      ]

      const customOnlyWrapper = ({ children }: { children: React.ReactNode }) =>
        AllTheProviders({
          children,
          mocks: customOnlyMocks,
          forceTypenames: true,
        })

      const { result } = renderHook(() => useRolesList(), { wrapper: customOnlyWrapper })

      await waitFor(() => {
        expect(result.current.isLoadingRoles).toBe(false)
      })

      // Custom roles should maintain their original order
      expect(result.current.roles).toHaveLength(2)
      expect(result.current.roles[0]?.name).toBe('Custom A')
      expect(result.current.roles[1]?.name).toBe('Custom B')
    })
  })
})
