import SettingsNavLayout, {
  SETTINGS_NAV_BACK_BUTTON_TEST_ID,
  SETTINGS_NAV_BILLING_ENTITY_ITEM_TEST_ID,
  SETTINGS_NAV_BURGER_BUTTON_TEST_ID,
  SETTINGS_NAV_CREATE_BILLING_ENTITY_BUTTON_TEST_ID,
} from '../SettingsNavLayout'

describe('SettingsNavLayout test IDs', () => {
  it('exports expected test ID constants', () => {
    expect(SETTINGS_NAV_BURGER_BUTTON_TEST_ID).toBe('settings-nav-burger-button')
    expect(SETTINGS_NAV_BACK_BUTTON_TEST_ID).toBe('settings-nav-back-button')
    expect(SETTINGS_NAV_CREATE_BILLING_ENTITY_BUTTON_TEST_ID).toBe(
      'settings-nav-create-billing-entity-button',
    )
    expect(SETTINGS_NAV_BILLING_ENTITY_ITEM_TEST_ID).toBe('settings-nav-billing-entity-item')
  })

  it('test ID constants follow kebab-case naming convention', () => {
    const testIds = [
      SETTINGS_NAV_BURGER_BUTTON_TEST_ID,
      SETTINGS_NAV_BACK_BUTTON_TEST_ID,
      SETTINGS_NAV_CREATE_BILLING_ENTITY_BUTTON_TEST_ID,
      SETTINGS_NAV_BILLING_ENTITY_ITEM_TEST_ID,
    ]

    testIds.forEach((testId) => {
      expect(testId).toMatch(/^[a-z-]+$/)
    })
  })
})

describe('SettingsNavLayout generateTabs function', () => {
  // Import the component to test the generateTabs function behavior indirectly

  it('component exports successfully', () => {
    expect(SettingsNavLayout).toBeDefined()
    expect(typeof SettingsNavLayout).toBe('function')
  })
})
