import { DateTime } from 'luxon'

import { customerName } from '../support/reusableConstants'

describe('Subscriptions', () => {
  beforeEach(() => {
    cy.login().visitApp('/customers')
    cy.get('[data-test="table-customers-list"] tr').contains(customerName).click()
  })

  const subscriptionName = `Subscription-${Math.round(Math.random() * 10000)}`
  const subscriptionAt = DateTime.now().plus({ days: 7 }).toISO()
  const inputFormattedDate = DateTime.fromISO(subscriptionAt as string).toFormat('LL/dd/yyyy')

  it('should be able to add a subscription in the future to customer', () => {
    cy.get(`[data-test="add-subscription"]`).click({ force: true })
    cy.url().should('include', '/create/subscription')

    // Submit without selecting a plan — should show validation error
    cy.get('[data-test="submit"]').should('not.be.disabled').click()
    cy.get('input[name="planId"]').should('exist')

    // Select a plan from the combobox — form sections appear
    cy.get('input[name="planId"]').click({ force: true })
    cy.get('[data-option-index="0"]', { timeout: 10000 }).click({ force: true })

    cy.get('[data-test="create-subscription-form-wrapper"]').within(() => {
      // Set subscription date
      cy.get('input[name="subscriptionAt"]')
        .clear({ force: true })
        .type(inputFormattedDate, { force: true })

      // Show and fill subscription name (hidden by default for new subscriptions)
      cy.get('[data-test="show-name"]').click()
      cy.get('input[name="name"]').first().type(subscriptionName)
    })

    cy.get('[data-test="submit"]').should('not.be.disabled').click()
    cy.get('[data-test="submit"]').should('not.exist')
    cy.get(`[data-test="${subscriptionName}"]`).should('exist')
  })

  it('should be able to cancel a future subscription', () => {
    cy.get(`[data-test="${subscriptionName}"]`).should('exist')
    cy.get(`[data-test="${subscriptionName}"]`).click({ force: true })

    cy.get('[data-test="status"]').should('have.text', 'Pending')
    cy.get('[data-test="subscription-details-actions"]').click()
    cy.get('[data-test="subscription-details-terminate"]').click()

    // Pending subscriptions use a CentralizedDialog (not FormDialog)
    cy.get('[data-test="centralized-confirm"]').click({ force: true })
  })
})
