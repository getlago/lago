import { CurrencyEnum, TimeGranularityEnum } from '~/generated/graphql'

import { formatMrrData, formatMrrDataForAreaChart } from '../utils'

jest.mock('~/components/designSystem/Filters', () => ({
  AvailableFiltersEnum: {
    currency: 'currency',
    date: 'date',
    timeGranularity: 'timeGranularity',
  },
  getFilterValue: jest.fn(),
}))

describe('formatMrrDataForAreaChart', () => {
  const mockData = [
    {
      endOfPeriodDt: '2023-01-31',
      endingMrr: '100000',
      mrrChange: '10000',
      mrrChurn: '5000',
      mrrContraction: '3000',
      mrrExpansion: '8000',
      mrrNew: '15000',
      startOfPeriodDt: '2023-01-01',
      startingMrr: '90000',
    },
    {
      endOfPeriodDt: '2023-02-28',
      endingMrr: '120000',
      mrrChange: '20000',
      mrrChurn: '6000',
      mrrContraction: '4000',
      mrrExpansion: '10000',
      mrrNew: '20000',
      startOfPeriodDt: '2023-02-01',
      startingMrr: '100000',
    },
  ]

  it('should format MRR data for monthly area chart display', () => {
    const result = formatMrrDataForAreaChart({
      data: mockData,
      timeGranularity: TimeGranularityEnum.Monthly,
      selectedCurrency: CurrencyEnum.Eur,
    })

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      tooltipLabel: 'Jan 2023: €1,000.00',
      value: 100000,
      axisName: 'Jan 1, 2023',
    })
    expect(result[1]).toEqual({
      tooltipLabel: 'Feb 2023: €1,200.00',
      value: 120000,
      axisName: 'Feb 28, 2023',
    })
  })

  it('should format MRR data for daily area chart display', () => {
    const result = formatMrrDataForAreaChart({
      data: mockData,
      timeGranularity: TimeGranularityEnum.Daily,
      selectedCurrency: CurrencyEnum.Eur,
    })

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      tooltipLabel: 'Jan 1, 23: €1,000.00',
      value: 100000,
      axisName: 'Jan 1, 2023',
    })
    expect(result[1]).toEqual({
      tooltipLabel: 'Feb 1, 23: €1,200.00',
      value: 120000,
      axisName: 'Feb 28, 2023',
    })
  })

  it('should format MRR data for weekly area chart display', () => {
    const result = formatMrrDataForAreaChart({
      data: mockData,
      timeGranularity: TimeGranularityEnum.Weekly,
      selectedCurrency: CurrencyEnum.Eur,
    })

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      tooltipLabel: 'Jan 1, 23 - Jan 31, 23: €1,000.00',
      value: 100000,
      axisName: 'Jan 1, 2023',
    })
    expect(result[1]).toEqual({
      tooltipLabel: 'Feb 1, 23 - Feb 28, 23: €1,200.00',
      value: 120000,
      axisName: 'Feb 28, 2023',
    })
  })

  it('should handle different currencies', () => {
    const result = formatMrrDataForAreaChart({
      data: mockData,
      timeGranularity: TimeGranularityEnum.Monthly,
      selectedCurrency: CurrencyEnum.Usd,
    })

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      tooltipLabel: 'Jan 2023: $1,000.00',
      value: 100000,
      axisName: 'Jan 1, 2023',
    })
    expect(result[1]).toEqual({
      tooltipLabel: 'Feb 2023: $1,200.00',
      value: 120000,
      axisName: 'Feb 28, 2023',
    })
  })

  it('should handle empty data array', () => {
    const result = formatMrrDataForAreaChart({
      data: [],
      timeGranularity: TimeGranularityEnum.Monthly,
      selectedCurrency: CurrencyEnum.Eur,
    })

    expect(result).toHaveLength(0)
  })
})

describe('formatMrrData', () => {
  const mockData = [
    {
      endOfPeriodDt: '2023-01-31',
      endingMrr: '100000',
      mrrChange: '10000',
      mrrChurn: '5000',
      mrrContraction: '3000',
      mrrExpansion: '8000',
      mrrNew: '15000',
      startOfPeriodDt: '2023-01-01',
      startingMrr: '90000',
    },
    {
      endOfPeriodDt: '2023-02-28',
      endingMrr: '120000',
      mrrChange: '20000',
      mrrChurn: '6000',
      mrrContraction: '4000',
      mrrExpansion: '10000',
      mrrNew: '20000',
      startOfPeriodDt: '2023-02-01',
      startingMrr: '100000',
    },
    {
      endOfPeriodDt: '2023-03-31',
      endingMrr: '140000',
      mrrChange: '20000',
      mrrChurn: '7000',
      mrrContraction: '5000',
      mrrExpansion: '12000',
      mrrNew: '20000',
      startOfPeriodDt: '2023-03-01',
      startingMrr: '120000',
    },
    {
      endOfPeriodDt: '2023-04-30',
      endingMrr: '160000',
      mrrChange: '20000',
      mrrChurn: '8000',
      mrrContraction: '4000',
      mrrExpansion: '14000',
      mrrNew: '18000',
      startOfPeriodDt: '2023-04-01',
      startingMrr: '140000',
    },
    {
      endOfPeriodDt: '2023-05-31',
      endingMrr: '180000',
      mrrChange: '20000',
      mrrChurn: '6000',
      mrrContraction: '6000',
      mrrExpansion: '12000',
      mrrNew: '20000',
      startOfPeriodDt: '2023-05-01',
      startingMrr: '160000',
    },
    {
      endOfPeriodDt: '2023-06-30',
      endingMrr: '200000',
      mrrChange: '20000',
      mrrChurn: '5000',
      mrrContraction: '5000',
      mrrExpansion: '15000',
      mrrNew: '15000',
      startOfPeriodDt: '2023-06-01',
      startingMrr: '180000',
    },
  ]

  const getFilterValueMock = jest.requireMock('~/components/designSystem/Filters').getFilterValue

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('should format MRR data with provided search params', () => {
    getFilterValueMock.mockImplementation(({ key, prefix }: { key: string; prefix: string }) => {
      if (key === 'date' && prefix === 'mbo') return '2023-01-01,2023-06-30'
      if (key === 'timeGranularity' && prefix === 'mbo') return TimeGranularityEnum.Monthly
      return null
    })

    const searchParams = new URLSearchParams()
    const result = formatMrrData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod: '2023-01-01,2023-01-31',
      defaultStaticTimeGranularity: TimeGranularityEnum.Monthly,
    })

    expect(result).toHaveLength(6)
    expect(result[0]).toEqual(mockData[0])
    expect(result[1]).toEqual(mockData[1])
    expect(result[2]).toEqual(mockData[2])
    expect(result[3]).toEqual(mockData[3])
    expect(result[4]).toEqual(mockData[4])
    expect(result[5]).toEqual(mockData[5])
    expect(getFilterValueMock).toHaveBeenCalledTimes(2)
  })

  it('should use default values when search params are not provided', () => {
    getFilterValueMock.mockReturnValue(null)

    const searchParams = new URLSearchParams()
    const result = formatMrrData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod: '2023-01-01,2023-01-31',
      defaultStaticTimeGranularity: TimeGranularityEnum.Monthly,
    })

    expect(getFilterValueMock).toHaveBeenCalledTimes(2)
    expect(result).toHaveLength(1)
    expect(result[0]).toEqual(mockData[0])
  })

  it('should pad data with empty values for missing periods', () => {
    getFilterValueMock.mockImplementation(({ key, prefix }: { key: string; prefix: string }) => {
      if (key === 'date' && prefix === 'mbo') return '2023-01-01,2023-07-31'
      if (key === 'timeGranularity' && prefix === 'mbo') return TimeGranularityEnum.Monthly
      return null
    })

    const searchParams = new URLSearchParams()
    const result = formatMrrData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod: '2023-01-01,2023-01-31',
      defaultStaticTimeGranularity: TimeGranularityEnum.Monthly,
    })

    expect(result).toHaveLength(7)
    expect(result[0]).toEqual(mockData[0])
    expect(result[1]).toEqual(mockData[1])
    expect(result[2]).toEqual(mockData[2])
    expect(result[3]).toEqual(mockData[3])
    expect(result[4]).toEqual(mockData[4])
    expect(result[5]).toEqual(mockData[5])
    expect(result[6]).toEqual({
      endOfPeriodDt: '2023-07-31',
      endingMrr: 0,
      mrrChange: 0,
      mrrChurn: 0,
      mrrContraction: 0,
      mrrExpansion: 0,
      mrrNew: 0,
      startOfPeriodDt: '2023-07-01',
      startingMrr: 0,
    })
  })

  it('should handle weekly time granularity correctly', () => {
    getFilterValueMock.mockImplementation(({ key, prefix }: { key: string; prefix: string }) => {
      if (key === 'date' && prefix === 'mbo') return '2023-06-04,2023-06-17'
      if (key === 'timeGranularity' && prefix === 'mbo') return TimeGranularityEnum.Weekly
      return null
    })

    const weeklyData = [
      {
        endOfPeriodDt: '2023-06-04',
        endingMrr: '190000',
        mrrChange: '10000',
        mrrChurn: '3000',
        mrrContraction: '2000',
        mrrExpansion: '8000',
        mrrNew: '7000',
        startOfPeriodDt: '2023-05-29',
        startingMrr: '180000',
      },
      {
        endOfPeriodDt: '2023-06-11',
        endingMrr: '200000',
        mrrChange: '10000',
        mrrChurn: '2000',
        mrrContraction: '1000',
        mrrExpansion: '7000',
        mrrNew: '6000',
        startOfPeriodDt: '2023-06-05',
        startingMrr: '190000',
      },
      {
        endOfPeriodDt: '2023-06-18',
        endingMrr: '205000',
        mrrChange: '5000',
        mrrChurn: '1000',
        mrrContraction: '1000',
        mrrExpansion: '4000',
        mrrNew: '3000',
        startOfPeriodDt: '2023-06-12',
        startingMrr: '200000',
      },
    ]

    const searchParams = new URLSearchParams()
    const result = formatMrrData({
      data: weeklyData,
      searchParams,
      defaultStaticDatePeriod: '2023-01-01,2023-01-31',
      defaultStaticTimeGranularity: TimeGranularityEnum.Monthly,
    })

    expect(result).toHaveLength(3)
    expect(result[0]).toEqual(weeklyData[0])
    expect(result[1]).toEqual(weeklyData[1])
    expect(result[2]).toEqual(weeklyData[2])
  })

  it('should handle daily time granularity correctly', () => {
    getFilterValueMock.mockImplementation(({ key, prefix }: { key: string; prefix: string }) => {
      if (key === 'date' && prefix === 'mbo') return '2023-06-01,2023-06-03'
      if (key === 'timeGranularity' && prefix === 'mbo') return TimeGranularityEnum.Daily
      return null
    })

    const dailyData = [
      {
        endOfPeriodDt: '2023-06-01',
        endingMrr: '180500',
        mrrChange: '500',
        mrrChurn: '100',
        mrrContraction: '100',
        mrrExpansion: '400',
        mrrNew: '300',
        startOfPeriodDt: '2023-06-01',
        startingMrr: '180000',
      },
      {
        endOfPeriodDt: '2023-06-02',
        endingMrr: '181000',
        mrrChange: '500',
        mrrChurn: '100',
        mrrContraction: '100',
        mrrExpansion: '400',
        mrrNew: '300',
        startOfPeriodDt: '2023-06-02',
        startingMrr: '180500',
      },
      {
        endOfPeriodDt: '2023-06-03',
        endingMrr: '181500',
        mrrChange: '500',
        mrrChurn: '100',
        mrrContraction: '100',
        mrrExpansion: '400',
        mrrNew: '300',
        startOfPeriodDt: '2023-06-03',
        startingMrr: '181000',
      },
    ]

    const searchParams = new URLSearchParams()
    const result = formatMrrData({
      data: dailyData,
      searchParams,
      defaultStaticDatePeriod: '2023-01-01,2023-01-31',
      defaultStaticTimeGranularity: TimeGranularityEnum.Monthly,
    })

    expect(result).toHaveLength(3)
    expect(result[0]).toEqual(dailyData[0])
    expect(result[1]).toEqual(dailyData[1])
    expect(result[2]).toEqual(dailyData[2])
  })

  it('should handle empty data array', () => {
    getFilterValueMock.mockImplementation(({ key, prefix }: { key: string; prefix: string }) => {
      if (key === 'date' && prefix === 'mbo') return '2023-06-01,2023-06-30'
      if (key === 'timeGranularity' && prefix === 'mbo') return TimeGranularityEnum.Monthly
      return null
    })

    const searchParams = new URLSearchParams()
    const result = formatMrrData({
      data: [],
      searchParams,
      defaultStaticDatePeriod: '2023-01-01,2023-01-31',
      defaultStaticTimeGranularity: TimeGranularityEnum.Monthly,
    })

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      endOfPeriodDt: '2023-06-30',
      endingMrr: 0,
      mrrChange: 0,
      mrrChurn: 0,
      mrrContraction: 0,
      mrrExpansion: 0,
      mrrNew: 0,
      startOfPeriodDt: '2023-06-01',
      startingMrr: 0,
    })
  })
})
