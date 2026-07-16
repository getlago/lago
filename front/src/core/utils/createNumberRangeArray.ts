/**
 * Create an array of numbers from startAt of defined size
 * @param size number of cell in the array
 * @param startAt starting number
 * @returns array of numbers
 */
export const createNumberRangeArray = (size: number, startAt = 0): ReadonlyArray<number> => {
  if (!size || isNaN(size) || size < 1) {
    return []
  }
  return Array.from({ length: size }, (_, i) => i + startAt)
}
