import _get from 'lodash/get'

export const getAmountInputError = (
  silentError: boolean,
  displayErrorText: boolean,
  touched: Record<string, unknown>,
  errors: Record<string, unknown>,
  name: string,
): string | boolean | undefined => {
  if (silentError) {
    return undefined
  }

  if (displayErrorText) {
    const touchedValue = _get(touched, name)
    const errorValue = _get(errors, name) as string | undefined

    return touchedValue && errorValue ? errorValue : undefined
  }

  return !!_get(errors, name)
}
