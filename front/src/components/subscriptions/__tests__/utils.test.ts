import {
  findChargeUsageByBillableMetricId,
  getLifetimeGraphPercentages,
} from '~/components/subscriptions/utils'
import {
  ChargeUsage,
  CurrencyEnum,
  GetCustomerProjectedUsageForPortalQuery,
  GetCustomerUsageForPortalQuery,
  ProjectedChargeUsage,
  ProjectedUsageForSubscriptionUsageQuery,
  SubscriptionLifetimeUsage,
  UsageForSubscriptionUsageQuery,
} from '~/generated/graphql'

describe('subscriptions utils tests', () => {
  it('should return the appropriate calculated percentages', () => {
    expect(
      getLifetimeGraphPercentages({
        totalUsageAmountCents: '100',
        lastThresholdAmountCents: '100',
        nextThresholdAmountCents: '200',
      } as SubscriptionLifetimeUsage),
    ).toEqual({
      nextThresholdPercentage: 100,
      lastThresholdPercentage: 0,
    })

    expect(
      getLifetimeGraphPercentages({
        totalUsageAmountCents: '200',
        lastThresholdAmountCents: '100',
        nextThresholdAmountCents: '200',
      } as SubscriptionLifetimeUsage),
    ).toEqual({
      nextThresholdPercentage: 0,
      lastThresholdPercentage: 100,
    })

    expect(
      getLifetimeGraphPercentages({
        totalUsageAmountCents: '150000',
        lastThresholdAmountCents: '100000',
        nextThresholdAmountCents: '300000',
      } as SubscriptionLifetimeUsage),
    ).toEqual({
      lastThresholdPercentage: 25,
      nextThresholdPercentage: 75,
    })

    expect(
      getLifetimeGraphPercentages({
        totalUsageAmountCents: '150000',
        lastThresholdAmountCents: '100000',
        nextThresholdAmountCents: '450000',
      } as SubscriptionLifetimeUsage),
    ).toEqual({
      lastThresholdPercentage: 14.285714285714286,
      nextThresholdPercentage: 85.71428571428571,
    })

    expect(
      getLifetimeGraphPercentages({
        totalUsageAmountCents: '150000',
        lastThresholdAmountCents: '100000',
        nextThresholdAmountCents: null,
      } as SubscriptionLifetimeUsage),
    ).toEqual({
      lastThresholdPercentage: 100,
      nextThresholdPercentage: 0,
    })

    expect(
      getLifetimeGraphPercentages({
        totalUsageAmountCents: '150000',
        lastThresholdAmountCents: '100000',
        nextThresholdAmountCents: '0',
      } as SubscriptionLifetimeUsage),
    ).toEqual({
      lastThresholdPercentage: 100,
      nextThresholdPercentage: 0,
    })
  })

  describe('findChargeUsageByBillableMetricId', () => {
    const mockBillableMetricId = 'bm-123'
    const mockChargeUsage: ChargeUsage = {
      id: 'charge-usage-1',
      billableMetric: {
        id: mockBillableMetricId,
        code: 'test-metric',
        name: 'Test Metric',
      },
      units: 10,
      amountCents: '1000',
    } as ChargeUsage

    const mockOtherChargeUsage: ChargeUsage = {
      id: 'charge-usage-2',
      billableMetric: {
        id: 'bm-456',
        code: 'other-metric',
        name: 'Other Metric',
      },
      units: 5,
      amountCents: '500',
    } as ChargeUsage

    it('should return undefined when data is null', () => {
      expect(findChargeUsageByBillableMetricId(null, mockBillableMetricId)).toBeUndefined()
    })

    it('should return undefined when data is undefined', () => {
      expect(findChargeUsageByBillableMetricId(undefined, mockBillableMetricId)).toBeUndefined()
    })

    it('should find charge usage in customerUsage data', () => {
      const mockData: UsageForSubscriptionUsageQuery = {
        customerUsage: {
          amountCents: '1500',
          currency: CurrencyEnum.Usd,
          fromDatetime: '2024-01-01T00:00:00Z',
          toDatetime: '2024-01-31T23:59:59Z',
          chargesUsage: [mockChargeUsage, mockOtherChargeUsage],
        },
      } as UsageForSubscriptionUsageQuery

      const result = findChargeUsageByBillableMetricId(mockData, mockBillableMetricId)

      expect(result).toEqual(mockChargeUsage)
    })

    it('should find charge usage in customerProjectedUsage data', () => {
      const mockProjectedChargeUsage: ProjectedChargeUsage = {
        ...mockChargeUsage,
        projectedUnits: 15,
        projectedAmountCents: '1500',
      } as ProjectedChargeUsage

      const mockProjectedOtherChargeUsage: ProjectedChargeUsage = {
        ...mockOtherChargeUsage,
        projectedUnits: 8,
        projectedAmountCents: '800',
      } as ProjectedChargeUsage

      const mockData: ProjectedUsageForSubscriptionUsageQuery = {
        customerProjectedUsage: {
          amountCents: '1500000',
          projectedAmountCents: '2000000',
          currency: CurrencyEnum.Usd,
          fromDatetime: '2024-01-01T00:00:00Z',
          toDatetime: '2024-01-31T23:59:59Z',
          chargesUsage: [mockProjectedChargeUsage, mockProjectedOtherChargeUsage],
        },
      } as ProjectedUsageForSubscriptionUsageQuery

      const result = findChargeUsageByBillableMetricId(mockData, mockBillableMetricId)

      expect(result).toEqual(mockProjectedChargeUsage)
    })

    it('should find charge usage in customerPortalCustomerUsage data', () => {
      const mockData: GetCustomerUsageForPortalQuery = {
        customerPortalCustomerUsage: {
          amountCents: '1500000',
          currency: CurrencyEnum.Usd,
          fromDatetime: '2024-01-01T00:00:00Z',
          toDatetime: '2024-01-31T23:59:59Z',
          chargesUsage: [mockChargeUsage, mockOtherChargeUsage],
        },
      } as GetCustomerUsageForPortalQuery

      const result = findChargeUsageByBillableMetricId(mockData, mockBillableMetricId)

      expect(result).toEqual(mockChargeUsage)
    })

    it('should find charge usage in customerPortalCustomerProjectedUsage data', () => {
      const mockProjectedChargeUsage: ProjectedChargeUsage = {
        ...mockChargeUsage,
        projectedUnits: 15,
        projectedAmountCents: '1500',
      } as ProjectedChargeUsage

      const mockProjectedOtherChargeUsage: ProjectedChargeUsage = {
        ...mockOtherChargeUsage,
        projectedUnits: 8,
        projectedAmountCents: '800',
      } as ProjectedChargeUsage

      const mockData: GetCustomerProjectedUsageForPortalQuery = {
        customerPortalCustomerProjectedUsage: {
          amountCents: '1500000',
          projectedAmountCents: '2000000',
          currency: CurrencyEnum.Usd,
          fromDatetime: '2024-01-01T00:00:00Z',
          toDatetime: '2024-01-31T23:59:59Z',
          chargesUsage: [mockProjectedChargeUsage, mockProjectedOtherChargeUsage],
        },
      } as GetCustomerProjectedUsageForPortalQuery

      const result = findChargeUsageByBillableMetricId(mockData, mockBillableMetricId)

      expect(result).toEqual(mockProjectedChargeUsage)
    })

    it('should return undefined when charge usage is not found', () => {
      const mockData: UsageForSubscriptionUsageQuery = {
        customerUsage: {
          amountCents: '1500000',
          currency: CurrencyEnum.Usd,
          fromDatetime: '2024-01-01T00:00:00Z',
          toDatetime: '2024-01-31T23:59:59Z',
          chargesUsage: [mockOtherChargeUsage],
        },
      } as UsageForSubscriptionUsageQuery

      const result = findChargeUsageByBillableMetricId(mockData, mockBillableMetricId)

      expect(result).toBeUndefined()
    })

    it('should return undefined when chargesUsage array is empty', () => {
      const mockData: UsageForSubscriptionUsageQuery = {
        customerUsage: {
          amountCents: '1500000',
          currency: CurrencyEnum.Usd,
          fromDatetime: '2024-01-01T00:00:00Z',
          toDatetime: '2024-01-31T23:59:59Z',
          chargesUsage: [],
        },
      } as UsageForSubscriptionUsageQuery

      const result = findChargeUsageByBillableMetricId(mockData, mockBillableMetricId)

      expect(result).toBeUndefined()
    })

    it('should return undefined when data does not have any expected properties', () => {
      const mockData = {} as UsageForSubscriptionUsageQuery

      const result = findChargeUsageByBillableMetricId(mockData, mockBillableMetricId)

      expect(result).toBeUndefined()
    })
  })
})
