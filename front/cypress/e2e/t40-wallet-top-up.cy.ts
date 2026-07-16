import {
  CREATE_CUSTOMER_DATA_TEST,
  SUBMIT_CUSTOMER_DATA_TEST,
} from '~/components/customers/utils/dataTestConstants'
import { DESKTOP_ACTIONS_BLOCK_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'
import {
  CREATE_WALLET_DATA_TEST,
  SUBMIT_WALLET_DATA_TEST,
  WALLET_ACTIONS_DATA_TEST,
  WALLET_TOPUP_BUTTON_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import {
  TOPUP_TYPE_FREE_CREDITS_DATA_TEST,
  TOPUP_TYPE_PREPAID_CREDITS_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'

const randomId = Math.round(Math.random() * 10000)
const walletCustomerName = `Wallet Customer ${randomId}`
const walletCustomerExternalId = `wallet-customer-${randomId}`

describe('Wallet Top-Up', () => {
  before(() => {
    // Create a customer and a wallet as prerequisites
    cy.login().visitApp('/customers')

    // Create customer
    cy.get(
      `[data-test="${DESKTOP_ACTIONS_BLOCK_TEST_ID}"] [data-test="${CREATE_CUSTOMER_DATA_TEST}"]`,
    ).click({ force: true })
    cy.url().should('include', '/customer/create')
    cy.get('input[name="externalId"]').type(walletCustomerExternalId)
    cy.get('input[name="name"]').type(walletCustomerName)
    cy.get(`[data-test="${SUBMIT_CUSTOMER_DATA_TEST}"]`).click({ force: true })
    cy.url().should('include', '/customer/')
    cy.contains(walletCustomerName).should('exist')

    // Navigate to wallet tab and create a wallet
    cy.get('[data-test="wallet-tab"]').click({ force: true })
    cy.get(`[data-test="${CREATE_WALLET_DATA_TEST}"]`, { timeout: 10000 })
      .should('be.visible')
      .and('not.be.disabled')
      .click({ force: true })
    cy.url().should('include', '/wallet/create')

    // Fill minimum wallet fields
    cy.get('input[name="name"]').type(`Test Wallet ${randomId}`)
    cy.get('input[name="rateAmount"]').clear().type('1')

    // Submit wallet creation
    cy.get(`[data-test="${SUBMIT_WALLET_DATA_TEST}"]`).click({ force: true })
    // After creation, navigates back to customer wallet tab
    cy.url().should('match', /\/customer\/[^/]+\/wallet$/)
  })

  beforeEach(() => {
    cy.login()
  })

  it('should be able to create a prepaid credits top-up', () => {
    // Navigate to the customer
    cy.visitApp('/customers')
    cy.contains(walletCustomerName).click({ force: true })

    // Go to wallet tab
    cy.get('[data-test="wallet-tab"]').click({ force: true })

    // Open wallet actions and click top-up
    cy.get(`[data-test="${WALLET_ACTIONS_DATA_TEST}"]`).first().click({ force: true })
    cy.get(`[data-test="${WALLET_TOPUP_BUTTON_DATA_TEST}"]`).click({ force: true })
    cy.url().should('include', '/top-up')

    // Prepaid credits is selected by default
    cy.get(`[data-test="${TOPUP_TYPE_PREPAID_CREDITS_DATA_TEST}"]`).should('exist')

    // Fill in paid credits amount
    cy.get('input[name="paidCredits"]').type('10')

    // Submit
    cy.get(`[data-test="${SUBMIT_WALLET_DATA_TEST}"]`).should('not.be.disabled')
    cy.get(`[data-test="${SUBMIT_WALLET_DATA_TEST}"]`).click({ force: true })

    // Should navigate to wallet details after success
    cy.url().should('include', '/wallet-details/')
  })

  it('should be able to create a free credits top-up', () => {
    // Navigate to the customer
    cy.visitApp('/customers')
    cy.contains(walletCustomerName).click({ force: true })

    // Go to wallet tab
    cy.get('[data-test="wallet-tab"]').click({ force: true })

    // Open wallet actions and click top-up
    cy.get(`[data-test="${WALLET_ACTIONS_DATA_TEST}"]`).first().click({ force: true })
    cy.get(`[data-test="${WALLET_TOPUP_BUTTON_DATA_TEST}"]`).click({ force: true })
    cy.url().should('include', '/top-up')

    // Switch to free credits
    cy.get(`[data-test="${TOPUP_TYPE_FREE_CREDITS_DATA_TEST}"]`).click({ force: true })

    // Fill in granted credits amount
    cy.get('input[name="grantedCredits"]').type('5')

    // Submit
    cy.get(`[data-test="${SUBMIT_WALLET_DATA_TEST}"]`).should('not.be.disabled')
    cy.get(`[data-test="${SUBMIT_WALLET_DATA_TEST}"]`).click({ force: true })

    // Should navigate to wallet details after success
    cy.url().should('include', '/wallet-details/')
  })
})
