import {
  CREATE_CUSTOMER_DATA_TEST,
  SUBMIT_CUSTOMER_DATA_TEST,
} from '~/components/customers/utils/dataTestConstants'
import { ACTIONS_BLOCK_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'

import { customerName } from '../../support/reusableConstants'

describe('Create customer', () => {
  beforeEach(() => {
    cy.login().visitApp('/customers')
  })

  it('should create customer', () => {
    const randomNumber = Math.round(Math.random() * 1000)

    cy.get(
      `[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="${CREATE_CUSTOMER_DATA_TEST}"]`,
    ).click()

    cy.url().should('include', '/customer/create')

    cy.get('input[name="externalId"]').type(`id-george-de-la-jungle-${randomNumber}`)

    cy.get('input[name="name"]').should('exist').type(customerName)

    cy.get(`[data-test="${SUBMIT_CUSTOMER_DATA_TEST}"]`).click()

    cy.url().should('include', '/customer/')

    cy.contains(customerName).should('exist')
  })

  describe('anti-regression', () => {
    // https://github.com/getlago/lago-front/pull/892
    it('should be able to edit VAT right after creating a customer', () => {
      const randomNumber = Math.round(Math.random() * 1000)
      const randomId = `Customer ${randomNumber}`

      cy.get(
        `[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="${CREATE_CUSTOMER_DATA_TEST}"]`,
      ).click()
      cy.get('input[name="name"]').type(randomId)
      cy.get(`[data-test="${SUBMIT_CUSTOMER_DATA_TEST}"]`).click()
      // Check validation for external ID
      cy.get('[data-test="text-field-error"]').should('exist')
      cy.get('input[name="externalId"]').type(randomId)
      cy.get(`[data-test="${SUBMIT_CUSTOMER_DATA_TEST}"]`).click()
      cy.url().should('include', '/customer/')
      cy.contains(randomId).should('exist')

      cy.get('button[role="tab"]').contains('Settings').click()
      cy.get('[data-test="add-vat-rate-button"]').last().click()
      cy.get('[data-test="edit-customer-vat-rate-dialog"]').should('exist')
    })
  })
})
