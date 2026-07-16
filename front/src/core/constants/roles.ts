import { GetRoleQuery, GetRolesListQuery } from '~/generated/graphql'

export const MEMBERS_PAGE_ROLE_FILTER_KEY = 'roles'
export const rolesNameMapping = {
  Admin: 'text_664f035a68227f00e261b7ee',
  Manager: 'text_664f035a68227f00e261b7f0',
  Finance: 'text_664f035a68227f00e261b7f2',
}

export const rolesDescriptionMapping = {
  Admin: 'text_1767027068946xgqsb9x6z3c',
  Manager: 'text_1767027068946er3mwgop2xm',
  Finance: 'text_1767027068946errhztv7v4w',
}

export const systemRoles = Object.keys(rolesNameMapping)

export type RoleItem = GetRolesListQuery['roles'][0] | NonNullable<GetRoleQuery['role']>
