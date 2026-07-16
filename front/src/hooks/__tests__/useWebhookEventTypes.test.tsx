import { renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { EventCategoryEnum, EventTypeEnum, useEventTypesQuery } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useWebhookEventTypes } from '../useWebhookEventTypes'

// Mock the GraphQL query
const mockEventTypesData = {
  eventTypes: [
    {
      key: EventTypeEnum.CustomerCreated,
      name: 'customer.created',
      description: 'Customer created event',
      category: EventCategoryEnum.Customers,
      deprecated: false,
    },
    {
      key: EventTypeEnum.CustomerUpdated,
      name: 'customer.updated',
      description: 'Customer updated event',
      category: EventCategoryEnum.Customers,
      deprecated: false,
    },
    {
      key: EventTypeEnum.InvoiceCreated,
      name: 'invoice.created',
      description: 'Invoice created event',
      category: EventCategoryEnum.Invoices,
      deprecated: false,
    },
    {
      key: EventTypeEnum.InvoiceDrafted,
      name: 'invoice.drafted',
      description: 'Invoice drafted event',
      category: EventCategoryEnum.Invoices,
      deprecated: false,
    },
    {
      key: EventTypeEnum.SubscriptionStarted,
      name: 'subscription.started',
      description: 'Subscription started event',
      category: EventCategoryEnum.SubscriptionsAndFees,
      deprecated: false,
    },
    {
      key: EventTypeEnum.PaymentReceiptCreated,
      name: 'payment_receipt.created',
      description: 'Payment receipt created event',
      category: EventCategoryEnum.PaymentReceipts,
      deprecated: false,
    },
  ],
}

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useEventTypesQuery: jest.fn(() => ({
    data: mockEventTypesData,
    loading: false,
  })),
}))

const TestWrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders>{children}</AllTheProviders>
)

TestWrapper.displayName = 'TestWrapper'

describe('useWebhookEventTypes', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('hook return values', () => {
    describe('GIVEN the hook is called', () => {
      describe('WHEN data is loaded', () => {
        it('THEN should return loading as false', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          expect(result.current.loading).toBe(false)
        })

        it('THEN should return groups organized by category', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          expect(result.current.groups).toHaveLength(4)

          const customerGroup = result.current.groups.find(
            (g) => g.id === EventCategoryEnum.Customers,
          )

          expect(customerGroup).toBeDefined()
          expect(customerGroup?.label).toBe('Customers')
          expect(customerGroup?.items).toHaveLength(2)
        })

        it('THEN should return all event keys', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          expect(result.current.allEventKeys).toEqual([
            EventTypeEnum.CustomerCreated,
            EventTypeEnum.CustomerUpdated,
            EventTypeEnum.InvoiceCreated,
            EventTypeEnum.InvoiceDrafted,
            EventTypeEnum.SubscriptionStarted,
            EventTypeEnum.PaymentReceiptCreated,
          ])
        })

        it('THEN should return all event names', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          expect(result.current.allEventNames).toEqual([
            'customer.created',
            'customer.updated',
            'invoice.created',
            'invoice.drafted',
            'subscription.started',
            'payment_receipt.created',
          ])
        })

        it('THEN should return default form values with all events unchecked', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          expect(result.current.defaultEventFormValues).toEqual({
            [EventTypeEnum.CustomerCreated]: false,
            [EventTypeEnum.CustomerUpdated]: false,
            [EventTypeEnum.InvoiceCreated]: false,
            [EventTypeEnum.InvoiceDrafted]: false,
            [EventTypeEnum.SubscriptionStarted]: false,
            [EventTypeEnum.PaymentReceiptCreated]: false,
          })
        })

        it('THEN should return eventKeyToNameMap', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          expect(result.current.eventKeyToNameMap[EventTypeEnum.CustomerCreated]).toBe(
            'customer.created',
          )
          expect(result.current.eventKeyToNameMap[EventTypeEnum.InvoiceCreated]).toBe(
            'invoice.created',
          )
        })
      })
    })
  })

  describe('getEventDisplayInfo', () => {
    describe('GIVEN eventTypes is null', () => {
      describe('WHEN getting display info', () => {
        it('THEN should indicate listening to all events', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const displayInfo = result.current.getEventDisplayInfo(null)

          expect(displayInfo.isListeningToAll).toBe(true)
          expect(displayInfo.displayedEvents).toEqual(result.current.allEventNames)
          expect(displayInfo.eventCount).toBe(6)
        })
      })
    })

    describe('GIVEN eventTypes is undefined', () => {
      describe('WHEN getting display info', () => {
        it('THEN should indicate listening to all events', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const displayInfo = result.current.getEventDisplayInfo(undefined)

          expect(displayInfo.isListeningToAll).toBe(true)
          expect(displayInfo.eventCount).toBe(6)
        })
      })
    })

    describe('GIVEN eventTypes contains EventTypeEnum.All', () => {
      describe('WHEN getting display info', () => {
        it('THEN should indicate listening to all events', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const displayInfo = result.current.getEventDisplayInfo([EventTypeEnum.All])

          expect(displayInfo.isListeningToAll).toBe(true)
          expect(displayInfo.displayedEvents).toEqual(result.current.allEventNames)
          expect(displayInfo.eventCount).toBe(6)
        })
      })
    })

    describe('GIVEN eventTypes is an empty array', () => {
      describe('WHEN getting display info', () => {
        it('THEN should indicate not listening to all events with count 0', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const displayInfo = result.current.getEventDisplayInfo([])

          expect(displayInfo.isListeningToAll).toBe(false)
          expect(displayInfo.displayedEvents).toEqual([])
          expect(displayInfo.eventCount).toBe(0)
        })
      })
    })

    describe('GIVEN eventTypes has specific events', () => {
      describe('WHEN getting display info', () => {
        it('THEN should return the human-readable display names', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const eventTypes = [EventTypeEnum.CustomerCreated, EventTypeEnum.InvoiceDrafted]
          const displayInfo = result.current.getEventDisplayInfo(eventTypes)

          expect(displayInfo.isListeningToAll).toBe(false)
          expect(displayInfo.displayedEvents).toEqual(['customer.created', 'invoice.drafted'])
          expect(displayInfo.eventCount).toBe(2)
        })
      })
    })
  })

  describe('groups structure', () => {
    describe('GIVEN events from different categories', () => {
      describe('WHEN groups are generated', () => {
        it('THEN should sort groups alphabetically by category enum value', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const groupIds = result.current.groups.map((g) => g.id)

          expect(groupIds).toEqual([
            EventCategoryEnum.Customers,
            EventCategoryEnum.Invoices,
            EventCategoryEnum.PaymentReceipts,
            EventCategoryEnum.SubscriptionsAndFees,
          ])
        })

        it('THEN should format category labels correctly', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const labels = result.current.groups.map((g) => g.label)

          expect(labels).toContain('Customers')
          expect(labels).toContain('Invoices')
          expect(labels).toContain('Subscriptions and fees')
          expect(labels).toContain('Payment receipts')
        })

        it('THEN should use EventTypeEnum keys for item IDs', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const customerGroup = result.current.groups.find(
            (g) => g.id === EventCategoryEnum.Customers,
          )
          const itemIds = customerGroup?.items.map((i) => i.id)

          expect(itemIds).toContain(EventTypeEnum.CustomerCreated)
          expect(itemIds).toContain(EventTypeEnum.CustomerUpdated)
        })

        it('THEN should preserve original event names as item labels', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const customerGroup = result.current.groups.find(
            (g) => g.id === EventCategoryEnum.Customers,
          )
          const itemLabels = customerGroup?.items.map((i) => i.label)

          expect(itemLabels).toContain('customer.created')
          expect(itemLabels).toContain('customer.updated')
        })

        it('THEN should include event descriptions as sublabels', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const customerGroup = result.current.groups.find(
            (g) => g.id === EventCategoryEnum.Customers,
          )
          const createdItem = customerGroup?.items.find(
            (i) => i.id === EventTypeEnum.CustomerCreated,
          )

          expect(createdItem?.sublabel).toBe('Customer created event')
        })
      })
    })
  })

  describe('deprecated events filtering', () => {
    describe('GIVEN some events are deprecated', () => {
      beforeEach(() => {
        jest.mocked(useEventTypesQuery).mockReturnValue({
          data: {
            eventTypes: [
              {
                key: EventTypeEnum.CustomerCreated,
                name: 'customer.created',
                description: 'Customer created event',
                category: EventCategoryEnum.Customers,
                deprecated: false,
              },
              {
                key: EventTypeEnum.EventsErrors,
                name: 'events.errors',
                description: 'Deprecated events errors',
                category: EventCategoryEnum.EventIngestion,
                deprecated: true,
              },
            ],
          },
          loading: false,
        } as ReturnType<typeof useEventTypesQuery>)
      })

      describe('WHEN the hook processes events', () => {
        it('THEN should exclude deprecated events from groups', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          const allIds = result.current.groups.flatMap((g) => g.items.map((i) => i.id))

          expect(allIds).not.toContain(EventTypeEnum.EventsErrors)
          expect(allIds).toContain(EventTypeEnum.CustomerCreated)
        })

        it('THEN should exclude deprecated events from allEventKeys', () => {
          const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

          expect(result.current.allEventKeys).not.toContain(EventTypeEnum.EventsErrors)
        })
      })
    })
  })
})

describe('useWebhookEventTypes loading state', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    // Override mock to return loading state
    jest.mocked(useEventTypesQuery).mockReturnValue({
      data: undefined,
      loading: true,
    } as ReturnType<typeof useEventTypesQuery>)
  })

  describe('GIVEN data is loading', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should return loading as true', () => {
        const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

        expect(result.current.loading).toBe(true)
      })

      it('THEN should return empty groups', () => {
        const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

        expect(result.current.groups).toEqual([])
      })

      it('THEN should return empty allEventNames', () => {
        const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

        expect(result.current.allEventNames).toEqual([])
      })

      it('THEN should return empty allEventKeys', () => {
        const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

        expect(result.current.allEventKeys).toEqual([])
      })

      it('THEN should return empty defaultEventFormValues', () => {
        const { result } = renderHook(() => useWebhookEventTypes(), { wrapper: TestWrapper })

        expect(result.current.defaultEventFormValues).toEqual({})
      })
    })
  })
})
