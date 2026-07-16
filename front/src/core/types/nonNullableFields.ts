/**
 * NonNullableFields<T> - A utility type that makes all fields of a given type non-nullable
 *
 * This mapped type iterates over all keys of type T and applies NonNullable to each property,
 * effectively removing null and undefined from all field types.
 *
 * @template T - The source type to transform
 *
 * @example
 * ```typescript
 * interface User {
 *   id: string | null
 *   name: string | undefined
 *   email?: string
 *   age: number
 * }
 *
 * type SafeUser = NonNullableFields<User>
 * // Result:
 * // {
 * //   id: string        // null removed
 * //   name: string      // undefined removed
 * //   email: string     // undefined removed (even for optional properties)
 * //   age: number       // already non-nullable, unchanged
 * // }
 * ```
 *
 * Common use cases:
 * - Data validation after ensuring required fields are present
 * - GraphQL data transformation where fields might be nullable by default
 * - Type safety guarantees after filtering or validation operations
 */
export type NonNullableFields<T> = {
  [P in keyof T]: NonNullable<T[P]>
}
