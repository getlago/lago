import {
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_TAX_INPUT_FOR_INVOICE_ADD_ON_CLASSNAME,
} from '~/core/constants/form'

import { customerName } from '../support/reusableConstants'

describe('Create one-off', () => {
  beforeEach(() => {
    cy.login()
  })

  it('should create a one-off invoice with correct amounts', () => {
    cy.visitApp('/customers')
    cy.get('[data-test="table-customers-list"] tr').contains(customerName).click({ force: true })
    cy.get('[data-test="customer-actions"]').click({ force: true })
    cy.get('[data-test="create-invoice-action"]').click({ force: true })
    cy.url().should('include', '/create-invoice')

    // Add one item
    cy.get('[data-test="add-item-button"]').click({ force: true })
    cy.get('[data-option-index="0"]').click({ force: true })
    cy.get('[data-test="invoice-item"]').should('have.length', 1)

    // Edit its tax rate
    cy.get('[data-test="invoice-item-actions-button"]').click({ force: true })
    cy.get('[data-test="invoice-item-edit-taxes"]').click({ force: true })
    cy.get(`[data-test="add-tax-button"]`).click({ force: true })
    cy.get(`.${SEARCH_TAX_INPUT_FOR_INVOICE_ADD_ON_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`)
      .last()
      .click({ force: true })
    cy.get('[data-option-index="0"]').click({ force: true })
    cy.get('[data-test="edit-invoice-item-tax-dialog-submit-button"]').click({ force: true })

    cy.get('[role="dialog"]').should('not.exist')

    // Add another item (same add-on, default taxes only)
    cy.get('[data-test="add-item-button"]').click({ force: true })
    cy.get('[data-option-index="0"]').click({ force: true })
    cy.get('[data-test="invoice-item"]').should('have.length', 2)

    cy.get('[data-test="one-off-invoice-tax-item-0"]').should('exist')
    cy.get('[data-test="one-off-invoice-tax-item-1"]').should('exist')
    cy.get('[data-test="one-off-invoice-tax-item-2"]').should('not.exist')

    // Amount math:
    // - Add-on unit price: $3,020.00 (from seed data)
    // - 2 items x $3,020.00 = $6,040.00 subtotal
    // - Item 1 has 20% tax (twenty_tax) added manually + 10% org-level tax (ten_tax)
    // - Item 2 has only the 10% org-level tax (ten_tax) applied via billing entity
    // - 20% on $6,040.00 = $1,208.00
    // - 10% on $3,020.00 = $302.00 (applied to item with ten_tax only)
    // - Total = $6,040.00 + $1,208.00 + $302.00 = $7,550.00
    cy.get('[data-test="one-off-invoice-subtotal-value"]').should('have.text', '$6,040.00')
    cy.get('[data-test="one-off-invoice-tax-item-0-label"]').should('have.text', 'Twenty tax (20%)')
    cy.get('[data-test="one-off-invoice-tax-item-0-value"]').should('have.text', '$1,208.00')
    cy.get('[data-test="one-off-invoice-tax-item-1-label"]').should('have.text', 'Ten tax (10%)')
    cy.get('[data-test="one-off-invoice-tax-item-1-value"]').should('have.text', '$302.00')
    cy.get('[data-test="one-off-invoice-subtotal-amount-due-value"]').should(
      'have.text',
      '$7,550.00',
    )
    cy.get('[data-test="one-off-invoice-total-amount-due-value"]').should('have.text', '$7,550.00')

    cy.get('[data-test="create-invoice-button"]').click({ force: true })

    // After creation, the app navigates to the invoice detail page (overview tab)
    cy.url().should('include', '/overview')

    // Verify invoice amounts on the detail page
    cy.get('[data-test="invoice-details-table-footer-subtotal-excl-tax-value"]').should(
      'have.text',
      '$6,040.00',
    )
    cy.get('[data-test="invoice-details-table-footer-tax-0-label"]').should(
      'have.text',
      'Twenty tax (20.00% on $6,040.00)',
    )
    cy.get('[data-test="invoice-details-table-footer-tax-0-value"]').should(
      'have.text',
      '$1,208.00',
    )
    cy.get('[data-test="invoice-details-table-footer-tax-1-label"]').should(
      'have.text',
      'Ten tax (10.00% on $3,020.00)',
    )
    cy.get('[data-test="invoice-details-table-footer-tax-1-value"]').should('have.text', '$302.00')
    cy.get('[data-test="invoice-details-table-footer-subtotal-incl-tax-value"]').should(
      'have.text',
      '$7,550.00',
    )
    cy.get('[data-test="invoice-details-table-footer-total-value"]').should(
      'have.text',
      '$7,550.00',
    )
  })

  describe('anti-regression', () => {
    it('should allow to edit the units and have an effect on totals', () => {
      cy.visitApp('/customers')
      cy.get('[data-test="table-customers-list"] tr').contains(customerName).click({ force: true })
      cy.get('[data-test="customer-actions"]').click({ force: true })
      cy.get('[data-test="create-invoice-action"]').click({ force: true })
      cy.url().should('include', '/create-invoice')

      // Add one item
      cy.get('[data-test="add-item-button"]').click({ force: true })
      cy.get('[data-option-index="0"]').click({ force: true })
      cy.get('[data-test="invoice-item"]').should('have.length', 1)

      // Edit its tax rate
      cy.get('[data-test="invoice-item-actions-button"]').click({ force: true })
      cy.get('[data-test="invoice-item-edit-taxes"]').click({ force: true })
      cy.get(`[data-test="add-tax-button"]`).click({ force: true })
      cy.get(`.${SEARCH_TAX_INPUT_FOR_INVOICE_ADD_ON_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`)
        .last()
        .click({ force: true })
      cy.get('[data-option-index="0"]').click({ force: true })
      cy.get('[data-test="edit-invoice-item-tax-dialog-submit-button"]').click({ force: true })

      // Update units to 3.333
      cy.get('input[name="fees.0.units"]').clear().type('3.333')

      // Amount math:
      // - Add-on unit price: $3,020.00, units: 3.333
      // - 1 item x $3,020.00 x 3.333 = $10,065.66 subtotal (rounded)
      // - 20% tax on $10,065.66 = $2,013.13
      // - 10% tax on $10,065.66 = $1,006.57
      // - Total = $10,065.66 + $2,013.13 + $1,006.57 = $13,085.36
      cy.get('[data-test="one-off-invoice-subtotal-value"]').should('have.text', '$10,065.66')
      cy.get('[data-test="one-off-invoice-tax-item-0-label"]').should(
        'have.text',
        'Twenty tax (20%)',
      )
      cy.get('[data-test="one-off-invoice-tax-item-0-value"]').should('have.text', '$2,013.13')
      cy.get('[data-test="one-off-invoice-tax-item-1-label"]').should('have.text', 'Ten tax (10%)')
      cy.get('[data-test="one-off-invoice-tax-item-1-value"]').should('have.text', '$1,006.57')
      cy.get('[data-test="one-off-invoice-subtotal-amount-due-value"]').should(
        'have.text',
        '$13,085.36',
      )
      cy.get('[data-test="one-off-invoice-total-amount-due-value"]').should(
        'have.text',
        '$13,085.36',
      )
    })
  })
})
