import {
  FEE_ACTIONS_BUTTON_TEST_ID,
  FEE_COPY_ID_BUTTON_TEST_ID,
  FEE_VIEW_DETAILS_BUTTON_TEST_ID,
  VIEW_FEE_DETAILS_DRAWER_TEST_ID,
} from '~/components/invoices/details/invoiceDetailsTestIds'

import { customerName } from '../../support/reusableConstants'

/**
 * E2E coverage for the View Fee Details drawer flow on a finalized invoice.
 *
 * Prerequisite: the seeded test customer (`customerName`) must have at least
 * one invoice with one or more fees. The existing one-off-invoice flow in
 * `t30-create-one-off-invoice.cy.ts` produces such an invoice when enabled.
 */
describe.skip('Invoice fee details', () => {
  beforeEach(() => {
    cy.login().visitApp('/customers')

    // Navigate to the seeded customer's Invoices tab
    cy.get('[data-test="table-customers-list"] tr').contains(customerName).click({ force: true })
    cy.get('[data-test="customer-navigation-wrapper"]').within(() => {
      cy.get('[role="tab"]').contains('Invoices').click({ force: true })
    })

    // Open the first invoice
    cy.get('#table-customer-invoices-row-0').click({ force: true })
    cy.url().should('include', '/overview')
  })

  it('should open the View fee details drawer when clicking a fee row', () => {
    // Click the first clickable fee row (data-test starts with "fee-row-")
    cy.get('[data-test^="fee-row-"]').first().click({ force: true })

    // Drawer should appear
    cy.get(`[data-test="${VIEW_FEE_DETAILS_DRAWER_TEST_ID}"]`).should('exist')

    // Close the drawer via the Close button in the sticky footer
    cy.get('[role="presentation"]').within(() => {
      cy.contains('button', /close/i).click({ force: true })
    })
    cy.get(`[data-test="${VIEW_FEE_DETAILS_DRAWER_TEST_ID}"]`).should('not.exist')
  })

  it('should open the fee actions menu and copy the fee ID without opening the drawer', () => {
    // Click the 3-dots button on the first fee row
    cy.get('[data-test^="fee-row-"]')
      .first()
      .within(() => {
        cy.get(`[data-test="${FEE_ACTIONS_BUTTON_TEST_ID}"]`).click({ force: true })
      })

    // The popper menu shows Copy fee ID + View fee details actions
    cy.get(`[data-test="${FEE_COPY_ID_BUTTON_TEST_ID}"]`).should('exist')
    cy.get(`[data-test="${FEE_VIEW_DETAILS_BUTTON_TEST_ID}"]`).should('exist')

    // The drawer should NOT have opened just from the menu being shown
    cy.get(`[data-test="${VIEW_FEE_DETAILS_DRAWER_TEST_ID}"]`).should('not.exist')

    // Click Copy fee ID
    cy.get(`[data-test="${FEE_COPY_ID_BUTTON_TEST_ID}"]`).click({ force: true })

    // Toast confirmation appears, drawer still closed
    cy.contains(/copied to clipboard/i).should('exist')
    cy.get(`[data-test="${VIEW_FEE_DETAILS_DRAWER_TEST_ID}"]`).should('not.exist')
  })
})
