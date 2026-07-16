import { ALL_FILTER_VALUES } from '~/core/constants/form'

import {
  AssociatedInvoiceSubscription,
  AssociatedSubscription,
  composeChargeFilterDisplayName,
  composeGroupedByDisplayName,
  composeMultipleValuesWithSepator,
  createBoundaryKey,
  getSubscriptionFeeDisplayName,
  groupAndFormatFees,
} from '../formatInvoiceItemsMap'

describe('formatInvoiceItemsMap', () => {
  describe('createBoundaryKey', () => {
    it('should normalize dates to date-only format (YYYY-MM-DD)', () => {
      const from = '2024-01-15T10:30:00Z'
      const to = '2024-01-31T23:59:59Z'

      const result = createBoundaryKey(from, to)

      expect(result).toBe('2024-01-15_2024-01-31')
    })

    it('should group fees with same date but different times', () => {
      const from1 = '2024-01-15T10:30:00Z'
      const from2 = '2024-01-15T14:45:00Z'
      const to = '2024-01-31T23:59:59Z'

      const result1 = createBoundaryKey(from1, to)
      const result2 = createBoundaryKey(from2, to)

      expect(result1).toBe(result2)
      expect(result1).toBe('2024-01-15_2024-01-31')
    })

    it('should handle null fromDatetime', () => {
      const result = createBoundaryKey(null, '2024-01-31T00:00:00Z')

      expect(result).toBe('no-from_2024-01-31')
    })

    it('should handle undefined fromDatetime', () => {
      const result = createBoundaryKey(undefined, '2024-01-31T00:00:00Z')

      expect(result).toBe('no-from_2024-01-31')
    })

    it('should handle null toDatetime', () => {
      const result = createBoundaryKey('2024-01-01T00:00:00Z', null)

      expect(result).toBe('2024-01-01_no-to')
    })

    it('should handle both dates as null', () => {
      const result = createBoundaryKey(null, null)

      expect(result).toBe('no-from_no-to')
    })

    it('should handle invalid ISO strings gracefully', () => {
      const result = createBoundaryKey('invalid-date', '2024-01-31T00:00:00Z')

      // Should fallback to the original string if parsing fails
      expect(result).toContain('invalid-date')
    })

    it('should work with different timezones (UTC offset)', () => {
      const from1 = '2024-01-15T00:00:00Z'
      const from2 = '2024-01-15T05:00:00+05:00' // Same day in different timezone

      const result1 = createBoundaryKey(from1, '2024-01-31T00:00:00Z')
      const result2 = createBoundaryKey(from2, '2024-01-31T00:00:00Z')

      expect(result1).toBe(result2)
    })
  })

  describe('getSubscriptionFeeDisplayName', () => {
    it('should return invoiceDisplayName when present', () => {
      const fee = {
        invoiceDisplayName: 'Custom Subscription Name',
      }
      const subscription = {
        plan: {
          name: 'Plan Name',
          interval: 'monthly',
        },
      }

      const result = getSubscriptionFeeDisplayName(fee as any, subscription as any)

      expect(result).toBe('Custom Subscription Name')
    })

    it('should generate display name from plan when invoiceDisplayName is null', () => {
      const fee = {
        invoiceDisplayName: null,
      }
      const subscription = {
        plan: {
          name: 'Premium Plan',
          interval: 'yearly',
        },
      }

      const result = getSubscriptionFeeDisplayName(fee as any, subscription as any)

      expect(result).toBe('Yearly subscription fee - Premium Plan')
    })

    it('should handle monthly interval', () => {
      const fee = {
        invoiceDisplayName: null,
      }
      const subscription = {
        plan: {
          name: 'Basic Plan',
          interval: 'monthly',
        },
      }

      const result = getSubscriptionFeeDisplayName(fee as any, subscription as any)

      expect(result).toBe('Monthly subscription fee - Basic Plan')
    })
  })

  describe('composeChargeFilterDisplayName', () => {
    it('should return empty string when no filter provided', () => {
      const result = composeChargeFilterDisplayName()

      expect(result).toBe('')
    })

    it('should return empty string when filter is null', () => {
      const result = composeChargeFilterDisplayName(null as any)

      expect(result).toBe('')
    })

    it('should return invoiceDisplayName when present', () => {
      const result = composeChargeFilterDisplayName({
        id: 'filter-1',
        invoiceDisplayName: 'Custom Filter Name',
        values: { key: ['value'] },
      })

      expect(result).toBe('Custom Filter Name')
    })

    it('should compose values when invoiceDisplayName is null', () => {
      const result = composeChargeFilterDisplayName({
        id: 'filter-1',
        invoiceDisplayName: null,
        values: {
          region: ['US', 'EU'],
          tier: ['premium'],
        },
      })

      expect(result).toBe('US • EU • premium')
    })

    it('should handle ALL_FILTER_VALUES special value', () => {
      const result = composeChargeFilterDisplayName({
        id: 'filter-1',
        invoiceDisplayName: null,
        values: {
          region: [ALL_FILTER_VALUES],
          tier: ['basic'],
        },
      })

      expect(result).toBe('region • basic')
    })
  })

  describe('composeGroupedByDisplayName', () => {
    it('should return empty string when no groupedBy provided', () => {
      const result = composeGroupedByDisplayName()

      expect(result).toBe('')
    })

    it('should return empty string when groupedBy is null', () => {
      const result = composeGroupedByDisplayName(null as any)

      expect(result).toBe('')
    })

    it('should compose grouped by values', () => {
      const result = composeGroupedByDisplayName({
        region: 'US-East',
        environment: 'production',
      })

      expect(result).toBe('US-East • production')
    })

    it('should filter out empty values', () => {
      const result = composeGroupedByDisplayName({
        region: 'US-East',
        empty: '',
        environment: 'production',
      })

      expect(result).toBe('US-East • production')
    })
  })

  describe('composeMultipleValuesWithSepator', () => {
    it('should return empty string for empty array', () => {
      const result = composeMultipleValuesWithSepator([])

      expect(result).toBe('')
    })

    it('should return empty string for no arguments', () => {
      const result = composeMultipleValuesWithSepator()

      expect(result).toBe('')
    })

    it('should compose multiple values', () => {
      const result = composeMultipleValuesWithSepator(['value1', 'value2', 'value3'])

      expect(result).toBe('value1 • value2 • value3')
    })

    it('should filter out null and undefined values', () => {
      const result = composeMultipleValuesWithSepator(['value1', null, undefined, 'value2'])

      expect(result).toBe('value1 • value2')
    })

    it('should handle nested calls', () => {
      const result = composeMultipleValuesWithSepator([
        'value1',
        composeMultipleValuesWithSepator(['nested1', 'nested2']),
        'value2',
      ])

      expect(result).toBe('value1 • nested1 • nested2 • value2')
    })
  })

  describe('groupAndFormatFees', () => {
    const mockSubscription: AssociatedSubscription = {
      id: 'sub-1',
      name: 'My Subscription',
      plan: {
        id: 'plan-1',
        name: 'Premium Plan',
        interval: 'monthly',
        invoiceDisplayName: null,
      },
    }

    const mockInvoiceSubscription: AssociatedInvoiceSubscription = {
      subscription: { id: 'sub-1' },
      invoice: { id: 'inv-1' },
      acceptNewChargeFees: true,
    }

    describe('empty states', () => {
      it('should return empty result when no fees provided', () => {
        const result = groupAndFormatFees({
          fees: [],
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result).toEqual({
          subscriptions: {},
          metadata: {
            hasAnyFeeParsed: false,
            hasAnyPositiveFeeParsed: false,
          },
        })
      })

      it('should return empty result when fees is null', () => {
        const result = groupAndFormatFees({
          fees: null,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result).toEqual({
          subscriptions: {},
          metadata: {
            hasAnyFeeParsed: false,
            hasAnyPositiveFeeParsed: false,
          },
        })
      })

      it('should skip fees without subscription ID', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            subscription: null,
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result.subscriptions).toEqual({})
      })
    })

    describe('single subscription with single boundary', () => {
      it('should group fees correctly', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'API Calls',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'API Calls',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result.metadata).toEqual({
          hasAnyFeeParsed: true,
          hasAnyPositiveFeeParsed: true,
        })

        expect(Object.keys(result.subscriptions)).toHaveLength(1)
        expect(result.subscriptions['sub-1']).toBeDefined()
        expect(result.subscriptions['sub-1'].acceptNewChargeFees).toBe(true)
        expect(result.subscriptions['sub-1'].subscriptionDisplayName).toBe('My Subscription')

        const boundaries = result.subscriptions['sub-1'].boundaries

        expect(Object.keys(boundaries)).toHaveLength(1)

        const boundaryKey = Object.keys(boundaries)[0]

        expect(boundaries[boundaryKey].fromDatetime).toBe('2024-01-01T00:00:00Z')
        expect(boundaries[boundaryKey].toDatetime).toBe('2024-01-31T23:59:59Z')
        expect(boundaries[boundaryKey].fees).toHaveLength(1)
      })

      it('should use subscription name as display name when available', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result.subscriptions['sub-1'].subscriptionDisplayName).toBe('My Subscription')
      })

      it('should fallback to plan name when subscription name is null', () => {
        const subscriptionWithoutName = {
          ...mockSubscription,
          name: null,
        }

        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [subscriptionWithoutName],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result.subscriptions['sub-1'].subscriptionDisplayName).toBe('Premium Plan')
      })

      it('should set acceptNewChargeFees from invoiceSubscription', () => {
        const invSubWithFalse: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-1' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: false,
        }

        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [invSubWithFalse],
          invoiceId: 'inv-1',
        })

        expect(result.subscriptions['sub-1'].acceptNewChargeFees).toBe(false)
      })

      it('should default acceptNewChargeFees to false when not found', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [], // Empty - no match
          invoiceId: 'inv-1',
        })

        expect(result.subscriptions['sub-1'].acceptNewChargeFees).toBe(false)
      })
    })

    describe('single subscription with multiple boundaries', () => {
      it('should group fees by date boundaries', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-2',
            amountCents: 2000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 2',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-02-01T00:00:00Z',
              toDatetime: '2024-02-29T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        const boundaries = result.subscriptions['sub-1'].boundaries

        expect(Object.keys(boundaries)).toHaveLength(2)

        // Check boundaries are sorted by date
        const boundaryKeys = Object.keys(boundaries)

        expect(boundaryKeys[0]).toBe('2024-01-01_2024-01-31')
        expect(boundaryKeys[1]).toBe('2024-02-01_2024-02-29')
      })

      it('should group fees with same date but different times into same boundary', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T10:00:00Z',
              toDatetime: '2024-01-31T10:00:00Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-2',
            amountCents: 2000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 2',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T14:30:00Z',
              toDatetime: '2024-01-31T14:30:00Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        const boundaries = result.subscriptions['sub-1'].boundaries

        expect(Object.keys(boundaries)).toHaveLength(1)
        expect(boundaries['2024-01-01_2024-01-31'].fees).toHaveLength(2)
      })

      it('should sort boundaries by fromDatetime, then toDatetime', () => {
        const fees = [
          {
            id: 'fee-3',
            amountCents: 3000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 3',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-02-01T00:00:00Z',
              toDatetime: '2024-02-15T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-4',
            amountCents: 4000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 4',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-02-01T00:00:00Z',
              toDatetime: '2024-02-29T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-2',
            amountCents: 2000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 2',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-15T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        const boundaryKeys = Object.keys(result.subscriptions['sub-1'].boundaries)

        expect(boundaryKeys).toEqual([
          '2024-01-01_2024-01-31',
          '2024-01-15_2024-01-31',
          '2024-02-01_2024-02-15',
          '2024-02-01_2024-02-29',
        ])
      })
    })

    describe('multiple subscriptions', () => {
      it('should sort subscriptions alphabetically by display name', () => {
        const sub1: AssociatedSubscription = {
          id: 'sub-1',
          name: 'Zebra Subscription',
          plan: {
            id: 'plan-1',
            name: 'Plan 1',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const sub2: AssociatedSubscription = {
          id: 'sub-2',
          name: 'Alpha Subscription',
          plan: {
            id: 'plan-2',
            name: 'Plan 2',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const invSub1: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-1' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        const invSub2: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-2' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: false,
        }

        // Fees are added with sub-1 (Zebra) first, then sub-2 (Alpha)
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-2',
            amountCents: 2000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 2',
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [sub1, sub2],
          invoiceSubscriptions: [invSub1, invSub2],
          invoiceId: 'inv-1',
        })

        const subscriptionIds = Object.keys(result.subscriptions)

        // Alpha should come before Zebra (alphabetically sorted)
        expect(subscriptionIds).toEqual(['sub-2', 'sub-1'])

        expect(result.subscriptions['sub-2'].subscriptionDisplayName).toBe('Alpha Subscription')
        expect(result.subscriptions['sub-2'].acceptNewChargeFees).toBe(false)

        expect(result.subscriptions['sub-1'].subscriptionDisplayName).toBe('Zebra Subscription')
        expect(result.subscriptions['sub-1'].acceptNewChargeFees).toBe(true)
      })

      it('should sort subscriptions by plan name when subscription name is null', () => {
        const sub1: AssociatedSubscription = {
          id: 'sub-1',
          name: null,
          plan: {
            id: 'plan-1',
            name: 'Zulu Plan',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const sub2: AssociatedSubscription = {
          id: 'sub-2',
          name: null,
          plan: {
            id: 'plan-2',
            name: 'Beta Plan',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const invSub1: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-1' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        const invSub2: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-2' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        // Fees are added with sub-1 (Zulu Plan) first, then sub-2 (Beta Plan)
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-2',
            amountCents: 2000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 2',
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [sub1, sub2],
          invoiceSubscriptions: [invSub1, invSub2],
          invoiceId: 'inv-1',
        })

        const subscriptionIds = Object.keys(result.subscriptions)

        // Beta Plan should come before Zulu Plan (alphabetically sorted by plan name)
        expect(subscriptionIds).toEqual(['sub-2', 'sub-1'])

        expect(result.subscriptions['sub-2'].subscriptionDisplayName).toBe('Beta Plan')
        expect(result.subscriptions['sub-1'].subscriptionDisplayName).toBe('Zulu Plan')
      })

      it('should sort subscriptions case-insensitively', () => {
        const sub1: AssociatedSubscription = {
          id: 'sub-1',
          name: 'zebra subscription', // lowercase
          plan: {
            id: 'plan-1',
            name: 'Plan 1',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const sub2: AssociatedSubscription = {
          id: 'sub-2',
          name: 'ALPHA SUBSCRIPTION', // uppercase
          plan: {
            id: 'plan-2',
            name: 'Plan 2',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const sub3: AssociatedSubscription = {
          id: 'sub-3',
          name: 'Beta Subscription', // mixed case
          plan: {
            id: 'plan-3',
            name: 'Plan 3',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const invSub1: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-1' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        const invSub2: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-2' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        const invSub3: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-3' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        // Fees are added in order: sub-1 (zebra), sub-2 (ALPHA), sub-3 (Beta)
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-2',
            amountCents: 2000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 2',
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          {
            id: 'fee-3',
            amountCents: 3000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 3',
            subscription: { id: 'sub-3' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [sub1, sub2, sub3],
          invoiceSubscriptions: [invSub1, invSub2, invSub3],
          invoiceId: 'inv-1',
        })

        const subscriptionIds = Object.keys(result.subscriptions)

        // Should be sorted case-insensitively: ALPHA, Beta, zebra
        expect(subscriptionIds).toEqual(['sub-2', 'sub-3', 'sub-1'])

        expect(result.subscriptions['sub-2'].subscriptionDisplayName).toBe('ALPHA SUBSCRIPTION')
        expect(result.subscriptions['sub-3'].subscriptionDisplayName).toBe('Beta Subscription')
        expect(result.subscriptions['sub-1'].subscriptionDisplayName).toBe('zebra subscription')
      })

      it('should handle each subscription independently with different boundaries', () => {
        const sub1: AssociatedSubscription = {
          id: 'sub-1',
          name: 'Subscription 1',
          plan: {
            id: 'plan-1',
            name: 'Plan 1',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const sub2: AssociatedSubscription = {
          id: 'sub-2',
          name: 'Subscription 2',
          plan: {
            id: 'plan-2',
            name: 'Plan 2',
            interval: 'monthly',
            invoiceDisplayName: null,
          },
        }

        const invSub1: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-1' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        const invSub2: AssociatedInvoiceSubscription = {
          subscription: { id: 'sub-2' },
          invoice: { id: 'inv-1' },
          acceptNewChargeFees: true,
        }

        const fees = [
          // Sub 1 - Jan
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          // Sub 2 - Jan
          {
            id: 'fee-2',
            amountCents: 2000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 2',
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          // Sub 1 - Feb
          {
            id: 'fee-3',
            amountCents: 1500,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 3',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-02-01T00:00:00Z',
              toDatetime: '2024-02-29T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
          // Sub 2 - Feb
          {
            id: 'fee-4',
            amountCents: 2500,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 4',
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-02-01T00:00:00Z',
              toDatetime: '2024-02-29T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [sub1, sub2],
          invoiceSubscriptions: [invSub1, invSub2],
          invoiceId: 'inv-1',
        })

        // Check sub-1 has 2 boundaries
        expect(Object.keys(result.subscriptions['sub-1'].boundaries)).toHaveLength(2)
        expect(result.subscriptions['sub-1'].boundaries['2024-01-01_2024-01-31'].fees).toHaveLength(
          1,
        )
        expect(result.subscriptions['sub-1'].boundaries['2024-02-01_2024-02-29'].fees).toHaveLength(
          1,
        )

        // Check sub-2 has 2 boundaries
        expect(Object.keys(result.subscriptions['sub-2'].boundaries)).toHaveLength(2)
        expect(result.subscriptions['sub-2'].boundaries['2024-01-01_2024-01-31'].fees).toHaveLength(
          1,
        )
        expect(result.subscriptions['sub-2'].boundaries['2024-02-01_2024-02-29'].fees).toHaveLength(
          1,
        )
      })
    })

    describe('metadata flags', () => {
      it('should set hasAnyFeeParsed to true when fees exist', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 0,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result.metadata.hasAnyFeeParsed).toBe(true)
      })

      it('should set hasAnyPositiveFeeParsed to true when positive amount exists', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 1000,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result.metadata.hasAnyPositiveFeeParsed).toBe(true)
      })

      it('should set hasAnyPositiveFeeParsed to false when all amounts are zero', () => {
        const fees = [
          {
            id: 'fee-1',
            amountCents: 0,
            currency: 'USD',
            units: 1,
            feeType: 'charge',
            invoiceName: 'Fee 1',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
            charge: {
              billableMetric: {
                name: 'Metric',
              },
            },
          },
        ]

        const result = groupAndFormatFees({
          fees: fees as any,
          subscriptions: [mockSubscription],
          invoiceSubscriptions: [mockInvoiceSubscription],
          invoiceId: 'inv-1',
        })

        expect(result.metadata.hasAnyFeeParsed).toBe(true)
        expect(result.metadata.hasAnyPositiveFeeParsed).toBe(false)
      })
    })
  })
})
