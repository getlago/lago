import { MultipleLineChartLine } from '~/components/designSystem/graphs/MultipleLineChart'

import { calculateYAxisDomain, checkOnlyZeroValues } from '../utils'

type TestDataType = {
  value1: string
  value2: string
  value3: string
}

describe('checkOnlyZeroValues', () => {
  const mockLines: Array<MultipleLineChartLine<TestDataType>> = [
    { dataKey: 'value1', tooltipLabel: 'Value 1', colorHex: '#000' },
    { dataKey: 'value2', tooltipLabel: 'Value 2', colorHex: '#111' },
    { dataKey: 'value3', tooltipLabel: 'Value 3', hideOnGraph: true },
  ]

  it('should return true for empty data', () => {
    expect(checkOnlyZeroValues([], mockLines)).toBe(true)
  })

  it('should return true when all visible lines have zero values', () => {
    const data: TestDataType[] = [
      { value1: '0', value2: '0', value3: '100' },
      { value1: '0', value2: '0', value3: '50' },
    ]

    expect(checkOnlyZeroValues(data, mockLines)).toBe(true)
  })

  it('should return false when any visible line has non-zero values', () => {
    const data: TestDataType[] = [
      { value1: '0', value2: '5', value3: '100' },
      { value1: '0', value2: '0', value3: '50' },
    ]

    expect(checkOnlyZeroValues(data, mockLines)).toBe(false)
  })
})

describe('calculateYAxisDomain', () => {
  const mockLines: Array<MultipleLineChartLine<TestDataType>> = [
    { dataKey: 'value1', tooltipLabel: 'Value 1', colorHex: '#000' },
    { dataKey: 'value2', tooltipLabel: 'Value 2', colorHex: '#111' },
    { dataKey: 'value3', tooltipLabel: 'Value 3', hideOnGraph: true },
  ]

  it('should return default domain for empty data', () => {
    expect(calculateYAxisDomain([], mockLines, false)).toEqual([0, 1])
  })

  it('should return default domain when hasOnlyZeroValues is true', () => {
    const data: TestDataType[] = [{ value1: '10', value2: '20', value3: '100' }]

    expect(calculateYAxisDomain(data, mockLines, true)).toEqual([0, 1])
  })

  it('should calculate domain based on visible lines', () => {
    const data: TestDataType[] = [
      { value1: '10', value2: '20', value3: '100' },
      { value1: '5', value2: '30', value3: '200' },
    ]

    expect(calculateYAxisDomain(data, mockLines, false)).toEqual([5, 30])
  })

  it('should ignore hidden lines', () => {
    const data: TestDataType[] = [
      { value1: '10', value2: '20', value3: '100' },
      { value1: '5', value2: '30', value3: '200' },
    ]

    expect(calculateYAxisDomain(data, mockLines, false)).toEqual([5, 30])
  })

  it('should handle invalid number values', () => {
    const data: TestDataType[] = [
      { value1: 'invalid', value2: '20', value3: '100' },
      { value1: '5', value2: 'NaN', value3: 'NaN' },
    ]

    expect(calculateYAxisDomain(data, mockLines, false)).toEqual([5, 20])
  })

  it('should use actual min/max values including zero', () => {
    const data: TestDataType[] = [
      { value1: '0', value2: '20', value3: '100' },
      { value1: '5', value2: '30', value3: '200' },
    ]

    expect(calculateYAxisDomain(data, mockLines, false)).toEqual([0, 30])
  })

  it('should handle negative values', () => {
    const data: TestDataType[] = [
      { value1: '-10', value2: '20', value3: '100' },
      { value1: '5', value2: '30', value3: '200' },
    ]

    expect(calculateYAxisDomain(data, mockLines, false)).toEqual([-10, 30])
  })

  it('should handle all positive values', () => {
    const data: TestDataType[] = [
      { value1: '15', value2: '20', value3: '100' },
      { value1: '25', value2: '30', value3: '200' },
    ]

    expect(calculateYAxisDomain(data, mockLines, false)).toEqual([15, 30])
  })
})
