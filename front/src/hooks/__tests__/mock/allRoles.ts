import { RoleItem } from '~/core/constants/roles'
import { PermissionEnum } from '~/generated/graphql'

export const allRoles: Array<RoleItem> = [
  {
    __typename: 'Role',
    id: '1',
    name: 'Admin',
    description: 'Full access to all settings and data.',
    admin: true,
    code: 'ADMIN',
    memberships: [
      {
        __typename: 'Membership',
        id: '1',
        user: {
          __typename: 'User',
          id: '1',
          email: 'john.doe@example.com',
        },
      },
      {
        __typename: 'Membership',
        id: '2',
        user: {
          __typename: 'User',
          id: '2',
          email: 'jane.smith@example.com',
        },
      },
      {
        __typename: 'Membership',
        id: '4',
        user: {
          __typename: 'User',
          id: '4',
          email: 'bob.brown@example.com',
        },
      },
    ],
    permissions: [],
  },
  {
    __typename: 'Role',
    id: '2',
    name: 'Manager',
    description: 'Can manage most settings and data, but cannot access admin-only features.',
    admin: false,
    code: 'MANAGER',
    memberships: [],
    permissions: [
      PermissionEnum.AddonsCreate,
      PermissionEnum.AddonsDelete,
      PermissionEnum.AddonsUpdate,
      PermissionEnum.AddonsView,
    ],
  },
  {
    __typename: 'Role',
    id: '3',
    name: 'Finance',
    description: 'Can view and manage billing and invoicing settings and data.',
    admin: false,
    code: 'FINANCE',
    memberships: [
      {
        __typename: 'Membership',
        id: '3',
        user: {
          __typename: 'User',
          id: '3',
          email: 'alice.johnson@example.com',
        },
      },
    ],
    permissions: [
      PermissionEnum.InvoicesCreate,
      PermissionEnum.InvoicesSend,
      PermissionEnum.BillingEntitiesView,
    ],
  },
]
