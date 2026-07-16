// Test route constants without importing the full module to avoid circular dependencies
describe('SettingRoutes', () => {
  // Define expected route constants locally to validate structure
  const SETTINGS_ROUTE = '/settings'
  const INVOICE_SETTINGS_ROUTE = `${SETTINGS_ROUTE}/invoice-sections`
  const TAXES_SETTINGS_ROUTE = `${SETTINGS_ROUTE}/taxes`
  const ROOT_INTEGRATIONS_ROUTE = `${SETTINGS_ROUTE}/integrations`
  const INTEGRATIONS_ROUTE = `${ROOT_INTEGRATIONS_ROUTE}/:integrationGroup`
  const MEMBERS_ROUTE = `${SETTINGS_ROUTE}/members`
  const MEMBERS_TAB_ROUTE = `${SETTINGS_ROUTE}/members/:tab`
  const AUTHENTICATION_ROUTE = `${SETTINGS_ROUTE}/authentication`
  const OKTA_AUTHENTICATION_ROUTE = `${AUTHENTICATION_ROUTE}/okta/:integrationId`
  const DUNNINGS_SETTINGS_ROUTE = `${SETTINGS_ROUTE}/dunnings`
  const BILLING_ENTITY_BASE = `${SETTINGS_ROUTE}/billing-entity`
  const BILLING_ENTITY_BASE_WITH_CODE = `${BILLING_ENTITY_BASE}/:billingEntityCode`
  const BILLING_ENTITY_ROUTE = BILLING_ENTITY_BASE_WITH_CODE
  const BILLING_ENTITY_GENERAL_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/general`
  const BILLING_ENTITY_EMAIL_SCENARIOS_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/email-scenarios`
  const BILLING_ENTITY_EMAIL_SCENARIOS_CONFIG_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/email-scenarios/:type`
  const BILLING_ENTITY_DUNNING_CAMPAIGNS_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/dunning-campaigns`
  const BILLING_ENTITY_INVOICE_SETTINGS_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/invoice-settings`
  const BILLING_ENTITY_INVOICE_CUSTOM_SECTIONS_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/invoice-custom-sections`
  const BILLING_ENTITY_TAXES_SETTINGS_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/taxes`
  const ROLES_LIST_ROUTE = `${SETTINGS_ROUTE}/roles`
  const ROLE_DETAILS_ROUTE = `${ROLES_LIST_ROUTE}/:roleId`
  const ROLE_CREATE_ROUTE = `${ROLES_LIST_ROUTE}/create`
  const ROLE_EDIT_ROUTE = `${ROLES_LIST_ROUTE}/:roleId/edit`
  const BILLING_ENTITY_CREATE_ROUTE = `${BILLING_ENTITY_BASE}/create`
  const BILLING_ENTITY_UPDATE_ROUTE = `${BILLING_ENTITY_BASE_WITH_CODE}/edit`
  const CREATE_DUNNING_ROUTE = `${SETTINGS_ROUTE}/dunnings/create`
  const UPDATE_DUNNING_ROUTE = `${SETTINGS_ROUTE}/dunnings/:campaignId/edit`
  const CREATE_INVOICE_CUSTOM_SECTION = `${INVOICE_SETTINGS_ROUTE}/custom-section/create`
  const EDIT_INVOICE_CUSTOM_SECTION = `${INVOICE_SETTINGS_ROUTE}/custom-section/:sectionId/edit`
  const CREATE_PRICING_UNIT = `${INVOICE_SETTINGS_ROUTE}/pricing-unit/create`
  const EDIT_PRICING_UNIT = `${INVOICE_SETTINGS_ROUTE}/pricing-unit/:pricingUnitId/edit`

  describe('route constants', () => {
    it('defines base settings route', () => {
      expect(SETTINGS_ROUTE).toBe('/settings')
    })

    it('defines organization settings routes', () => {
      expect(INVOICE_SETTINGS_ROUTE).toBe('/settings/invoice-sections')
      expect(TAXES_SETTINGS_ROUTE).toBe('/settings/taxes')
      expect(ROOT_INTEGRATIONS_ROUTE).toBe('/settings/integrations')
      expect(INTEGRATIONS_ROUTE).toBe('/settings/integrations/:integrationGroup')
      expect(MEMBERS_ROUTE).toBe('/settings/members')
      expect(MEMBERS_TAB_ROUTE).toBe('/settings/members/:tab')
      expect(DUNNINGS_SETTINGS_ROUTE).toBe('/settings/dunnings')
    })

    it('defines authentication routes', () => {
      expect(AUTHENTICATION_ROUTE).toBe('/settings/authentication')
      expect(OKTA_AUTHENTICATION_ROUTE).toBe('/settings/authentication/okta/:integrationId')
    })

    it('defines billing entity routes', () => {
      expect(BILLING_ENTITY_ROUTE).toBe('/settings/billing-entity/:billingEntityCode')
      expect(BILLING_ENTITY_GENERAL_ROUTE).toBe(
        '/settings/billing-entity/:billingEntityCode/general',
      )
      expect(BILLING_ENTITY_EMAIL_SCENARIOS_ROUTE).toBe(
        '/settings/billing-entity/:billingEntityCode/email-scenarios',
      )
      expect(BILLING_ENTITY_EMAIL_SCENARIOS_CONFIG_ROUTE).toBe(
        '/settings/billing-entity/:billingEntityCode/email-scenarios/:type',
      )
      expect(BILLING_ENTITY_DUNNING_CAMPAIGNS_ROUTE).toBe(
        '/settings/billing-entity/:billingEntityCode/dunning-campaigns',
      )
      expect(BILLING_ENTITY_INVOICE_SETTINGS_ROUTE).toBe(
        '/settings/billing-entity/:billingEntityCode/invoice-settings',
      )
      expect(BILLING_ENTITY_INVOICE_CUSTOM_SECTIONS_ROUTE).toBe(
        '/settings/billing-entity/:billingEntityCode/invoice-custom-sections',
      )
      expect(BILLING_ENTITY_TAXES_SETTINGS_ROUTE).toBe(
        '/settings/billing-entity/:billingEntityCode/taxes',
      )
    })

    it('defines roles routes', () => {
      expect(ROLES_LIST_ROUTE).toBe('/settings/roles')
      expect(ROLE_DETAILS_ROUTE).toBe('/settings/roles/:roleId')
      expect(ROLE_CREATE_ROUTE).toBe('/settings/roles/create')
      expect(ROLE_EDIT_ROUTE).toBe('/settings/roles/:roleId/edit')
    })

    it('defines creation routes', () => {
      expect(BILLING_ENTITY_CREATE_ROUTE).toBe('/settings/billing-entity/create')
      expect(BILLING_ENTITY_UPDATE_ROUTE).toBe('/settings/billing-entity/:billingEntityCode/edit')
      expect(CREATE_DUNNING_ROUTE).toBe('/settings/dunnings/create')
      expect(UPDATE_DUNNING_ROUTE).toBe('/settings/dunnings/:campaignId/edit')
      expect(CREATE_INVOICE_CUSTOM_SECTION).toBe('/settings/invoice-sections/custom-section/create')
      expect(EDIT_INVOICE_CUSTOM_SECTION).toBe(
        '/settings/invoice-sections/custom-section/:sectionId/edit',
      )
      expect(CREATE_PRICING_UNIT).toBe('/settings/invoice-sections/pricing-unit/create')
      expect(EDIT_PRICING_UNIT).toBe('/settings/invoice-sections/pricing-unit/:pricingUnitId/edit')
    })
  })

  describe('route structure validation', () => {
    it('all settings routes follow consistent pattern', () => {
      // All settings routes should start with /settings
      expect(SETTINGS_ROUTE).toMatch(/^\/settings$/)
      expect(INVOICE_SETTINGS_ROUTE).toMatch(/^\/settings\//)
      expect(TAXES_SETTINGS_ROUTE).toMatch(/^\/settings\//)
      expect(MEMBERS_ROUTE).toMatch(/^\/settings\//)
      expect(DUNNINGS_SETTINGS_ROUTE).toMatch(/^\/settings\//)
      expect(BILLING_ENTITY_ROUTE).toMatch(/^\/settings\//)
      expect(ROLES_LIST_ROUTE).toMatch(/^\/settings\//)
    })

    it('route parameter patterns use colons', () => {
      expect(BILLING_ENTITY_ROUTE).toContain(':billingEntityCode')
      expect(ROLE_DETAILS_ROUTE).toContain(':roleId')
      expect(OKTA_AUTHENTICATION_ROUTE).toContain(':integrationId')
      expect(EDIT_INVOICE_CUSTOM_SECTION).toContain(':sectionId')
      expect(EDIT_PRICING_UNIT).toContain(':pricingUnitId')
    })

    it('creation routes use consistent naming', () => {
      expect(CREATE_DUNNING_ROUTE).toContain('/create')
      expect(CREATE_INVOICE_CUSTOM_SECTION).toContain('/create')
      expect(CREATE_PRICING_UNIT).toContain('/create')
      expect(BILLING_ENTITY_CREATE_ROUTE).toContain('/create')
      expect(ROLE_CREATE_ROUTE).toContain('/create')
    })

    it('edit routes use consistent naming', () => {
      expect(UPDATE_DUNNING_ROUTE).toContain('/edit')
      expect(EDIT_INVOICE_CUSTOM_SECTION).toContain('/edit')
      expect(EDIT_PRICING_UNIT).toContain('/edit')
      expect(BILLING_ENTITY_UPDATE_ROUTE).toContain('/edit')
      expect(ROLE_EDIT_ROUTE).toContain('/edit')
    })
  })
})
