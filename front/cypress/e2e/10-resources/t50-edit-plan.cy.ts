import {
  DETAILS_ADD_USAGE_CHARGE_TEST_ID,
  PLAN_SETTINGS_ACCORDION_TEST_ID,
  PLAN_SETTINGS_EDIT_TEST_ID,
  USAGE_CHARGE_ACCORDION_TEST_ID_PREFIX,
} from '~/components/plans/details-v2/detailsV2TestIds'

import {
  customerName,
  planWithChargeCodeNew,
  planWithChargesName,
} from '../../support/reusableConstants'

// Mirrors BASE_DRAWER_CLOSE_BUTTON_TEST_ID from BaseDrawer.tsx — not imported
// because Cypress specs cannot import React component files.
const BASE_DRAWER_CLOSE_BUTTON_TEST_ID = 'base-drawer-close-button'

// Navigate from the plans list to the plan details page (v2 edit layout)
// through the list's "View and edit" action.
const goToPlanDetails = () => {
  cy.visitApp('/plans')
  cy.get(`[data-test="${planWithChargesName}"] [data-test="open-action-button"]`).click({
    force: true,
  })
  cy.get('[data-test="tab-internal-button-link-update-plan"]').click({ force: true })
  cy.url().should('include', '/overview')
}

// Open the plan settings drawer from the section accordion actions menu.
const openPlanSettingsDrawer = () => {
  cy.get(`[data-test="${PLAN_SETTINGS_ACCORDION_TEST_ID}-actions"]`).click({ force: true })
  cy.get(`[data-test="${PLAN_SETTINGS_EDIT_TEST_ID}"]`).click({ force: true })
  cy.get('input[name="name"]').should('exist')
}

describe('Edit plan', () => {
  beforeEach(() => {
    cy.login()
  })

  it('should be able to open and close the plan settings drawer without saving', () => {
    goToPlanDetails()
    openPlanSettingsDrawer()

    cy.get(`[data-test="${BASE_DRAWER_CLOSE_BUTTON_TEST_ID}"]`).click({ force: true })
    cy.get('[data-test="base-drawer-paper"]').should('not.exist')
    cy.url().should('include', '/overview')
  })

  it('should be able to update plan code', () => {
    goToPlanDetails()
    openPlanSettingsDrawer()

    cy.get('input[name="name"]').should('not.be.disabled')
    cy.get('input[name="code"]').should('not.be.disabled')
    cy.get('input[name="code"]').clear().type(planWithChargeCodeNew)

    cy.get('[data-test="plan-settings-drawer-save"]').should('not.be.disabled')
    cy.get('[data-test="plan-settings-drawer-save"]').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')
    cy.contains(planWithChargeCodeNew).should('exist')
  })

  it('should add plan to customer', () => {
    cy.visitApp('/customers')
    cy.get('[data-test="table-customers-list"] tr').contains(customerName).click()
    cy.get('[data-test="add-subscription"]').click()

    cy.get('input[name="planId"]').click()
    cy.get('[data-test^="combobox-item-"]').contains(planWithChargeCodeNew).click()

    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()

    cy.get('[data-test="entity-section-view-name"]').first().should('have.text', customerName)
  })

  it('should not be able to update locked fields of a used plan', () => {
    goToPlanDetails()
    openPlanSettingsDrawer()

    // Name stays editable on a used plan, code locks
    cy.get('input[name="name"]').should('not.be.disabled')
    cy.get('input[name="code"]').should('be.disabled')

    cy.get(`[data-test="${BASE_DRAWER_CLOSE_BUTTON_TEST_ID}"]`).click({ force: true })
    cy.get('[data-test="base-drawer-paper"]').should('not.exist')

    // Existing charges are displayed
    cy.get(`[data-test="${USAGE_CHARGE_ACCORDION_TEST_ID_PREFIX}0"]`).should('exist')

    // Should be able to add a new charge even on a used plan; the granular
    // mutation saves immediately when the drawer is submitted. The charge gets
    // a unique code (regenerated on each test retry) so the assertion targets
    // this exact charge instead of a count, which is unstable across retries
    // and cache-first repaints.
    const chargeCode = `e2e_charge_${Math.round(Math.random() * 100000)}`

    cy.get(`[data-test="${DETAILS_ADD_USAGE_CHARGE_TEST_ID}"]`).scrollIntoView()
    cy.get(`[data-test="${DETAILS_ADD_USAGE_CHARGE_TEST_ID}"]`).click()
    cy.get('[data-option-index]', { timeout: 30000 }).should('exist')
    cy.contains('[role="option"]', 'bm count').click({ force: true })
    cy.get('[data-test="base-drawer-paper"]').within(() => {
      cy.get('input[name="code"]').clear().type(chargeCode)
    })
    cy.get('input[name="properties.amount"]').type('3000')
    cy.get('[data-test="usage-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')

    cy.contains(chargeCode, { timeout: 10000 }).should('exist')
  })
})
