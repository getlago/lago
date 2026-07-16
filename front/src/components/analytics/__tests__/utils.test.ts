import { AvailableFiltersEnum } from '~/components/designSystem/Filters'
import { REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import {
  RevenueStreamDataForOverviewSectionFragment,
  TimeGranularityEnum,
} from '~/generated/graphql'

import { formatRevenueStreamsData } from '../revenueStreams/utils'

jest.mock('~/components/designSystem/Filters', () => ({
  AvailableFiltersEnum: {
    date: 'date',
    timeGranularity: 'timeGranularity',
  },
  getFilterValue: jest.fn().mockImplementation(({ key, searchParams, prefix }) => {
    const paramKey = `${prefix}${key}`

    return searchParams.get(paramKey)
  }),
}))

describe('formatRevenueStreamsData', () => {
  const defaultStaticDatePeriod = '2023-01-01,2023-12-31'
  const defaultStaticTimeGranularity = TimeGranularityEnum.Daily
  const mockData: RevenueStreamDataForOverviewSectionFragment[] = [
    {
      startOfPeriodDt: '2023-01-01',
      endOfPeriodDt: '2023-01-01',
      commitmentFeeAmountCents: 100,
      couponsAmountCents: 50,
      grossRevenueAmountCents: 1000,
      netRevenueAmountCents: 950,
      oneOffFeeAmountCents: 200,
      subscriptionFeeAmountCents: 300,
      usageBasedFeeAmountCents: 400,
    },
    {
      startOfPeriodDt: '2023-01-15',
      endOfPeriodDt: '2023-01-15',
      commitmentFeeAmountCents: 150,
      couponsAmountCents: 75,
      grossRevenueAmountCents: 1500,
      netRevenueAmountCents: 1425,
      oneOffFeeAmountCents: 300,
      subscriptionFeeAmountCents: 450,
      usageBasedFeeAmountCents: 600,
    },
    {
      startOfPeriodDt: '2023-12-31',
      endOfPeriodDt: '2023-12-31',
      commitmentFeeAmountCents: 500,
      couponsAmountCents: 100,
      grossRevenueAmountCents: 5000,
      netRevenueAmountCents: 4900,
      oneOffFeeAmountCents: 1000,
      subscriptionFeeAmountCents: 2000,
      usageBasedFeeAmountCents: 2000,
    },
  ]

  it('should use values from search params when available', () => {
    const searchParams = new URLSearchParams()

    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.date}`,
      '2023-02-01,2023-02-28',
    )
    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.timeGranularity}`,
      TimeGranularityEnum.Weekly,
    )

    const result = formatRevenueStreamsData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod,
      defaultStaticTimeGranularity,
    })

    // Should generate 5 weeks for February (including partial weeks at month boundaries)
    expect(result.length).toBe(5)
    expect(result[0].startOfPeriodDt).toBe('2023-01-30')
    expect(result[3].startOfPeriodDt).toBe('2023-02-20')
  })

  it('should use default values when search params are not available', () => {
    const searchParams = new URLSearchParams()

    const result = formatRevenueStreamsData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod,
      defaultStaticTimeGranularity,
    })

    // Should generate 365 days for the full year
    expect(result.length).toBe(365)
    expect(result[0].startOfPeriodDt).toBe('2023-01-01')
    expect(result[364].startOfPeriodDt).toBe('2023-12-31')

    // Check that the January 1st data matches the mock
    expect(result[0].grossRevenueAmountCents).toBe(1000)
    expect(result[0].netRevenueAmountCents).toBe(950)

    // Check that January 15th data matches the mock
    expect(result[14].grossRevenueAmountCents).toBe(1500)
    expect(result[14].netRevenueAmountCents).toBe(1425)

    // Check that some random days in the middle have zero values
    expect(result[100].grossRevenueAmountCents).toBe(0)
    expect(result[200].grossRevenueAmountCents).toBe(0)
    expect(result[300].grossRevenueAmountCents).toBe(0)

    // Check that December 31st data matches the mock
    expect(result[364].grossRevenueAmountCents).toBe(5000)
    expect(result[364].netRevenueAmountCents).toBe(4900)
    expect(result[364].subscriptionFeeAmountCents).toBe(2000)
    expect(result[364].usageBasedFeeAmountCents).toBe(2000)
  })

  it('should pad missing data points with zero values', () => {
    const searchParams = new URLSearchParams()

    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.date}`,
      '2023-01-01,2023-01-05',
    )

    const result = formatRevenueStreamsData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod,
      defaultStaticTimeGranularity,
    })

    // Should generate 5 days
    expect(result.length).toBe(5)

    // Day that has data should keep original values
    expect(result[0].startOfPeriodDt).toBe('2023-01-01')
    expect(result[0].grossRevenueAmountCents).toBe(1000)

    // Day that has no data should have zero values
    expect(result[1].startOfPeriodDt).toBe('2023-01-02')
    expect(result[1].grossRevenueAmountCents).toBe(0)
    expect(result[1].netRevenueAmountCents).toBe(0)
    expect(result[1].subscriptionFeeAmountCents).toBe(0)
  })

  it('should correctly handle daily granularity', () => {
    const searchParams = new URLSearchParams()

    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.date}`,
      '2023-01-01,2023-01-03',
    )
    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.timeGranularity}`,
      TimeGranularityEnum.Daily,
    )

    const result = formatRevenueStreamsData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod,
      defaultStaticTimeGranularity,
    })

    expect(result.length).toBe(3)
    expect(result[0].startOfPeriodDt).toBe('2023-01-01')
    expect(result[1].startOfPeriodDt).toBe('2023-01-02')
    expect(result[2].startOfPeriodDt).toBe('2023-01-03')
  })

  it('should correctly handle weekly granularity', () => {
    const searchParams = new URLSearchParams()

    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.date}`,
      '2023-01-01,2023-01-21',
    )
    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.timeGranularity}`,
      TimeGranularityEnum.Weekly,
    )

    const result = formatRevenueStreamsData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod,
      defaultStaticTimeGranularity,
    })

    // Should create 4 weeks (including partial week at end)
    expect(result.length).toBe(4)
    expect(result[0].startOfPeriodDt).toBe('2022-12-26')
    expect(result[1].startOfPeriodDt).toBe('2023-01-02')
    expect(result[2].startOfPeriodDt).toBe('2023-01-09')
    expect(result[3].startOfPeriodDt).toBe('2023-01-16')

    // Check end dates (note: exact end dates depend on implementation details of the utility)
    expect(result[0].endOfPeriodDt).toBe('2023-01-01')
    expect(result[1].endOfPeriodDt).toBe('2023-01-08')
  })

  it('should correctly handle monthly granularity', () => {
    const searchParams = new URLSearchParams()

    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.date}`,
      '2023-01-01,2023-03-31',
    )
    searchParams.set(
      `${REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX}${AvailableFiltersEnum.timeGranularity}`,
      TimeGranularityEnum.Monthly,
    )

    const result = formatRevenueStreamsData({
      data: mockData,
      searchParams,
      defaultStaticDatePeriod,
      defaultStaticTimeGranularity,
    })

    // Should create 3 months
    expect(result.length).toBe(3)
    expect(result[0].startOfPeriodDt).toBe('2023-01-01')
    expect(result[1].startOfPeriodDt).toBe('2023-02-01')
    expect(result[2].startOfPeriodDt).toBe('2023-03-01')
  })
})
