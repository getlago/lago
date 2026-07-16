// Note: some login are done manually without using cy.login command
// to preserve the router state needed for redirect testing
// otherwise, cy.login breaks the redirection logic as it manually navigate to /login route

// Use unique credentials for this test to avoid conflicts with other tests
const testUser = {
  email: 'auth-redirect-test@lago.com',
  email2: 'auth-redirect-test2@lago.com',
  password: 'AuthR3dir3ct!',
  org1Name: 'Auth Test Org Primary',
  org2Name: 'Auth Test Org Secondary',
}

describe('Authentication redirect flows', () => {
  beforeEach(() => {
    // Clean up any existing session before each test
    cy.clearLocalStorage()
    cy.clearCookies()
  })

  describe('Basic redirect after logout', () => {
    it('should redirect to intended destination after logout and login', () => {
      // 1. Create new organization
      cy.signup({
        organizationName: testUser.org1Name,
        email: testUser.email,
        password: testUser.password,
      })
      cy.url().should('include', Cypress.config().baseUrl)
      cy.get('[data-test="side-nav-name"]').contains(testUser.org1Name)

      // 2. Navigate to a specific page (customers list)
      cy.visitApp('/customers')
      cy.url().should('include', '/customers')

      // 3. Logout
      cy.logout()
      // 4. Login again
      cy.get('input[name="email"]').type(testUser.email)
      cy.get('input[name="password"]').type(testUser.password)
      cy.get('[data-test="submit"]').click()

      // 5. Should be redirected back to /customers (not default home)
      cy.url().should('include', '/customers')
      cy.url().should('not.equal', Cypress.config().baseUrl + '/')
    })

    it('should redirect to new intended destination after logout and login', () => {
      // 1. Create new organization
      cy.signup({
        organizationName: testUser.org2Name,
        email: testUser.email2,
        password: testUser.password,
      })
      cy.url().should('include', Cypress.config().baseUrl)

      // 2. Navigate to a specific page (customers list)
      cy.visitApp('/customers')
      cy.url().should('include', '/customers')

      // 3. Logout
      cy.logout()

      // 4. Try to access the plans page (should redirect to login with saved state).
      // Intentionally uses a slug-less path here: the auth guard fires before
      // `OrganizationLayout` can resolve anything, saves `location.state.from`,
      // and redirects to `/login`. After re-login, `Home.tsx` restores the
      // saved path and prepends the current org slug.
      cy.visit('/plans')
      cy.url().should('include', '/login')

      // 5. Login again
      cy.get('input[name="email"]').type(testUser.email2)
      cy.get('input[name="password"]').type(testUser.password)
      cy.get('[data-test="submit"]').click()

      // 6. Should be redirected to /plans (not default home nor /customers)
      cy.url().should('include', '/plans')
      cy.url().should('not.equal', Cypress.config().baseUrl + '/')
    })

    it('should redirect to default home if accessing root path after logout', () => {
      // Login
      cy.login(testUser.email, testUser.password)

      // Logout
      cy.logout()

      // We should be on login page now, so login again
      cy.login(testUser.email, testUser.password)

      // Should go to default home (based on permissions)
      cy.url().should('match', /\/(analytics)/)
    })
  })

  describe('Session expiration redirect', () => {
    it('should redirect back after session expiration and re-login', () => {
      // Login
      cy.login(testUser.email, testUser.password)

      // Navigate to a specific page
      cy.visitApp('/settings/taxes')
      cy.url().should('include', '/settings/taxes')

      // Simulate session expiration by clearing auth token
      cy.clearLocalStorage('authToken')

      // Try to navigate to another protected page (should redirect to login).
      // Slug-less path is intentional: no valid session → auth guard catches
      // this before slug resolution and redirects to `/login`.
      cy.visit('/customers')
      cy.url().should('include', '/login')

      // Login again
      cy.get('input[name="email"]').type(testUser.email)
      cy.get('input[name="password"]').type(testUser.password)
      cy.get('[data-test="submit"]').click()

      // Should be redirected to /customers (the page we tried to access)
      cy.url().should('include', '/customers')
    })
  })

  describe('Edge cases and corner scenarios', () => {
    it('should handle navigation to public pages while authenticated', () => {
      // Login
      cy.login(testUser.email, testUser.password)

      // Try to access login page while authenticated
      cy.visit('/login')

      // Should be redirected to home, not stay on login
      cy.url().should('not.include', '/login')
      cy.url().should('match', /\/(analytics|customers)/)
    })

    it('should preserve query parameters in redirect', () => {
      // Login
      cy.login(testUser.email, testUser.password)

      // Navigate to page with query params
      cy.visitApp('/customers?search=test&status=active')
      cy.url().should('include', 'search=test')
      cy.url().should('include', 'status=active')

      // Logout
      cy.logout()

      // Try to access the same page with query params (slug-less intentionally
      // — logged out → auth guard redirects to `/login` with saved state).
      cy.visit('/customers?search=test&status=active')
      cy.url().should('include', '/login')

      // Login
      cy.get('input[name="email"]').type(testUser.email)
      cy.get('input[name="password"]').type(testUser.password)
      cy.get('[data-test="submit"]').click()

      // Should preserve query parameters in redirect
      cy.url().should('include', '/customers')
      cy.url().should('include', 'search=test')
      cy.url().should('include', 'status=active')
    })
  })

  // Cleanup after all tests in this file
  after(() => {
    // Note: In a real scenario, you might want to delete the test organizations
    // via API calls to keep the test database clean
    cy.clearCookies()
    cy.clearLocalStorage()
  })
})
