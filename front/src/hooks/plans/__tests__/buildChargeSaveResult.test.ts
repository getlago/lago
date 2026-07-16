import { GraphQLError } from 'graphql'

import { FORM_ERRORS_ENUM } from '~/core/constants/form'

import { buildChargeSaveResult } from '../buildChargeSaveResult'

const valueAlreadyExistError = new GraphQLError('Value already exists', {
  extensions: { code: 'value_already_exist', details: { code: ['value_already_exist'] } },
})

const otherError = new GraphQLError('Something went wrong', {
  extensions: { code: 'internal_error' },
})

describe('buildChargeSaveResult', () => {
  it('returns the existing-code error when the backend reports a duplicate code', () => {
    expect(buildChargeSaveResult([valueAlreadyExistError], true)).toBe(
      FORM_ERRORS_ENUM.existingCode,
    )
    // A duplicate code wins even when the cascade was not confirmed.
    expect(buildChargeSaveResult([valueAlreadyExistError], false)).toBe(
      FORM_ERRORS_ENUM.existingCode,
    )
  })

  it('returns false for any other GraphQL error (drawer stays open)', () => {
    expect(buildChargeSaveResult([otherError], true)).toBe(false)
  })

  it('returns the confirmed flag when there are no errors', () => {
    expect(buildChargeSaveResult(undefined, true)).toBe(true)
    expect(buildChargeSaveResult(undefined, false)).toBe(false)
    expect(buildChargeSaveResult([], true)).toBe(true)
  })
})
