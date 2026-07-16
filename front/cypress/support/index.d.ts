/// <reference types="cypress" />

declare namespace Cypress {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface Chainable<Subject> {
    /**
     * Login user. Captures the org slug from the post-login URL and stores
     * it in `Cypress.env('orgSlug')` so subsequent `cy.visitApp()` calls
     * work without manual setup.
     * @example
     * cy.login('usertest@lago.com', 'P@ssw0rd')
     */
    login(email?: string, password?: string): Chainable<unknown>

    /**
     * Logout current user. Clears the captured org slug so any subsequent
     * `cy.visitApp()` call throws unless re-login/signup happens first.
     * @example
     * cy.logout()
     */
    logout(): Chainable<unknown>

    /**
     * Signup user. Same slug-capture behavior as `cy.login()`.
     * @example
     * cy.signup({ organizationName: 'Lago', email: 'user@lago.com', password: 'P@ssw0rd' })
     */
    signup({
      organizationName,
      email,
      password,
    }: {
      organizationName: string
      email: string
      password: string
    }): Chainable<unknown>

    /**
     * Slug-aware `cy.visit()` wrapper. Prepends `/${orgSlug}` to
     * authenticated paths; public paths (`/login`, `/sign-up`, `/invitation`,
     * `/customer-portal`, `/forbidden`, `/404`, `/password-reset`,
     * `/forgot-password`) pass through unchanged.
     *
     * Requires `cy.login()` or `cy.signup()` to have been called first.
     *
     * @example
     * cy.visitApp('/customers')            // → /${slug}/customers
     * cy.visitApp('/login')                // → /login (public, unchanged)
     */
    visitApp(path: string): Chainable<Cypress.AUTWindow>
  }

  interface Cypress {
    mocha: any // for Cypress.mocha
  }
}
