import { render, screen } from '@testing-library/react'

import { RoleItem } from '~/core/constants/roles'
import { PermissionEnum } from '~/generated/graphql'

import RoleTypeChip from '../RoleTypeChip'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => {
      const translations: Record<string, string> = {
        text_1765464506554l3g5v7dctfv: 'System',
        text_6641dd21c0cffd005b5e2a8b: 'Custom',
      }

      return translations[key] || key
    },
  }),
}))

describe('RoleTypeChip', () => {
  it('renders null when role is undefined', () => {
    const { container } = render(<RoleTypeChip role={undefined} />)

    expect(container.firstChild).toBeNull()
  })

  it('renders "System" chip for Admin role', () => {
    const adminRole = {
      __typename: 'Role',
      id: '1',
      name: 'Admin',
      description: 'Admin role',
      admin: true,
      code: 'admin',
      permissions: [PermissionEnum.PlansView],
      memberships: [],
    } as RoleItem

    render(<RoleTypeChip role={adminRole} />)

    expect(screen.getByText('System')).toBeInTheDocument()
  })

  it('renders "System" chip for Manager role', () => {
    const managerRole = {
      __typename: 'Role',
      id: '2',
      name: 'Manager',
      description: 'Manager role',
      admin: false,
      code: 'manager',
      permissions: [PermissionEnum.PlansView],
      memberships: [],
    } as RoleItem

    render(<RoleTypeChip role={managerRole} />)

    expect(screen.getByText('System')).toBeInTheDocument()
  })

  it('renders "System" chip for Finance role', () => {
    const financeRole = {
      __typename: 'Role',
      id: '3',
      name: 'Finance',
      description: 'Finance role',
      admin: false,
      code: 'finance',
      permissions: [PermissionEnum.PlansView],
      memberships: [],
    } as RoleItem

    render(<RoleTypeChip role={financeRole} />)

    expect(screen.getByText('System')).toBeInTheDocument()
  })

  it('renders "Custom" chip for custom role', () => {
    const customRole = {
      __typename: 'Role',
      id: '100',
      name: 'my-custom-role',
      description: 'A custom role',
      admin: false,
      code: 'custom_code',
      permissions: [PermissionEnum.PlansView],
      memberships: [],
    } as RoleItem

    render(<RoleTypeChip role={customRole} />)

    expect(screen.getByText('Custom')).toBeInTheDocument()
  })

  it('renders "Custom" chip for role with non-system name', () => {
    const customRole = {
      __typename: 'Role',
      id: '101',
      name: 'Support Team',
      description: 'Support team role',
      admin: false,
      code: 'support_team',
      permissions: [PermissionEnum.CustomersView],
      memberships: [],
    } as RoleItem

    render(<RoleTypeChip role={customRole} />)

    expect(screen.getByText('Custom')).toBeInTheDocument()
  })
})
