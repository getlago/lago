import { isZodErrors } from '~/core/form/isZodErrors'

const chooseBetweenErrorAndErrorMap = (error: string, errorMap: unknown) => {
  if (!errorMap || Object.keys(errorMap).length === 0) {
    return error
  }

  if (!isZodErrors(errorMap)) {
    return error
  }

  return Object.values(errorMap)
    .filter(Boolean)
    .map((e) => e.message)
    .join('')
}

type GetErrorToDisplayParams = {
  error: string
  errorMap: unknown
  silentError?: boolean
  displayErrorText?: boolean
}

// Overloads meaning that if you do not pass noBoolean, the return type can be string | boolean | undefined
// More on this here https://www.typescriptlang.org/docs/handbook/2/functions.html#function-overloads
export function getErrorToDisplay(
  params: GetErrorToDisplayParams & { noBoolean: true },
): string | undefined
export function getErrorToDisplay(params: GetErrorToDisplayParams): string | boolean | undefined
export function getErrorToDisplay({
  error,
  errorMap,
  silentError = false,
  displayErrorText = true,
  noBoolean = false,
}: {
  error: string
  errorMap: unknown
  silentError?: boolean
  displayErrorText?: boolean
  noBoolean?: boolean
}) {
  if (silentError) {
    return undefined
  }

  const finalError = chooseBetweenErrorAndErrorMap(error, errorMap)

  if (noBoolean) {
    return finalError
  }

  if (!displayErrorText) {
    return !!finalError
  }

  return finalError
}
