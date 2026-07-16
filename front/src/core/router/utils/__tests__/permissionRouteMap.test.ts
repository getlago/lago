import { getPermissionRouteMap, getRouteForPermission } from '../permissionRouteMap'

describe('permissionRouteMap', () => {
  describe('getPermissionRouteMap', () => {
    it('returns a map of view permissions to routes', () => {
      const map = getPermissionRouteMap()

      expect(map).toBeDefined()
      expect(typeof map).toBe('object')
    })

    it('includes expected view permission mappings (relative paths under :organizationSlug)', () => {
      const map = getPermissionRouteMap()

      // After route restructure, paths are relative (no leading /)
      expect(map.customersView).toBe('customers')
      expect(map.billableMetricsView).toBe('billable-metrics')
      expect(map.plansView).toBe('plans')
      expect(map.couponsView).toBe('coupons')
      expect(map.addonsView).toBe('add-ons')
      expect(map.invoicesView).toBe('invoices')
      expect(map.paymentsView).toBe('payments')
      expect(map.creditNotesView).toBe('credit-notes')
      expect(map.subscriptionsView).toBe('subscriptions')
      expect(map.featuresView).toBe('features')
    })

    it('includes settings route mappings (relative paths)', () => {
      const map = getPermissionRouteMap()

      expect(map.organizationInvoicesView).toBe('settings/invoice-sections')
      expect(map.organizationTaxesView).toBe('settings/taxes')
      expect(map.organizationMembersView).toBe('settings/team-and-security')
      expect(map.dunningCampaignsView).toBe('settings/dunnings')
    })

    it('returns the same cached map on subsequent calls', () => {
      const map1 = getPermissionRouteMap()
      const map2 = getPermissionRouteMap()

      expect(map1).toBe(map2)
    })

    it('only includes routes without dynamic params', () => {
      const map = getPermissionRouteMap()

      // All routes in the map should not contain dynamic params
      for (const route of Object.values(map)) {
        expect(route).not.toContain(':')
      }
    })
  })

  describe('getRouteForPermission', () => {
    it('returns the correct route for a valid view permission', () => {
      expect(getRouteForPermission('customersView')).toBe('customers')
      expect(getRouteForPermission('plansView')).toBe('plans')
      expect(getRouteForPermission('invoicesView')).toBe('invoices')
    })

    it('returns null for non-view permissions', () => {
      expect(getRouteForPermission('customersCreate')).toBeNull()
      expect(getRouteForPermission('plansDelete')).toBeNull()
    })

    it('returns null for permissions without associated routes', () => {
      // auditLogsView doesn't have a standalone route in the current config
      const result = getRouteForPermission('auditLogsView')

      expect(result).toBeNull()
    })
  })
})
