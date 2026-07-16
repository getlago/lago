import { validationSchema } from '../validationSchema'

describe('validationSchema', () => {
  describe('name field', () => {
    it('accepts valid name', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'my_role',
        description: 'Description',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })

    it('rejects empty name', () => {
      const result = validationSchema.safeParse({
        name: '',
        code: 'my-role',
        description: 'Description',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].path).toContain('name')
        expect(result.error.issues[0].message).toBe('text_1766155139328b95i4fjkwe9')
      }
    })

    it('accepts single character name', () => {
      const result = validationSchema.safeParse({
        name: 'A',
        code: 'a',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })

    it('accepts long name', () => {
      const result = validationSchema.safeParse({
        name: 'A'.repeat(100),
        code: 'long_name',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })
  })

  describe('code field', () => {
    it('accepts valid code with lowercase letters', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'my_role_code',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })

    it('accepts valid code with numbers', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'role123',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })

    it('accepts valid code with underscores', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'my_role_123',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })

    it('does NOT accept empty code', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: '',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
    })

    it('rejects code with uppercase letters', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'MyRole',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].path).toContain('code')
        expect(result.error.issues[0].message).toBe('text_1767881112174odn29xztnvi')
      }
    })

    it('rejects code with hyphens', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'my-role',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].path).toContain('code')
        expect(result.error.issues[0].message).toBe('text_1767881112174odn29xztnvi')
      }
    })

    it('rejects code with spaces', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'my role',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].path).toContain('code')
        expect(result.error.issues[0].message).toBe('text_1767881112174odn29xztnvi')
      }
    })

    it('rejects code with special characters', () => {
      const result = validationSchema.safeParse({
        name: 'My Role',
        code: 'my.role@test',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].path).toContain('code')
        expect(result.error.issues[0].message).toBe('text_1767881112174odn29xztnvi')
      }
    })
  })

  describe('description field', () => {
    it('accepts empty description', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: '',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })

    it('accepts long description', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: 'A'.repeat(500),
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })

    it('accepts description with special characters', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: 'This role can: view, edit & delete items!',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(true)
    })
  })

  describe('permissions field', () => {
    it('accepts valid permissions with PascalCase keys', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: 'Description',
        permissions: {
          PlansView: true,
          PlansCreate: false,
          CustomersView: true,
        },
      })

      expect(result.success).toBe(true)
    })

    it('does NOT accept empty permissions object', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: 'Description',
        permissions: {},
      })

      expect(result.success).toBe(false)
    })

    it('does NOT accept all permissions set to false', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: 'Description',
        permissions: {
          PlansView: false,
          PlansCreate: false,
        },
      })

      expect(result.success).toBe(false)
    })

    it('accepts all permissions set to true', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: 'Description',
        permissions: {
          PlansView: true,
          PlansCreate: true,
          CustomersView: true,
          CustomersCreate: true,
        },
      })

      expect(result.success).toBe(true)
    })

    it('rejects invalid permission keys', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role_name',
        description: 'Description',
        permissions: {
          invalidPermission: true,
        },
      })

      expect(result.success).toBe(false)
    })
  })

  describe('complete form validation', () => {
    it('validates a complete valid form', () => {
      const result = validationSchema.safeParse({
        name: 'Custom Admin Role',
        code: 'custom_admin_role',
        description: 'A role with custom admin permissions',
        permissions: {
          PlansView: true,
          PlansCreate: true,
          PlansUpdate: true,
          PlansDelete: false,
          CustomersView: true,
        },
      })

      expect(result.success).toBe(true)
      if (result.success) {
        expect(result.data.name).toBe('Custom Admin Role')
        expect(result.data.code).toBe('custom_admin_role')
        expect(result.data.description).toBe('A role with custom admin permissions')
        expect(result.data.permissions.PlansView).toBe(true)
      }
    })

    it('fails when name is missing', () => {
      const result = validationSchema.safeParse({
        code: 'role-code',
        description: 'Description',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
    })

    it('fails when code is missing', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        description: 'Description',
        permissions: { PlansView: true },
      })

      expect(result.success).toBe(false)
    })

    it('fails when permissions is missing', () => {
      const result = validationSchema.safeParse({
        name: 'Role Name',
        code: 'role-name',
        description: 'Description',
      })

      expect(result.success).toBe(false)
    })
  })
})
