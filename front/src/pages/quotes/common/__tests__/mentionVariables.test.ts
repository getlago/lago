import { QUOTE_MENTION_VARIABLES } from '../mentionVariables'

const EXPECTED_BACKEND_KEYS = [
  'customer_name',
  'customer_email',
  'organization_name',
  'organization_logo',
  'billing_entity_name',
  'billing_entity_legal_name',
  'billing_entity_address',
  'billing_entity_tax_id',
  'billing_entity_email',
  'quote_number',
  'quote_date',
  'quote_version',
  'quote_currency',
  'commercial_terms_term_duration',
  'commercial_terms_start_date',
  'commercial_terms_payment_terms',
]

describe('QUOTE_MENTION_VARIABLES', () => {
  it('matches the backend mentionVariables key set exactly', () => {
    expect(QUOTE_MENTION_VARIABLES.map((v) => v.id)).toEqual(EXPECTED_BACKEND_KEYS)
  })

  it('has unique snake_case ids', () => {
    const ids = QUOTE_MENTION_VARIABLES.map((v) => v.id)

    expect(new Set(ids).size).toBe(ids.length)
    ids.forEach((id) => expect(id).toMatch(/^[a-z]+(_[a-z]+)*$/))
  })

  it('has a non-empty labelKey for every entry', () => {
    QUOTE_MENTION_VARIABLES.forEach((v) => expect(v.labelKey).toMatch(/^text_/))
  })
})
