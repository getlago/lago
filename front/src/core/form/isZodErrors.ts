export const isZodErrors = (
  errors: unknown,
): errors is Array<{ message: string; path: unknown[] }> => {
  return (
    Array.isArray(errors) &&
    errors.every(
      (err) =>
        err &&
        typeof err === 'object' &&
        'message' in err &&
        typeof err.message === 'string' &&
        'path' in err &&
        Array.isArray(err.path),
    )
  )
}
