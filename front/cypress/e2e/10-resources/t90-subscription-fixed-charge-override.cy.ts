import { ACTIONS_BLOCK_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'
import { FIXED_CHARGES_ADD_BUTTON_TEST_ID } from '~/components/plans/chargeTestIds'

import { customerName } from '../../support/reusableConstants'

/**
 * E2E coverage for the per-subscription fixed-charge units override.
 *
 * Verifies that:
 *   1. After editing units on a subscription's fixed charge, the subscription
 *      detail page displays the override value (read from
 *      `Subscription.fixedCharges[*].units`).
 *   2. The override survives a full page reload (Apollo cache reads from the
 *      no-cache `getSubscriptionFixedChargeUnitsOverrides` query each time).
 *
 * The test sets up its full state inline (add-on → plan with fixed charge →
 * subscription against an existing customer) so it has no implicit dependency
 * on other specs. Skipped until the BE override endpoint is deployed in the
 * CI environment — flip `describe.skip` to `describe` to enable.
 */
describe.skip('Subscription fixed charge units override', () => {
  const randomId = Math.round(Math.random() * 100000)
  const addOnName = `Fixed Charge AddOn ${randomId}`
  const addOnCode = `fc_addon_${randomId}`
  const planName = `Plan FC ${randomId}`
  const planCode = `plan_fc_${randomId}`
  const subscriptionName = `Sub FC ${randomId}`
  const baseUnits = '10'
  const overrideUnits = '25'

  before(() => {
    cy.login()

    // 1. Create an add-on to back the plan's fixed charge.
    cy.visitApp('/add-ons')
    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-addon-cta"]`).click({
      force: true,
    })
    cy.get('input[name="name"]').type(addOnName)
    cy.get('input[name="code"]').clear().type(addOnCode)
    cy.get('input[name="amountCents"]').type('30')
    cy.get('[data-test="submit"]').should('be.enabled').click()
    cy.url().should('include', '/overview')

    // 2. Create a plan, attach the add-on as a fixed charge with baseUnits.
    cy.visitApp('/plans')
    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-plan"]`).click({
      force: true,
    })
    cy.url().should('match', /\/[^/]+\/create\/plans$/)
    cy.get('input[name="name"]').type(planName)
    cy.get('input[name="code"]').clear().type(planCode)
    cy.get('input[name="amountCents"]').type('5000')

    cy.get(`[data-test="${FIXED_CHARGES_ADD_BUTTON_TEST_ID}"]`).scrollIntoView().click({
      force: true,
    })

    // Pick the add-on we just created (combobox is searchable).
    cy.get('input[name="addOnId"]').click({ force: true })
    cy.contains('[role="option"]', addOnName).click({ force: true })
    cy.get('input[name="units"]').clear().type(baseUnits)
    cy.get('[data-test="fixed-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')

    cy.get('[data-test="submit"]').click({ force: true })
    cy.url().should('include', '/overview')

    // 3. Subscribe an existing customer to the new plan.
    cy.visitApp('/customers')
    cy.get('[data-test="table-customers-list"] tr').contains(customerName).click({ force: true })
    cy.get('[data-test="add-subscription"]').click({ force: true })
    cy.url().should('include', '/create/subscription')

    cy.get('input[name="planId"]').click({ force: true })
    cy.contains('[role="option"]', planName).click({ force: true })

    cy.get('[data-test="create-subscription-form-wrapper"]').within(() => {
      cy.get('[data-test="show-name"]').click({ force: true })
      cy.get('input[name="name"]').first().type(subscriptionName)
    })
    cy.get('[data-test="submit"]').should('not.be.disabled').click({ force: true })
    cy.get(`[data-test="${subscriptionName}"]`, { timeout: 15000 }).should('exist')
  })

  it('displays the override units after editing units on the subscription, and persists across reload', () => {
    cy.login().visitApp('/customers')
    cy.get('[data-test="table-customers-list"] tr').contains(customerName).click({ force: true })
    cy.get(`[data-test="${subscriptionName}"]`, { timeout: 15000 }).click({ force: true })

    // Open the Plan tab on the subscription detail page.
    cy.contains('[role="tab"]', /plan/i).click({ force: true })

    // The base units (plan default) should appear first.
    cy.contains(addOnCode).should('exist')
    cy.contains(addOnCode).parents('[role="button"]').first().click({ force: true })
    cy.contains(baseUnits).should('exist')

    // Open the edit drawer via the actions menu and update units.
    cy.get('button[aria-label="actions"]').first().click({ force: true })
    cy.contains('button', /edit/i).click({ force: true })
    cy.get('input[name="units"]').clear().type(overrideUnits)
    cy.get('[data-test="fixed-charge-drawer-save"]').should('not.be.disabled').click()
    cy.get('[data-test="base-drawer-paper"]', { timeout: 10000 }).should('not.exist')

    // After the mutation, the override units should be displayed.
    cy.contains(overrideUnits, { timeout: 10000 }).should('exist')

    // Reload — the override is read from Subscription.fixedCharges (no-cache),
    // so the displayed value must still be the override, not the plan default.
    cy.reload()
    cy.contains('[role="tab"]', /plan/i).click({ force: true })
    cy.contains(addOnCode).parents('[role="button"]').first().click({ force: true })
    cy.contains(overrideUnits, { timeout: 10000 }).should('exist')

    // And the plan-scope page must keep showing the plan default (no cache
    // bleed from the per-subscription override). Navigate to the plan view.
    cy.visitApp('/plans')
    cy.contains('tr', planName).click({ force: true })
    cy.contains(addOnCode).parents('[role="button"]').first().click({ force: true })
    cy.contains(baseUnits).should('exist')
  })
})
