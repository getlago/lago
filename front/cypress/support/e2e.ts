// ***********************************************************
// This example support/e2e.ts is processed and
// loaded automatically before your test files.
// ***********************************************************
import { NEVER_SLUG_PREFIXES } from '~/core/router/slugPrefixes'
import { SIGNUP_SUBMIT_BUTTON_TEST_ID } from '~/pages/auth/signUpTestIds'

import { userEmail, userPassword } from './reusableConstants'

/**
 * Paths that pass through `cy.visitApp()` unchanged (no slug prepended).
 *
 * Extends the app's `NEVER_SLUG_PREFIXES` with auth entry pages that are
 * reachable only from outside the app (signup, invitation, password reset)
 * — those aren't in `NEVER_SLUG_PREFIXES` because the in-app wrappers
 * (`useNavigate` / `<Link>`) never build `navigate('/sign-up')` calls, but
 * Cypress tests do visit those pages directly.
 *
 * Importing `NEVER_SLUG_PREFIXES` from the source keeps the two lists in
 * sync — any new public route added there is reflected here automatically.
 */
const PUBLIC_PATHS = [
  ...NEVER_SLUG_PREFIXES,
  '/sign-up',
  '/invitation',
  '/password-reset',
  '/forgot-password',
]

/**
 * Regex matching the first authenticated URL after login/signup.
 * `Home.tsx` redirects to `/${slug}/customers` or `/${slug}/analytics`
 * depending on the user's permissions.
 */
const POST_AUTH_URL_RE = /\/[^/]+\/(customers|analytics)/

/**
 * Module-scoped org slug captured by `cy.login()` / `cy.signup()` and read
 * by `cy.visitApp()`. Preferred over `Cypress.env('orgSlug', value)` because
 * Cypress deprecated the 2-arg setter overload. Module-scoped state is
 * fine here: Cypress loads this support file once per spec run, and tests
 * that need a different slug re-login/signup (both re-capture).
 */
let capturedOrgSlug: string | undefined

/**
 * Extracts the org slug from the current URL and stores it for subsequent
 * `cy.visitApp()` calls in the same spec.
 */
const captureOrgSlugFromUrl = (): void => {
  cy.url()
    .should('match', POST_AUTH_URL_RE)
    .then((url) => {
      const slug = new URL(url).pathname.split('/')[1]

      if (!slug) throw new Error(`Could not extract org slug from URL: ${url}`)
      capturedOrgSlug = slug
    })
}

Cypress.Commands.add('login', (email = userEmail, password = userPassword) => {
  cy.visit('/login')
  cy.get('input[name="email"]').type(email)
  cy.get('input[name="password"]').type(password)
  cy.get('[data-test="submit"]').click()
  captureOrgSlugFromUrl()
})

Cypress.Commands.add('logout', () => {
  cy.get('[data-test="side-nav-user-infos"]').click()
  cy.get('[data-test="side-nav-logout"]').click()
  cy.url().should('include', '/login')
  // Clear the captured slug — subsequent login/signup must re-capture it.
  capturedOrgSlug = undefined
})

Cypress.Commands.add(
  'signup',
  ({
    organizationName,
    email,
    password,
  }: {
    organizationName: string
    email: string
    password: string
  }) => {
    cy.visit('sign-up')
    cy.get('input[name="organizationName"]').type(organizationName)
    cy.get('input[name="email"]').type(email)
    cy.get('input[name="password"]').type(password)
    cy.get(`[data-test="${SIGNUP_SUBMIT_BUTTON_TEST_ID}"]`).click()
    captureOrgSlugFromUrl()
  },
)

/**
 * Slug-aware wrapper around `cy.visit()`. Prepends `/${orgSlug}` to any
 * absolute authenticated path so spec files can keep writing
 * `cy.visitApp('/customers')` while the actual navigation targets
 * `/${slug}/customers`. Public paths (login/signup/invitation/…) pass
 * through unchanged.
 *
 * Requires `cy.login()` or `cy.signup()` to have been called first so
 * the slug is available.
 */
Cypress.Commands.add('visitApp', (path: string) => {
  const isPublic = PUBLIC_PATHS.some((p) => path.startsWith(p))

  if (isPublic) {
    return cy.visit(path)
  }

  if (!capturedOrgSlug) {
    throw new Error(
      `cy.visitApp('${path}') called without a captured org slug. Call cy.login() or cy.signup() first.`,
    )
  }

  const normalized = path.startsWith('/') ? path : `/${path}`

  return cy.visit(`/${capturedOrgSlug}${normalized}`)
})

// https://docs.cypress.io/api/cypress-api/custom-commands#Overwrite-type-command
// @ts-expect-error custom command
Cypress.Commands.overwrite('type', (originalFn, element, text, options) => {
  // @ts-expect-error custom options
  return originalFn(element, text, { ...options, delay: 0 })
})

beforeEach(() => {
  // Allow access to broswer's clipboard api
  Cypress.automation('remote:debugger:protocol', {
    command: 'Browser.grantPermissions',
    params: {
      permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'],
      origin: window.location.origin,
    },
  })
})
