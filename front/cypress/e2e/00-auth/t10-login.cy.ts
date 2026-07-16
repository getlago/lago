import { userEmail, userPassword } from '../../support/reusableConstants'

describe('Log in', () => {
  it('should redirect to home page if right credentials', () => {
    cy.visit('login')
    cy.get('input[name="email"]').type(userEmail)
    cy.get('input[name="password"]').type(userPassword)
    cy.get('[data-test="submit"]').click()

    cy.url().should('match', /\/[^/]+\/(customers|analytics)/)
    cy.get('[data-test="incorrect-login-or-password-alert"]').should('not.exist')
  })

  it('should display an error if wrong credentials', () => {
    cy.visit('/login')

    cy.get('input[name="email"]').type(userEmail)
    cy.get('input[name="password"]').type('IHateLago')
    cy.get('[data-test="submit"]').click()
    cy.url().should('be.equal', Cypress.config().baseUrl + '/login')
    cy.get('[data-test="incorrect-login-or-password-alert"]').should('exist')
  })

  it('should display errors if inputs are not filled', () => {
    cy.visit('/login')

    cy.get('[data-test="submit"]').click()
    cy.url().should('be.equal', Cypress.config().baseUrl + '/login')
    cy.get('[data-test="text-field-error"]').should('have.length', 2)
  })

  it('should redirect on sign up on link click', () => {
    cy.visit('/login')

    cy.get('[href="/sign-up"]').click()
    cy.url().should('be.equal', Cypress.config().baseUrl + '/sign-up')
  })
})
