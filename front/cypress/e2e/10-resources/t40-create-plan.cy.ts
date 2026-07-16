import { ACTIONS_BLOCK_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'
import {
  CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID,
  CHARGE_PERCENTAGE_REMOVE_FIXED_FEE_TEST_ID,
  GRADUATED_CHARGE_TABLE_ADD_TIER_TEST_ID,
  VOLUME_CHARGE_TABLE_ADD_TIER_TEST_ID,
} from '~/components/plans/chargeTestIds'
import { SEARCH_BILLABLE_METRIC_IN_USAGE_CHARGE_DRAWER_INPUT_CLASSNAME } from '~/core/constants/form'

import { planWithChargesName } from '../../support/reusableConstants'

// Helper: select a metered billable metric in the usage charge drawer.
// Waits for the dropdown to be open (onEntered auto-opens it), then clicks the matching option.
const selectMeteredBillableMetric = (bmNameFragment: string) => {
  // Wait for dropdown options to load
  cy.get('[data-option-index]', { timeout: 30000 }).should('exist')
  // Find the option containing the BM name and click it
  cy.contains('[role="option"]', bmNameFragment).click({ force: true })
}

describe('Create plan', () => {
  beforeEach(() => {
    cy.login().visitApp('/plans')
  })

  it('should be able to create a minimal plan', () => {
    const randomId = Math.round(Math.random() * 1000)
    const planName = `plan minimal ${randomId}`
    const planCode = `plan_minimal_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-plan"]`).click({
      force: true,
    })
    cy.url().should('match', /\/[^/]+\/create\/plans$/)
    cy.get('input[name="name"]').type(planName)
    cy.get('input[name="code"]').should('have.value', planCode)

    cy.get('[data-test="submit"]', { timeout: 10000 }).should('not.be.disabled')
    cy.get('[data-test="submit"]').click({ force: true })
    cy.url().should('include', '/overview')
    cy.contains(planName).should('exist')
  })

  it('should be able to create a simple plan', () => {
    const randomId = Math.round(Math.random() * 1000)
    const planName = `plan ${randomId}`
    const planCode = `plan_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-plan"]`).click({
      force: true,
    })
    cy.url().should('match', /\/[^/]+\/create\/plans$/)
    cy.get('input[name="name"]').type(planName)
    cy.get('input[name="code"]').should('have.value', planCode)
    cy.get('[data-test="show-description"]').click({ force: true })
    cy.get('textarea[name="description"]').type('I am a description')

    // Open subscription fee drawer, set amount, and save
    cy.get('[data-test="open-subscription-fee-drawer"]').click({ force: true })
    cy.get('input[name="amountCents"]').type('30000')
    cy.get('[data-test="subscription-fee-drawer-save"]').should('not.be.disabled').click()

    cy.get('[data-test="submit"]').click({ force: true })
    cy.url().should('include', '/overview')
    cy.contains(planName).should('exist')
  })

  it('should be able to create a plan with all charge types', () => {
    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-plan"]`).click({
      force: true,
    })
    cy.url().should('match', /\/[^/]+\/create\/plans$/)
    cy.get('input[name="name"]').type(planWithChargesName)
    cy.get('[data-test="show-description"]').click({ force: true })
    cy.get('textarea[name="description"]').type('A plan with all charge types')

    // Set subscription fee
    cy.get('[data-test="open-subscription-fee-drawer"]').scrollIntoView().click({ force: true })
    cy.get('input[name="amountCents"]').type('30000')
    cy.get('[data-test="subscription-fee-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')

    // Standard charge
    cy.get('[data-test="add-usage-charge"]').scrollIntoView()
    cy.get('[data-test="add-usage-charge"]').click()
    selectMeteredBillableMetric('bm count')
    cy.get('input[name="properties.amount"]').type('5000')
    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')
    cy.get('[data-test="usage-charge-selector-0"]', { timeout: 10000 }).should('exist')

    // Graduated charge
    cy.get('[data-test="add-usage-charge"]').scrollIntoView()
    cy.get('[data-test="add-usage-charge"]').click()
    selectMeteredBillableMetric('bm uniq count')
    cy.get('[data-test="charge-model-wrapper"] input[name="chargeModel"]').click({ force: true })
    cy.get('[data-test="graduated"]').click({ force: true })
    cy.get(`[data-test="${GRADUATED_CHARGE_TABLE_ADD_TIER_TEST_ID}"]`).click({ force: true })
    cy.get('[data-test="cell-amount-0"]').type('1')
    cy.get('[data-test="cell-amount-1"]').type('1')
    cy.get('[data-test="cell-amount-2"]').type('1')
    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')
    cy.get('[data-test="usage-charge-selector-1"]', { timeout: 10000 }).should('exist')

    // Package charge
    cy.get('[data-test="add-usage-charge"]').scrollIntoView()
    cy.get('[data-test="add-usage-charge"]').click()
    selectMeteredBillableMetric('bm max')
    cy.get('[data-test="charge-model-wrapper"] input[name="chargeModel"]').click({ force: true })
    cy.get('[data-test="package"]').click({ force: true })
    cy.get('input[name="properties.amount"]').type('100')
    cy.get('input[name="properties.packageSize"]').type('10')
    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')
    cy.get('[data-test="usage-charge-selector-2"]', { timeout: 10000 }).should('exist')

    // Percentage charge
    cy.get('[data-test="add-usage-charge"]').scrollIntoView()
    cy.get('[data-test="add-usage-charge"]').click()
    selectMeteredBillableMetric('bm sum')
    cy.get('[data-test="charge-model-wrapper"] input[name="chargeModel"]').click({ force: true })
    cy.get('[data-test="percentage"]').click({ force: true })
    cy.get('input[name="properties.rate"]').type('1')
    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')
    cy.get('[data-test="usage-charge-selector-3"]', { timeout: 10000 }).should('exist')

    // Volume charge
    cy.get('[data-test="add-usage-charge"]').scrollIntoView()
    cy.get('[data-test="add-usage-charge"]').click()
    selectMeteredBillableMetric('bm filtered')
    cy.get('[data-test="charge-model-wrapper"] input[name="chargeModel"]').click({ force: true })
    cy.get('[data-test="volume"]').click({ force: true })
    cy.get(`[data-test="${VOLUME_CHARGE_TABLE_ADD_TIER_TEST_ID}"]`).click({ force: true })
    cy.get('[data-test="cell-amount-0"]').last().type('1')
    cy.get('[data-test="cell-amount-1"]').last().type('1')
    cy.get('[data-test="cell-amount-2"]').last().type('1')
    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')
    cy.get('[data-test="usage-charge-selector-4"]', { timeout: 10000 }).should('exist')

    cy.get('[data-test="submit"]', { timeout: 10000 }).should('not.be.disabled')
    cy.get('[data-test="submit"]').click({ force: true })
    cy.url().should('include', '/overview')
    cy.contains(planWithChargesName).should('exist')
  })

  it('should be able to edit percentage charge without data loss', () => {
    const randomId = Math.round(Math.random() * 1000)
    const planName = `plan percentage ${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-plan"]`).click({
      force: true,
    })
    cy.get('input[name="name"]').type(planName)

    // Add percentage charge
    cy.get('[data-test="add-usage-charge"]').scrollIntoView()
    cy.get('[data-test="add-usage-charge"]').click()
    selectMeteredBillableMetric('bm count')
    cy.get('[data-test="charge-model-wrapper"] input[name="chargeModel"]').click({ force: true })
    cy.get('[data-test="percentage"]').click({ force: true })
    cy.get('input[name="properties.rate"]').type('1')

    // Add fixed fee, then remove it — rate should still be "1"
    cy.get(`[data-test="${CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID}"]`).click({ force: true })
    cy.get('input[name="properties.fixedAmount"]').should('exist')
    cy.get(`[data-test="${CHARGE_PERCENTAGE_REMOVE_FIXED_FEE_TEST_ID}"]`).click({ force: true })
    cy.get('input[name="properties.rate"]').should('have.value', '1')

    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')

    cy.get('[data-test="submit"]', { timeout: 10000 }).should('not.be.disabled')
    cy.get('[data-test="submit"]').click({ force: true })
    cy.url().should('include', '/overview')
    cy.contains(planName).should('exist')
  })

  it('should be able to create a usage charge with filters', () => {
    const randomId = Math.round(Math.random() * 1000)
    const planName = `plan filtered ${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-plan"]`).click({
      force: true,
    })
    cy.get('input[name="name"]').type(planName)

    // Add usage charge — select the BM with filters
    cy.get('[data-test="add-usage-charge"]').scrollIntoView()
    cy.get('[data-test="add-usage-charge"]').click()
    // Wait for dropdown to open, then search for filtered BM
    cy.get('[data-option-index="0"]', { timeout: 30000 }).should('exist')
    cy.get(`.${SEARCH_BILLABLE_METRIC_IN_USAGE_CHARGE_DRAWER_INPUT_CLASSNAME} input`)
      .first()
      .type('filtered')
    cy.get('[data-option-index="0"]', { timeout: 15000 }).click({ force: true })
    cy.get('input[name="properties.amount"]').type('500')

    // The BM has filters — add a charge filter
    cy.get('body').then(($body) => {
      cy.get('[data-test="add-charge-filter"]').click({ force: true })

      // In the filter drawer (topmost): select a filter value and fill pricing
      // Use .last() to scope to the topmost drawer when two are stacked
      cy.get('[data-option-index="0"]', { timeout: 15000 }).click({ force: true })
      cy.get('[data-test="charge-filter-values-container"]').should('exist')

      // Fill standard pricing — scope to the topmost drawer to avoid ambiguity
      cy.get('[data-test="base-drawer-paper"]')
        .last()
        .find('input[name="properties.amount"]')
        .type('500')

      // Save filter drawer
      cy.get('[data-test="charge-filter-drawer-save"]').should('not.be.disabled').click()
      cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('have.length', 1)
    })

    // Save usage charge drawer
    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')

    cy.get('[data-test="submit"]', { timeout: 10000 }).should('not.be.disabled')
    cy.get('[data-test="submit"]').click({ force: true })
    cy.url().should('include', '/overview')
    cy.contains(planName).should('exist')
  })
})
