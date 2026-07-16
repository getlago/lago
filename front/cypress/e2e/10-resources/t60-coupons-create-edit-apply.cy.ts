import {
  ACTIONS_BLOCK_TEST_ID,
  ENTITY_SECTION_VIEW_NAME_TEST_ID,
} from '~/components/MainHeader/mainHeaderTestIds'

import { customerName } from '../../support/reusableConstants'

const randomId = Math.round(Math.random() * 10000)
const couponName = `Coupon ${randomId}`
const couponCode = `coupon_${randomId}`

describe('Coupons', () => {
  beforeEach(() => {
    cy.login()
  })

  it('should be able create a coupon with plan limitation', () => {
    cy.visitApp('/coupons')
    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="add-coupon"]`).click()
    cy.get('input[name="name"]').type(couponName)
    cy.get('input[name="code"]').should('have.value', couponCode)
    cy.get('input[name="amountCents"]').type('30')

    // Set plan limitation
    cy.get('[data-test="checkbox-hasPlanOrBillableMetricLimit"]').click()
    cy.get('[data-test="add-plan-limit"]').click()
    cy.get('input[name="selectedPlan"]').click()
    cy.get('[data-option-index="0"]').click()
    cy.get('[data-test="submit-add-plan-to-coupon-dialog"]').click()

    // Submit form
    cy.get('[data-test="submit"]').click()
    cy.get(`[data-test="${ENTITY_SECTION_VIEW_NAME_TEST_ID}"]`).should('contain.text', couponName)
  })

  it('should be able to edit the same coupon', () => {
    cy.visitApp('/coupons')
    cy.get(`[data-test="${couponName}"]`).click()

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="coupon-details-actions"]`).click()
    cy.get(`[data-test="coupon-details-edit"]`).click()

    cy.get('[data-test="limited-plan-0"]').within(() => {
      cy.get(`[data-test="delete-limited-plan-0"]`).click()
    })
    cy.get('[data-test="limited-plan-0"]').should('not.exist')
    cy.get('[data-test="add-plan-limit"]').click()
    cy.get('input[name="selectedPlan"]').click()
    cy.get('[data-option-index="0"]').click()
    cy.get('[data-test="submit-add-plan-to-coupon-dialog"]').click()
    cy.get('input[name="amountCents"]').type('1')

    cy.get('[data-test="submit"]').click()
    cy.get(`[data-test="${ENTITY_SECTION_VIEW_NAME_TEST_ID}"]`).should('contain.text', couponName)
  })

  it('should be able to apply the coupon to a customer', () => {
    cy.visitApp('/customers')
    cy.get('[data-test="table-customers-list"] tr', { timeout: 10000 })
      .contains(customerName)
      .click()
    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="customer-actions"]`).click()
    cy.get('[data-test="apply-coupon-action"]').click()
    cy.get('input[name="selectCoupon"]').click()
    cy.get('[data-option-index="0"]').click({ force: true })
    cy.get(`[data-test="plan-limitation-section"]`).should('exist')

    cy.pause()
    cy.get('[data-test="submit"]')
      .click()
      .then(() => {
        cy.get('[role="dialog"]', { timeout: 10000 }).should('not.exist')
        cy.get('[data-test="coupons-tab"]')
          .click()
          .then(() => {
            cy.get('[data-test="table-customer-coupons-list"]').should('contain.text', couponName)
          })
      })
  })

  it('should not be able to apply the same coupon to a customer multiple time', () => {
    cy.visitApp('/customers')
    cy.get('[data-test="table-customers-list"] tr', { timeout: 10000 })
      .contains(customerName)
      .click()
    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="customer-actions"]`).click()
    cy.get('[data-test="apply-coupon-action"]').click()
    cy.get('input[name="selectCoupon"]').click()
    cy.get('[data-option-index="0"]').click()
    cy.get('[data-test="submit"]').click()
    cy.get(`[data-test="alert-type-danger"]`).should('exist', 1)
  })

  it('should not be able to edit an applied coupon', () => {
    cy.visitApp('/coupons')
    cy.get(`[data-test="${couponName}"]`).click()

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="coupon-details-actions"]`).click()
    cy.get(`[data-test="coupon-details-edit"]`).click()

    cy.get('input[name="name"]').should('not.be.disabled')
    cy.get('input[name="code"]').should('be.disabled')
    cy.get('[data-test="checkbox-hasPlanOrBillableMetricLimit"] input').should('be.disabled')
    cy.get(`[data-test="delete-limited-plan-1"]`).should('not.exist')
  })
})
