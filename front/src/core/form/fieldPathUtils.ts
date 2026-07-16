import { get } from 'lodash'

/**
 * Creates a field path by optionally prefixing it with a base path.
 * If basePath is provided, returns "{basePath}.{fieldName}", otherwise returns "{fieldName}".
 *
 * @param fieldName - The name of the field
 * @param basePath - Optional base path to prefix the field name
 * @returns The full field path
 *
 * @example
 * getFieldPath('paymentMethod') // returns 'paymentMethod'
 * getFieldPath('paymentMethod', 'recurringTransactionRules.0') // returns 'recurringTransactionRules.0.paymentMethod'
 */
export const getFieldPath = (fieldName: string, basePath?: string): string => {
  return basePath ? `${basePath}.${fieldName}` : fieldName
}

/**
 * Gets a field value from an object using the field path.
 * If basePath is provided, looks for the value at "{basePath}.{fieldName}",
 * otherwise looks for the value at "{fieldName}".
 *
 * @param fieldName - The name of the field
 * @param object - The object to get the value from
 * @param basePath - Optional base path to prefix the field name
 * @returns The field value from the object
 *
 * @example
 * // Without basePath
 * getFieldValue('paymentMethod', { paymentMethod: { id: '123' } })
 * // returns { id: '123' }
 *
 * // With basePath
 * getFieldValue('paymentMethod', { recurringTransactionRules: [{ paymentMethod: { id: '456' } }] }, 'recurringTransactionRules.0')
 * // returns { id: '456' }
 *
 * // With type parameter for type safety
 * getFieldValue<SelectedPaymentMethod>('paymentMethod', formikValues, basePath)
 * // returns SelectedPaymentMethod | undefined
 */
export const getFieldValue = <
  TReturn = unknown,
  TObject extends Record<string, unknown> = Record<string, unknown>,
>(
  fieldName: string,
  object: TObject,
  basePath?: string,
): TReturn | undefined => {
  const path = getFieldPath(fieldName, basePath)

  return get(object, path) as TReturn | undefined
}
