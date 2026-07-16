import { GraphQLFormattedError } from 'graphql'

import { hasDefinedGQLError } from '~/core/apolloClient'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'

// Maps a charge create/update mutation outcome to the drawer save result, shared
// by the usage- and fixed-charge cascade hooks.
//
// `errorPolicy` is 'all', so GraphQL errors resolve in `errors` instead of
// throwing: a duplicate code becomes a field error in the drawer; any other
// error keeps the drawer open (toast handled by the error link); otherwise the
// cascade-confirmed flag decides whether to close.
export const buildChargeSaveResult = (
  errors: readonly GraphQLFormattedError[] | undefined,
  confirmed: boolean,
): boolean | FORM_ERRORS_ENUM.existingCode => {
  if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
    return FORM_ERRORS_ENUM.existingCode
  }

  if (errors?.length) {
    return false
  }

  return confirmed
}
