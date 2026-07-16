import { renderHook } from '@testing-library/react'

import { RoleItem } from '~/core/constants/roles'

import { useRoleDisplayInformation } from '../useRoleDisplayInformation'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('useRoleDisplayInformation', () => {
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

  describe('getDisplayName', () => {
    it('returns empty string for undefined role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())

      expect(result.current.getDisplayName(undefined)).toBe('')
    })

    it('returns translated name for admin system role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const adminRole = createRole({ name: 'Admin' })

      expect(result.current.getDisplayName(adminRole)).toBe('text_664f035a68227f00e261b7ee')
    })

    it('returns translated name for manager system role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const managerRole = createRole({ name: 'Manager' })

      expect(result.current.getDisplayName(managerRole)).toBe('text_664f035a68227f00e261b7f0')
    })

    it('returns translated name for finance system role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const financeRole = createRole({ name: 'Finance' })

      expect(result.current.getDisplayName(financeRole)).toBe('text_664f035a68227f00e261b7f2')
    })

    it('returns role name as-is for custom roles', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const customRole = createRole({ name: 'My Custom Role' })

      expect(result.current.getDisplayName(customRole)).toBe('My Custom Role')
    })
  })

  describe('getDisplayDescription', () => {
    it('returns empty string for undefined role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())

      expect(result.current.getDisplayDescription(undefined)).toBe('')
    })

    it('returns translated description for admin system role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const adminRole = createRole({ name: 'Admin' })

      expect(result.current.getDisplayDescription(adminRole)).toBe('text_1767027068946xgqsb9x6z3c')
    })

    it('returns translated description for manager system role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const managerRole = createRole({ name: 'Manager' })

      expect(result.current.getDisplayDescription(managerRole)).toBe(
        'text_1767027068946er3mwgop2xm',
      )
    })

    it('returns translated description for finance system role', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const financeRole = createRole({ name: 'Finance' })

      expect(result.current.getDisplayDescription(financeRole)).toBe(
        'text_1767027068946errhztv7v4w',
      )
    })

    it('returns role description for custom roles', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const customRole = createRole({
        name: 'My Custom Role',
        description: 'Custom role description',
      })

      expect(result.current.getDisplayDescription(customRole)).toBe('Custom role description')
    })

    it('returns empty string if custom role has no description', () => {
      const { result } = renderHook(() => useRoleDisplayInformation())
      const customRole = createRole({ name: 'My Custom Role', description: undefined })

      expect(result.current.getDisplayDescription(customRole)).toBe('')
    })
  })
})
