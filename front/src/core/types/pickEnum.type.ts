/**
 * Allow to pick enum values from a given enum type
 *
 * @example
 * ```ts
 * enum Colors {
 *   Red = 'red',
 *   Green = 'green',
 *   Blue = 'blue',
 * }
 *
 * type PrimaryColors = PickEnum<Colors, Colors.Red | Colors.Blue>
 *
 * const color1: PrimaryColors = Colors.Red // Valid
 * const color2: PrimaryColors = Colors.Green // Error: Type 'Colors.Green' is not assignable to type 'PrimaryColors'
 * ```
 */
export type PickEnum<T, K extends T> = K
