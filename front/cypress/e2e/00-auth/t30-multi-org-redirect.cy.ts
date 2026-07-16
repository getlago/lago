import {
  CREATE_CUSTOMER_DATA_TEST,
  SUBMIT_CUSTOMER_DATA_TEST,
} from '~/components/customers/utils/dataTestConstants'
import { ACTIONS_BLOCK_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'

// Note: some login are done manually without using cy.login command
// to preserve the router state needed for redirect testing
// otherwise, cy.login breaks the redirection logic as it manually navigate to /login route

// Use unique credentials to avoid conflicts with other tests
const testUsers = {
  userA: {
    email: 'multi-orga-user-a+3@lago.com',
    password: 'Multi0rgT3st!',
    org1Name: 'Multi Org Test - Organization A',
  },
  userB: {
    email: 'multi-orga-user-b+3@lago.com',
    password: 'Multi0rgT3st!',
    org2Name: 'Multi Org Test - Organization B',
  },
}

describe('Multi-organization redirect flows', () => {
  let invitationUrl = ''

  // Setup: Create two organizations and make User A a member of both
  before(() => {
    // 1. User A creates Org1
    cy.signup({
      organizationName: testUsers.userA.org1Name,
      email: testUsers.userA.email,
      password: testUsers.userA.password,
    })

    // Logout User A
    cy.logout()

    // 2. User B creates Org2
    cy.signup({
      organizationName: testUsers.userB.org2Name,
      email: testUsers.userB.email,
      password: testUsers.userB.password,
    })

    // Wait for session to be fully established
    cy.url().should('not.include', '/sign-up')
    // Ensure the user is authenticated by checking for the side nav
    cy.get('[data-test="side-nav-user-infos"]', { timeout: 10000 }).should('be.visible')

    // 3. User B invites User A to Org2 as admin
    // Navigate to settings using UI to ensure session is maintained
    cy.get('[data-test="side-nav-user-infos"]').click()
    cy.contains('Settings').click()
    cy.url().should('include', '/settings')

    // Navigate to members tab
    cy.contains('Team & Security').click()
    cy.url().should('include', '/settings/team-and-security')
    // Wait for the page to load
    cy.get('[data-test="create-invite-button"]', { timeout: 10000 }).should('be.visible')
    cy.get('[data-test="create-invite-button"]').click()
    cy.get('input[name="email"]').type(testUsers.userA.email)
    // Select Admin role from the role picker combobox
    cy.get('input[name="role"]').click()
    cy.get('[data-option-index="0"]').click() // Select Admin (first option)
    cy.get('[data-test="submit-invite-button"]').click()

    // Wait for invitation to be created and get the URL from the UI
    cy.get('[data-test="invitation-url"]', { timeout: 10000 })
      .should('be.visible')
      .then(($link) => {
        // Get the href attribute which contains the full URL
        invitationUrl = $link.attr('href') || $link.text().trim()
        cy.log('Invitation URL captured:', invitationUrl)

        // Force a full page navigation by visiting the URL
        // This will clear the session and disconnect User B
        cy.visit(invitationUrl, { failOnStatusCode: false })
      })

    // 5. User A accepts the invitation to Org2 - enter the same password to avoid DB issues
    cy.url().should('include', '/invitation/')
    cy.get('input[name="password"]', { timeout: 10000 }).should('be.visible')
    cy.get('input[name="password"]').type(testUsers.userA.password)
    cy.get('[data-test="submit-button"]').click()

    // User A should now have access to both organizations
    cy.url().should('match', /\/(analytics|customers)/)
    // Ensure the orga switcher shows two organizations
    cy.get('[data-test="side-nav-user-infos"]').click()
    cy.contains(testUsers.userA.org1Name).should('exist')
    cy.contains(testUsers.userB.org2Name).should('exist')

    // Logout to prepare for actual tests - doing it manually as the orga switcher is already open
    cy.get('[data-test="side-nav-logout"]').click()
  })

  beforeEach(() => {
    // Clean session before each test
    cy.clearCookies()
    cy.clearLocalStorage()
  })

  describe('Cross-organization redirect protection', () => {
    it('should NOT redirect to Org1 resource when logged into Org2', () => {
      // 1. Login as User A (will land in one of the orgs)
      cy.login(testUsers.userA.email, testUsers.userA.password)
      // 2. Ensure we're in Org1 by clicking on orga 1
      cy.get('[data-test="side-nav-user-infos"]').click()
      cy.contains(testUsers.userA.org1Name).click()
      // 3. Create a customer in Org1
      cy.visitApp('/customers')
      cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="${CREATE_CUSTOMER_DATA_TEST}"]`, {
        timeout: 10000,
      }).click()
      cy.get('input[name="name"]').type('Customer Org1 Multi-Org Test')
      cy.get('input[name="externalId"]').type(`customer-org1-${Date.now()}`)
      cy.get(`[data-test="${SUBMIT_CUSTOMER_DATA_TEST}"]`).click()
      cy.url().should('include', '/customer/')
      // Save the customer URL from Org1
      cy.url().then((org1CustomerUrl) => {
        const customerIdMatch = org1CustomerUrl.match(/\/customer\/([^/]+)/)
        const org1CustomerId = customerIdMatch ? customerIdMatch[1] : null
        cy.log('Org1 Customer ID:', org1CustomerId)
        // 4. logout, visit orga 1 url and login with customer in org2.
        // Slug-less path is intentional: the test probes what happens when
        // a logged-out user visits a legacy cross-org URL. Auth guard fires,
        // saves state, redirects to login. After login as User B, Home.tsx
        // cannot resolve a slug from `location.state.from` so falls to the
        // permission-based default (Org2 home).
        cy.logout()
        cy.visit(`/customer/${org1CustomerId}`)
        cy.get('input[name="email"]').type(testUsers.userB.email)
        cy.get('input[name="password"]').type(testUsers.userB.password)
        cy.get('[data-test="submit"]').click()
        // 5. Verify we're now in Org2 on home page (not the Org1 customer page)
        cy.url().should('not.include', `/customer/${org1CustomerId}`)
        cy.url().should('match', /\/(analytics|customers)/)
        cy.get('[data-test="side-nav-user-infos"]').should('contain', testUsers.userB.org2Name)
      })
    })
  })

  describe('Organization switching redirect behavior', () => {
    it('should redirect to home when switching orgs from deep page', () => {
      // 1. Login as User A
      cy.login(testUsers.userA.email, testUsers.userA.password)

      // 2. Navigate to a deep page (e.g., customers/:id)
      // Create a customer to get a deep link
      cy.visitApp('/customers')
      cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="${CREATE_CUSTOMER_DATA_TEST}"]`, {
        timeout: 10000,
      }).click()
      cy.get('input[name="name"]').type('Customer for Org Switch Test')
      cy.get('input[name="externalId"]').type(`customer-org-switch-${Date.now()}`)
      cy.get(`[data-test="${SUBMIT_CUSTOMER_DATA_TEST}"]`).click()
      cy.url().should('include', '/customer/')

      const urlToAvoidAfterLogin = cy.url()

      // 3. switch organizations
      cy.get('[data-test="side-nav-user-infos"]', { timeout: 10000 }).click()
      cy.contains(testUsers.userB.org2Name).click()

      // Make sure we're on home page of Org2 (not the deep link)
      cy.url().should('match', /\/(analytics|customers)/)
      cy.url().should('not.equal', urlToAvoidAfterLogin)
    })

    it('should preserve query params after logout', () => {
      // 1. Login as User A
      cy.login(testUsers.userA.email, testUsers.userA.password)

      // 2. Navigate to customers with query params
      cy.visitApp('/customers?search=test&page=2')
      cy.url().should('include', 'search=test')
      cy.url().should('include', 'page=2')

      // 3. logout
      cy.logout()
      // 4. Login again
      cy.get('input[name="email"]').type(testUsers.userA.email)
      cy.get('input[name="password"]').type(testUsers.userA.password)
      cy.get('[data-test="submit"]').click()

      // 5. Should preserve query params after login
      cy.url().should('include', 'search=test')
      cy.url().should('include', 'page=2')
    })
  })

  // Cleanup after all tests
  after(() => {
    cy.clearCookies()
    cy.clearLocalStorage()
  })
})
