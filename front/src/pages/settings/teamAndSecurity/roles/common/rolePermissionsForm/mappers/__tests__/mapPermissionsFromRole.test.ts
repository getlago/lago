import { RoleItem } from '~/core/constants/roles'
import { PermissionEnum } from '~/generated/graphql'
import { allPermissions } from '~/pages/settings/teamAndSecurity/roles/common/permissionsConst'

import { mapPermissionsFromRole } from '../mapPermissionsFromRole'

describe('mapPermissionsFromRole', () => {
  const createRole = (overrides: Partial<RoleItem> = {}): RoleItem => ({
    id: '1',
    name: 'test-role',
    description: 'Test description',
    admin: false,
    code: 'TEST_ROLE',
    memberships: [],
    permissions: [],
    ...overrides,
  })

  it('returns all permissions as false for undefined role', () => {
    const result = mapPermissionsFromRole(undefined)

    expect(Object.keys(result)).toHaveLength(allPermissions.length)
    Object.values(result).forEach((value) => {
      expect(value).toBe(false)
    })
  })

  it('returns all permissions as false for role with no permissions', () => {
    const role = createRole({ permissions: [] })
    const result = mapPermissionsFromRole(role)

    expect(Object.keys(result)).toHaveLength(allPermissions.length)
    Object.values(result).forEach((value) => {
      expect(value).toBe(false)
    })
  })

  it('returns all permissions as true for admin role', () => {
    const role = createRole({ admin: true, permissions: [] })
    const result = mapPermissionsFromRole(role)

    expect(Object.keys(result)).toHaveLength(allPermissions.length)
    Object.values(result).forEach((value) => {
      expect(value).toBe(true)
    })
  })

  it('maps specific permissions correctly', () => {
    const role = createRole({
      permissions: [
        PermissionEnum.PlansView,
        PermissionEnum.PlansCreate,
        PermissionEnum.CustomersView,
      ],
    })
    const result = mapPermissionsFromRole(role)

    expect(result.PlansView).toBe(true)
    expect(result.PlansCreate).toBe(true)
    expect(result.CustomersView).toBe(true)
    expect(result.PlansDelete).toBe(false)
    expect(result.PlansUpdate).toBe(false)
  })

  it('handles role with all addon permissions', () => {
    const role = createRole({
      permissions: [
        PermissionEnum.AddonsCreate,
        PermissionEnum.AddonsDelete,
        PermissionEnum.AddonsUpdate,
        PermissionEnum.AddonsView,
      ],
    })
    const result = mapPermissionsFromRole(role)

    expect(result.AddonsCreate).toBe(true)
    expect(result.AddonsDelete).toBe(true)
    expect(result.AddonsUpdate).toBe(true)
    expect(result.AddonsView).toBe(true)
  })

  it('returns correct permission count', () => {
    const result = mapPermissionsFromRole(undefined)

    expect(Object.keys(result).length).toBe(allPermissions.length)
  })

  it('admin flag overrides empty permissions array', () => {
    const role = createRole({
      admin: true,
      permissions: [],
    })
    const result = mapPermissionsFromRole(role)

    expect(result.PlansView).toBe(true)
    expect(result.CustomersCreate).toBe(true)
    expect(result.InvoicesView).toBe(true)
  })
})
