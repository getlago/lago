import { renderHook } from '@testing-library/react'

import { useGetPermissionGrouping } from '../useGetPermissionGrouping'

jest.mock('~/core/apolloClient', () => ({
  envGlobalVar: () => ({ appEnv: 'production' }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('useGetPermissionGrouping', () => {
  it('returns groups for provided permissions', () => {
    const { result } = renderHook(() =>
      useGetPermissionGrouping(['AddonsCreate', 'AnalyticsView', 'PlansView', 'CustomersView']),
    )

    expect(result.current.permissionGrouping).toHaveProperty('addons')
    expect(result.current.permissionGrouping).toHaveProperty('analytics')
    expect(result.current.permissionGrouping).toHaveProperty('plans')
    expect(result.current.permissionGrouping).toHaveProperty('customers')
  })

  it('returns empty object on empty array', () => {
    const { result } = renderHook(() => useGetPermissionGrouping([]))

    expect(result.current.permissionGrouping).toEqual({})
  })

  it('maps permissions to their respective groups with PascalCase names', () => {
    const { result } = renderHook(() =>
      useGetPermissionGrouping(['PlansView', 'AddonsCreate', 'AddonsView']),
    )

    const { permissionGrouping } = result.current

    expect(permissionGrouping.plans.permissions).toHaveLength(1)
    expect(permissionGrouping.plans.permissions[0].name).toBe('PlansView')
    expect(permissionGrouping.addons.permissions).toHaveLength(2)
    expect(permissionGrouping.addons.permissions.map((p) => p.name)).toContain('AddonsCreate')
    expect(permissionGrouping.addons.permissions.map((p) => p.name)).toContain('AddonsView')
  })

  it('does not add "other" key when all permissions are mapped', () => {
    const { result } = renderHook(() => useGetPermissionGrouping(['PlansView', 'PlansCreate']))

    expect(result.current.permissionGrouping).not.toHaveProperty('other')
  })

  it('adds unmapped permissions to "other" key', () => {
    const { result } = renderHook(() => useGetPermissionGrouping(['unknownPermission' as never]))

    expect(result.current.permissionGrouping).toHaveProperty('other')
    expect(result.current.permissionGrouping.other.permissions).toHaveLength(1)
    expect(result.current.permissionGrouping.other.permissions[0].name).toBe('unknownPermission')
  })

  it('falls back to permission key name when description mapping is missing', () => {
    const { result } = renderHook(() => useGetPermissionGrouping(['unknownPermission' as never]))

    expect(result.current.permissionGrouping.other.permissions[0].description).toBe(
      'unknownPermission',
    )
  })

  it('adds multiple unmapped permissions to "other" key', () => {
    const { result } = renderHook(() =>
      useGetPermissionGrouping(['unknownPermission1' as never, 'unknownPermission2View' as never]),
    )

    expect(result.current.permissionGrouping.other.permissions).toHaveLength(2)
  })

  it('only includes groups that have matching permissions', () => {
    const { result } = renderHook(() => useGetPermissionGrouping(['PlansView']))

    const { permissionGrouping } = result.current

    // Only plans should have permissions, other groups should not be in result
    expect(permissionGrouping.plans.permissions).toHaveLength(1)
    expect(permissionGrouping.plans.permissions[0].name).toBe('PlansView')

    // Groups without matching permissions should not be included
    expect(Object.keys(permissionGrouping)).toHaveLength(1)
    expect(Object.keys(permissionGrouping)).toContain('plans')
  })

  it('returns translated displayName and description strings', () => {
    const { result } = renderHook(() => useGetPermissionGrouping(['PlansView', 'PlansCreate']))

    const plansView = result.current.permissionGrouping.plans.permissions.find(
      (p) => p.name === 'PlansView',
    )
    const plansCreate = result.current.permissionGrouping.plans.permissions.find(
      (p) => p.name === 'PlansCreate',
    )

    expect(typeof plansView?.description).toBe('string')
    expect(typeof plansCreate?.description).toBe('string')
  })

  it('returns correct group displayName', () => {
    const { result } = renderHook(() => useGetPermissionGrouping(['PlansView']))

    expect(result.current.permissionGrouping.plans.displayName).toBe(
      'text_62442e40cea25600b0b6d85a',
    )
  })

  it('returns group with name property', () => {
    const { result } = renderHook(() => useGetPermissionGrouping(['PlansView']))

    expect(result.current.permissionGrouping.plans.name).toBe('plans')
  })

  it('handles multiple permissions in same group', () => {
    const { result } = renderHook(() =>
      useGetPermissionGrouping(['PlansView', 'PlansCreate', 'PlansUpdate', 'PlansDelete']),
    )

    expect(result.current.permissionGrouping.plans.permissions).toHaveLength(4)
  })

  it('handles permissions from multiple groups', () => {
    const { result } = renderHook(() =>
      useGetPermissionGrouping(['PlansView', 'CustomersView', 'InvoicesView', 'SubscriptionsView']),
    )

    expect(result.current.permissionGrouping).toHaveProperty('plans')
    expect(result.current.permissionGrouping).toHaveProperty('customers')
    expect(result.current.permissionGrouping).toHaveProperty('invoices')
    expect(result.current.permissionGrouping).toHaveProperty('subscriptions')
  })
})
