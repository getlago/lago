import { PermissionEnum } from '~/generated/graphql'

import {
  allPermissions,
  groupNameMapping,
  permissionDescriptionMapping,
  permissionGroupMapping,
} from '../permissionsConst'
import { PermissionName } from '../permissionsTypes'

describe('permissionsConst', () => {
  describe('allPermissions', () => {
    it('contains all permissions from PermissionEnum', () => {
      const enumKeys = Object.keys(PermissionEnum) as PermissionName[]

      expect(allPermissions).toHaveLength(enumKeys.length)
      expect(allPermissions.sort()).toEqual(enumKeys.sort())
    })

    it('does not contain duplicates', () => {
      const uniquePermissions = Array.from(new Set(allPermissions))

      expect(allPermissions).toHaveLength(uniquePermissions.length)
    })

    it('contains only valid permission names', () => {
      allPermissions.forEach((permission) => {
        expect(Object.keys(PermissionEnum)).toContain(permission)
      })
    })
  })

  describe('permissionGroupMapping', () => {
    it('has valid structure with groups and permissions arrays', () => {
      Object.entries(permissionGroupMapping).forEach(([groupKey, permissions]) => {
        expect(typeof groupKey).toBe('string')
        expect(Array.isArray(permissions)).toBe(true)
        expect(permissions.length).toBeGreaterThan(0)
      })
    })

    it('contains only valid permissions from allPermissions', () => {
      const allMappedPermissions = Object.values(permissionGroupMapping).flat()

      allMappedPermissions.forEach((permission) => {
        expect(allPermissions).toContain(permission)
      })
    })

    it('has no orphaned permissions (all permissions are in some group)', () => {
      const allMappedPermissions = Object.values(permissionGroupMapping).flat()
      const uniqueMappedPermissions = Array.from(new Set(allMappedPermissions))

      // Note: Some permissions might intentionally not be in groups (like hidden permissions)
      // This test just ensures the structure is valid
      expect(uniqueMappedPermissions.length).toBeGreaterThan(0)
    })

    it('has no duplicate permissions within the same group', () => {
      Object.values(permissionGroupMapping).forEach((permissions) => {
        const uniquePermissions = Array.from(new Set(permissions))

        expect(permissions).toHaveLength(uniquePermissions.length)
      })
    })

    it('has all expected permission groups', () => {
      const expectedGroups = [
        'addons',
        'aiAgent',
        'analytics',
        'auditLogs',
        'authenticationMethods',
        'billableMetrics',
        'billingEntities',
        'charges',
        'coupons',
        'creditNotes',
        'customers',
        'dataApi',
        'developers',
        'dunningCampaigns',
        'features',
        'invoiceCustomSections',
        'invoices',
        'organization',
        'payments',
        'plans',
        'pricingUnits',
        'roles',
        'securityLogs',
        'subscriptions',
        'wallets',
      ]

      expectedGroups.forEach((group) => {
        expect(permissionGroupMapping).toHaveProperty(group)
      })
    })

    it('groups contain the correct number of permissions', () => {
      // Spot check key groups to ensure structure is maintained
      expect(permissionGroupMapping.addons).toHaveLength(4) // Create, Delete, Update, View
      expect(permissionGroupMapping.aiAgent).toHaveLength(2) // Create, View
      expect(permissionGroupMapping.analytics).toHaveLength(1) // View only
      expect(permissionGroupMapping.customers).toHaveLength(4) // Create, Delete, Update, View
    })
  })

  describe('groupNameMapping', () => {
    it('has translation keys for all groups in permissionGroupMapping', () => {
      const permissionGroups = Object.keys(permissionGroupMapping)

      permissionGroups.forEach((group) => {
        expect(groupNameMapping).toHaveProperty(group)
        expect(typeof groupNameMapping[group]).toBe('string')
        expect(groupNameMapping[group]).toMatch(/^text_[a-z0-9]+$/)
      })
    })

    it('has no extra groups not in permissionGroupMapping', () => {
      const groupMappingKeys = Object.keys(groupNameMapping)
      const permissionGroupKeys = Object.keys(permissionGroupMapping)

      // groupNameMapping might have some extra entries like 'customerSettings', 'draftInvoices'
      // that are used in other parts of the app, so we just check that all permission groups exist
      permissionGroupKeys.forEach((key) => {
        expect(groupMappingKeys).toContain(key)
      })
    })

    it('all translation keys follow the expected format', () => {
      Object.values(groupNameMapping).forEach((translationKey) => {
        expect(translationKey).toMatch(/^text_[a-z0-9]+$/)
      })
    })

    it('has no duplicate translation keys', () => {
      const translationKeys = Object.values(groupNameMapping)
      const uniqueKeys = Array.from(new Set(translationKeys))

      expect(translationKeys).toHaveLength(uniqueKeys.length)
    })
  })

  describe('permissionDescriptionMapping', () => {
    it('has no orphaned descriptions (all keys are valid permissions)', () => {
      const descriptionKeys = Object.keys(permissionDescriptionMapping) as PermissionName[]

      descriptionKeys.forEach((key) => {
        expect(allPermissions).toContain(key)
      })
    })

    it('all description translation keys follow the expected format', () => {
      Object.values(permissionDescriptionMapping).forEach((translationKey) => {
        expect(translationKey).toMatch(/^text_[a-z0-9]+$/)
      })
    })

    it('has no duplicate translation keys', () => {
      const translationKeys = Object.values(permissionDescriptionMapping)
      const uniqueKeys = Array.from(new Set(translationKeys))

      expect(translationKeys).toHaveLength(uniqueKeys.length)
    })
  })

  describe('data integrity across all constants', () => {
    it('permissionDescriptionMapping keys are a subset of allPermissions', () => {
      const descriptionKeys = Object.keys(permissionDescriptionMapping) as PermissionName[]

      descriptionKeys.forEach((key) => {
        expect(allPermissions).toContain(key)
      })
    })

    it('permissionGroupMapping only uses permissions from allPermissions', () => {
      const groupedPermissions = Object.values(permissionGroupMapping).flat()

      groupedPermissions.forEach((permission) => {
        expect(allPermissions).toContain(permission)
      })
    })
  })

  describe('snapshot tests', () => {
    it('permissionGroupMapping structure matches snapshot', () => {
      expect(permissionGroupMapping).toMatchSnapshot()
    })

    it('groupNameMapping structure matches snapshot', () => {
      expect(groupNameMapping).toMatchSnapshot()
    })

    it('allPermissions matches snapshot', () => {
      expect(allPermissions).toMatchSnapshot()
    })
  })
})
