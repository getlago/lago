describe('Invitations', () => {
  beforeEach(() => {
    cy.login()
  })

  const inviteEmail = `test-invite-${Date.now()}@gmail.com`

  it('should be able to create an invitation', () => {
    cy.visitApp('/settings/team-and-security/members')
    cy.get(`[role="dialog"]`).should('not.exist')
    cy.get(`[data-test="create-invite-button"]`).click()
    cy.get(`[role="dialog"]`).should('exist')
    cy.get('input[name="email"]').type(inviteEmail)
    // Select Admin role from the role picker combobox
    cy.get('input[name="role"]').click()
    cy.get('[data-option-index="0"]').click() // Select Admin (first option)
    cy.get('[data-test="submit-invite-button"]').click()
    cy.get('[data-test="centralized-confirm"]').click()
    cy.get(`[role="dialog"]`).should('not.exist')
  })

  it('invite link should have correct format', () => {
    cy.visitApp('/settings/team-and-security/members/invitations')

    cy.get('#table-members-setting-invitations-list-row-0')
      .first()
      .within(() => {
        cy.get(`button`).click()
      })

    cy.get('[data-test="copy-invite-link"]').click()

    cy.url().should('match', /\/[^/]+\/settings\/team-and-security\/members\/invitations$/)
    cy.window().then((win) => {
      new Cypress.Promise((resolve, reject) =>
        win.navigator.clipboard.readText().then(resolve).catch(reject),
      ).then((text) => {
        expect(text).to.contain('/invitation/')
      })
    })
  })
})
