import { ACTIONS_BLOCK_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'

describe('Create billable metrics', () => {
  beforeEach(() => {
    cy.login().visitApp('/billable-metrics')
  })

  it('should create count billable metric', () => {
    const randomId = Math.round(Math.random() * 1000)
    const bmName = `bm count ${randomId}`
    const bmCode = `bm_count_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-bm"]`).click()
    cy.url().should('match', /\/[^/]+\/create\/billable-metrics$/)
    cy.get('input[name="name"]').type(bmName)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="code"]').should('have.value', bmCode)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('[data-test="show-description"]').click()
    cy.get('textarea[name="description"]').type('I am a description')
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="aggregationType"]').click()
    cy.get('[data-test="count_agg"]').click()
    cy.get('input[name="fieldName"]').should('not.exist')
    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()
    cy.url().should('include', '/billable-metric/')
    cy.contains(bmName).should('exist')
  })

  it('should create uniq count billable metric', () => {
    const randomId = Math.round(Math.random() * 1000)
    const bmName = `bm uniq count ${randomId}`
    const bmCode = `bm_uniq_count_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-bm"]`).click()
    cy.url().should('match', /\/[^/]+\/create\/billable-metrics$/)
    cy.get('input[name="name"]').type(bmName)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="code"]').should('have.value', bmCode)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('[data-test="show-description"]').click()
    cy.get('textarea[name="description"]').type('I am a description')
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="aggregationType"]').click()
    cy.get('[data-test="unique_count_agg"]').click()
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="fieldName"]').type('whatever')
    cy.get('[data-test="button-selector-true"]').click()
    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()
    cy.url().should('include', '/billable-metric/')
    cy.contains(bmName).should('exist')
  })

  it('should create max billable metric', () => {
    const randomId = Math.round(Math.random() * 1000)
    const bmName = `bm max ${randomId}`
    const bmCode = `bm_max_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-bm"]`).click()
    cy.url().should('match', /\/[^/]+\/create\/billable-metrics$/)
    cy.get('input[name="name"]').type(bmName)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="code"]').should('have.value', bmCode)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('[data-test="show-description"]').click()
    cy.get('textarea[name="description"]').type('I am a description')
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="aggregationType"]').click()
    cy.get('[data-test="max_agg"]').click()
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="fieldName"]').type('whatever')
    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()
    cy.url().should('include', '/billable-metric/')
    cy.contains(bmName).should('exist')
  })

  it('should create sum billable metric', () => {
    const randomId = Math.round(Math.random() * 1000)
    const bmName = `bm sum ${randomId}`
    const bmCode = `bm_sum_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-bm"]`).click()
    cy.url().should('match', /\/[^/]+\/create\/billable-metrics$/)
    cy.get('input[name="name"]').type(bmName)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="code"]').should('have.value', bmCode)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('[data-test="show-description"]').click()
    cy.get('textarea[name="description"]').type('I am a description')
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="aggregationType"]').click()
    cy.get('[data-test="sum_agg"]').click()
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="fieldName"]').type('whatever')
    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()
    cy.url().should('include', '/billable-metric/')
    cy.contains(bmName).should('exist')
  })

  it('should create recurring count billable metric', () => {
    const randomId = Math.round(Math.random() * 1000)
    const bmName = `bm recurring count ${randomId}`
    const bmCode = `bm_recurring_count_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-bm"]`).click()
    cy.url().should('match', /\/[^/]+\/create\/billable-metrics$/)
    cy.get('input[name="name"]').type(bmName)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="code"]').should('have.value', bmCode)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('[data-test="show-description"]').click()
    cy.get('textarea[name="description"]').type('I am a description')
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="aggregationType"]').click()
    cy.get('[data-test="count_agg"]').click()
    cy.get('input[name="fieldName"]').should('not.exist')
    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()
    cy.url().should('include', '/billable-metric/')
    cy.contains(bmName).should('exist')
  })

  it('should create recurring count billable metric', () => {
    const randomId = Math.round(Math.random() * 1000)
    const bmName = `bm weighted sum ${randomId}`
    const bmCode = `bm_weighted_sum_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-bm"]`).click()
    cy.url().should('match', /\/[^/]+\/create\/billable-metrics$/)
    cy.get('input[name="name"]').type(bmName)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('[data-test="recurring-switch"] [data-test="button-selector-true"]').click()
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="code"]').should('have.value', bmCode)
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('[data-test="show-description"]').click()
    cy.get('textarea[name="description"]').type('I am a description')
    cy.get('[data-test="submit"]').should('be.disabled')
    cy.get('input[name="aggregationType"]').click()
    cy.get('[data-test="weighted_sum_agg"]').click()
    cy.get('input[name="fieldName"]').type('whatever')
    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()
    cy.url().should('include', '/billable-metric/')
    cy.contains(bmName).should('exist')
  })

  it('should create count billable metric with filters', () => {
    const randomId = Math.round(Math.random() * 1000)
    const bmName = `bm filtered ${randomId}`
    const bmCode = `bm_filtered_${randomId}`

    cy.get(`[data-test="${ACTIONS_BLOCK_TEST_ID}"] [data-test="create-bm"]`).click()
    cy.url().should('match', /\/[^/]+\/create\/billable-metrics$/)
    cy.get('input[name="name"]').type(bmName)
    cy.get('input[name="code"]').should('have.value', bmCode)
    cy.get('input[name="aggregationType"]').click()
    cy.get('[data-test="count_agg"]').click()

    // Add a filter with key "region" and values "us", "eu"
    cy.get('[data-test="add-filter"]').click()
    cy.get('input[name="filters[0].key"]').type('region')
    cy.get('.MuiAutocomplete-root').last().find('input').type('us{enter}')
    cy.get('.MuiAutocomplete-root').last().find('input').type('eu{enter}')

    cy.get('[data-test="submit"]').should('not.be.disabled')
    cy.get('[data-test="submit"]').click()
    cy.url().should('include', '/billable-metric/')
    cy.contains(bmName).should('exist')
  })
})
