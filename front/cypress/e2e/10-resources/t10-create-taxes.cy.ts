import {
  APPLY_TAX_BUTTON_TEST_ID,
  APPLY_TAX_DIALOG_SUBMIT_BUTTON_TEST_ID,
} from '~/pages/settings/BillingEntity/sections/taxes/dataTestConstants'

import {
  TAX_TEN_CODE,
  TAX_TEN_NAME,
  TAX_TWENTY_CODE,
  TAX_TWENTY_NAME,
} from '../../support/reusableConstants'

describe('Create taxes', () => {
  beforeEach(() => {
    cy.login()
  })

  it('should create taxes', () => {
    cy.visitApp('/settings/taxes')
    cy.url().should('include', '/settings/taxes')

    // Make sure no tax exists
    cy.get('[data-test="table-tax-settings-taxes"]').should('not.exist')

    // Create tax 10%
    cy.get('[data-test="create-tax-button"]').click()
    cy.url().should('include', '/create/tax')
    cy.get('input[name="name"]').type(TAX_TEN_NAME)
    cy.get('input[name="code"]').should('have.value', TAX_TEN_CODE)
    cy.get('input[name="rate"]').type('10')
    cy.get('[data-test="submit"]').click()

    // Create tax 20%
    cy.get('[data-test="create-tax-button"]').click()
    cy.url().should('include', '/create/tax')
    cy.get('input[name="name"]').type(TAX_TWENTY_NAME)
    cy.get('input[name="code"]').should('have.value', TAX_TWENTY_CODE)
    cy.get('input[name="rate"]').type('20')
    cy.get('[data-test="submit"]').click()

    cy.get(`[data-test="${TAX_TEN_CODE}"]`).should('exist')
    cy.get(`[data-test="${TAX_TWENTY_CODE}"]`).should('exist')
  })

  it('should assign tax to billing entity', () => {
    // Navigate to settings — auto-redirects to default billing entity page
    // after the billing entities GraphQL query resolves
    cy.visitApp('/settings')
    cy.url().should('include', '/billing-entity/')

    // Extract billing entity code from redirected URL
    cy.url().then((url) => {
      const match = url.match(/billing-entity\/([^/]+)/)
      const billingEntityCode = match?.[1] as string

      // Navigate to the billing entity's taxes settings
      cy.visitApp(`/settings/billing-entity/${billingEntityCode}/taxes`)
      cy.url().should('include', `/settings/billing-entity/${billingEntityCode}/taxes`)

      // Make sure no taxes are already assigned
      cy.get('[data-test="table-billing-entity-taxes"]').should('not.exist')

      // Apply the 20% tax to the billing entity
      cy.get(`[data-test="${APPLY_TAX_BUTTON_TEST_ID}"]`).click()
      cy.get(`[data-test="${APPLY_TAX_DIALOG_SUBMIT_BUTTON_TEST_ID}"]`).should('exist')

      // Search and select the tax in the ComboBox
      cy.get('input[name="billingEntityApplyTaxes"]').click()
      cy.get('input[name="billingEntityApplyTaxes"]').type(TAX_TWENTY_NAME)
      cy.get('[data-option-index="0"]').click()

      // Submit the dialog
      cy.get(`[data-test="${APPLY_TAX_DIALOG_SUBMIT_BUTTON_TEST_ID}"]`).click()

      // Verify the tax appears in the table
      cy.get('[data-test="table-billing-entity-taxes"]').should('exist')
      cy.get(`[data-test="${TAX_TWENTY_CODE}"]`).should('exist')
    })
  })
})
