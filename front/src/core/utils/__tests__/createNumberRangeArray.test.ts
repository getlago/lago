import { createNumberRangeArray } from '../createNumberRangeArray'

describe('createNumberRangeArray', () => {
  it('should create an array of defined size starting from 0', () => {
    const result = createNumberRangeArray(3)

    expect(result).toEqual([0, 1, 2])
  })
  it('should create an array of defined size starting from a given number', () => {
    const result = createNumberRangeArray(3, 5)

    expect(result).toEqual([5, 6, 7])
  })
  it('should return an empty array if size is less than 1', () => {
    const result = createNumberRangeArray(0)

    expect(result).toEqual([])
  })
  it('should return an empty array if size is NaN', () => {
    const result = createNumberRangeArray(NaN)

    expect(result).toEqual([])
  })
  it('should return an empty array if size is negative', () => {
    const result = createNumberRangeArray(-5)

    expect(result).toEqual([])
  })
  it('should return an empty array if size is not provided', () => {
    // @ts-expect-error Testing invalid input
    const result = createNumberRangeArray()

    expect(result).toEqual([])
  })
  it('should return an empty array if size is a string', () => {
    // @ts-expect-error Testing invalid input
    const result = createNumberRangeArray('a')

    expect(result).toEqual([])
  })
})
