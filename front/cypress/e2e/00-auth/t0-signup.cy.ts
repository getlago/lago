import {
  SIGNUP_ERROR_ALERT_TEST_ID,
  SIGNUP_PASSWORD_VALIDATION_HIDDEN_TEST_ID,
  SIGNUP_PASSWORD_VALIDATION_VISIBLE_TEST_ID,
  SIGNUP_SUBMIT_BUTTON_TEST_ID,
  SIGNUP_SUCCESS_ALERT_TEST_ID,
} from '~/pages/auth/signUpTestIds'

import { userEmail, userPassword } from '../../support/reusableConstants'

describe('Sign up', () => {
  it('should create a new user and redirect to the home after signup', () => {
    cy.visit('sign-up')

    cy.get('input[name="organizationName"]').type('Company name')
    cy.get('input[name="email"]').type(userEmail)
    cy.get('input[name="password"]').type(userPassword)
    cy.get(`[data-test="${SIGNUP_SUBMIT_BUTTON_TEST_ID}"]`).click()

    cy.url().should('match', /\/[^/]+\/(customers|analytics)/)
    cy.get('[data-test="side-nav-name"]').contains('Company name')
  })

  it('should show password validation feedback when typing', () => {
    cy.visit('sign-up')

    cy.get(`[data-test="${SIGNUP_SUBMIT_BUTTON_TEST_ID}"]`).should('not.be.disabled')
    cy.get(`[data-test="${SIGNUP_PASSWORD_VALIDATION_HIDDEN_TEST_ID}"]`).should('exist')

    cy.get('input[name="password"]').type('P@ss')
    cy.get(`[data-test="${SIGNUP_PASSWORD_VALIDATION_VISIBLE_TEST_ID}"]`).should('exist')
    cy.get(`[data-test="${SIGNUP_SUCCESS_ALERT_TEST_ID}"]`).should('not.exist')

    cy.get('input[name="password"]').type('P@ssw0rd')
    cy.get(`[data-test="${SIGNUP_SUCCESS_ALERT_TEST_ID}"]`).should('exist')
  })

  it('should display an error message if user already exists', () => {
    cy.visit('sign-up')

    cy.get(`[data-test="${SIGNUP_SUCCESS_ALERT_TEST_ID}"]`).should('not.exist')
    cy.get('input[name="organizationName"]').type('Lago')
    cy.get('input[name="email"]').type(userEmail)
    cy.get('input[name="password"]').type('P@ssw0rdd')
    cy.get(`[data-test="${SIGNUP_SUBMIT_BUTTON_TEST_ID}"]`).click()
    cy.get(`[data-test="${SIGNUP_ERROR_ALERT_TEST_ID}"]`).should('exist')
  })

  it('should display the right password error message', () => {
    cy.visit('sign-up')

    cy.get('input[name="password"]').focus()
    cy.get('[data-test="LOWERCASE"]').should('exist')
    cy.get('[data-test="UPPERCASE"]').should('exist')
    cy.get('[data-test="SPECIAL"]').should('exist')
    cy.get('[data-test="MIN"]').should('exist')
    cy.get('[data-test="NUMBER"]').should('exist')

    cy.get('input[name="password"]').type('P')
    cy.get('[data-test="LOWERCASE"]').should('exist')
    cy.get('[data-test="UPPERCASE"]').should('not.exist')
    cy.get('[data-test="SPECIAL"]').should('exist')
    cy.get('[data-test="MIN"]').should('exist')
    cy.get('[data-test="NUMBER"]').should('exist')

    cy.get('input[name="password"]').type('@')
    cy.get('[data-test="LOWERCASE"]').should('exist')
    cy.get('[data-test="UPPERCASE"]').should('not.exist')
    cy.get('[data-test="SPECIAL"]').should('not.exist')
    cy.get('[data-test="MIN"]').should('exist')
    cy.get('[data-test="NUMBER"]').should('exist')

    cy.get('input[name="password"]').type('s')
    cy.get('[data-test="LOWERCASE"]').should('not.exist')
    cy.get('[data-test="UPPERCASE"]').should('not.exist')
    cy.get('[data-test="SPECIAL"]').should('not.exist')
    cy.get('[data-test="MIN"]').should('exist')
    cy.get('[data-test="NUMBER"]').should('exist')

    cy.get('input[name="password"]').type('sw0')
    cy.get('[data-test="LOWERCASE"]').should('not.exist')
    cy.get('[data-test="UPPERCASE"]').should('not.exist')
    cy.get('[data-test="SPECIAL"]').should('not.exist')
    cy.get('[data-test="MIN"]').should('exist')
    cy.get('[data-test="NUMBER"]').should('not.exist')

    cy.get('input[name="password"]').type('rd')
    cy.get('[data-test="LOWERCASE"]').should('not.exist')
    cy.get('[data-test="UPPERCASE"]').should('not.exist')
    cy.get('[data-test="SPECIAL"]').should('not.exist')
    cy.get('[data-test="MIN"]').should('not.exist')
    cy.get('[data-test="NUMBER"]').should('not.exist')
  })
})
