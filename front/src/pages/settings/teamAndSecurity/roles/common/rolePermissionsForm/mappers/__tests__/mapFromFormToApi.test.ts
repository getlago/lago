import { PermissionEnum } from '~/generated/graphql'

import { mapFromFormToApi } from '../mapFromFormToApi'

describe('mapFromFormToApi', () => {
  it('maps form values to API input with all fields', () => {
    const formValues = {
      name: 'Custom Role',
      code: 'custom-role',
      description: 'A custom role description',
      permissions: {
        PlansView: true,
        PlansCreate: false,
        CustomersView: true,
      },
    }

    const result = mapFromFormToApi(formValues)

    expect(result.name).toBe('Custom Role')
    expect(result.code).toBe('custom-role')
    expect(result.description).toBe('A custom role description')
    expect(result.permissions).toContain(PermissionEnum.PlansView)
    expect(result.permissions).toContain(PermissionEnum.CustomersView)
    expect(result.permissions).not.toContain(PermissionEnum.PlansCreate)
  })

  it('returns empty permissions array when all permissions are false', () => {
    const formValues = {
      name: 'No Permissions Role',
      code: 'no-perms',
      description: '',
      permissions: {
        PlansView: false,
        PlansCreate: false,
      },
    }

    const result = mapFromFormToApi(formValues)

    expect(result.permissions).toHaveLength(0)
  })

  it('returns empty permissions array when permissions object is empty', () => {
    const formValues = {
      name: 'Empty Permissions Role',
      code: 'empty-perms',
      description: '',
      permissions: {},
    }

    const result = mapFromFormToApi(formValues)

    expect(result.permissions).toHaveLength(0)
  })

  it('includes all true permissions in output', () => {
    const formValues = {
      name: 'Full Access Role',
      code: 'full-access',
      description: 'Has many permissions',
      permissions: {
        PlansView: true,
        PlansCreate: true,
        PlansUpdate: true,
        PlansDelete: true,
        CustomersView: true,
        CustomersCreate: true,
      },
    }

    const result = mapFromFormToApi(formValues)

    expect(result.permissions).toHaveLength(6)
    expect(result.permissions).toContain(PermissionEnum.PlansView)
    expect(result.permissions).toContain(PermissionEnum.PlansCreate)
    expect(result.permissions).toContain(PermissionEnum.PlansUpdate)
    expect(result.permissions).toContain(PermissionEnum.PlansDelete)
    expect(result.permissions).toContain(PermissionEnum.CustomersView)
    expect(result.permissions).toContain(PermissionEnum.CustomersCreate)
  })

  it('handles empty description', () => {
    const formValues = {
      name: 'Role Without Description',
      code: 'no-desc',
      description: '',
      permissions: { PlansView: true },
    }

    const result = mapFromFormToApi(formValues)

    expect(result.description).toBe('')
  })

  it('handles empty code', () => {
    const formValues = {
      name: 'Role Without Code',
      code: '',
      description: 'Some description',
      permissions: { PlansView: true },
    }

    const result = mapFromFormToApi(formValues)

    expect(result.code).toBe('')
  })
})
