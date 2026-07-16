import { gql } from '@apollo/client'
import { useMemo } from 'react'

import { CheckboxGroup } from '~/components/form'
import {
  EventCategoryEnum,
  EventTypeEnum,
  EventTypesQuery,
  useEventTypesQuery,
} from '~/generated/graphql'

gql`
  query eventTypes {
    eventTypes {
      key
      name
      description
      category
      deprecated
    }
  }
`

type EventTypeItem = EventTypesQuery['eventTypes'][number]

/**
 * Formats an EventCategoryEnum value into a display label.
 * e.g., "CUSTOMERS" -> "Customers"
 * e.g., "SUBSCRIPTIONS_AND_FEES" -> "Subscriptions and fees"
 * e.g., "CREDIT_NOTES" -> "Credit notes"
 */
const formatCategoryLabel = (category: EventCategoryEnum): string => {
  const withSpaces = category.replace(/_/g, ' ').toLowerCase()

  return withSpaces.charAt(0).toUpperCase() + withSpaces.slice(1)
}

/**
 * Transforms a list of event types into grouped checkbox data.
 * Uses event.category for grouping and event.key as checkbox ID.
 */
const transformEventTypesToGroups = (eventTypes: EventTypeItem[]): CheckboxGroup[] => {
  // Filter out deprecated events and the special "all" event
  const activeEvents = eventTypes.filter(
    (event) => !event.deprecated && event.key !== EventTypeEnum.All,
  )

  // Group events by category
  const groupedByCategory = activeEvents.reduce<Record<string, EventTypeItem[]>>((acc, event) => {
    const category = event.category

    if (!acc[category]) {
      acc[category] = []
    }
    acc[category].push(event)
    return acc
  }, {})

  // Transform to CheckboxGroup format and sort alphabetically by label
  return Object.entries(groupedByCategory)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([category, events]) => ({
      id: category,
      label: formatCategoryLabel(category as EventCategoryEnum),
      items: events.map((event) => ({
        id: event.key,
        label: event.name,
        sublabel: event.description,
      })),
    }))
}

/**
 * Computed display information for webhook event types.
 * Centralizes the logic for determining which events to display.
 */
type WebhookEventDisplayInfo = {
  /** Whether the webhook is listening to all events */
  isListeningToAll: boolean
  /** The list of events to display (human-readable names with dots) */
  displayedEvents: string[]
  /** The count of events being listened to */
  eventCount: number
}

/**
 * Computes display information for webhook event types.
 *
 * Logic:
 * - null/undefined eventTypes → listening to ALL events
 * - array containing EventTypeEnum.All → listening to ALL events
 * - empty array → listening to NO events
 * - array with specific values → listening to SPECIFIC events
 *
 * @param eventTypes - The eventTypes from the webhook
 * @param allEventNames - All available event display names (dotted format)
 * @param eventKeyToNameMap - Mapping from EventTypeEnum keys to display names
 */
const getWebhookEventDisplayInfo = (
  eventTypes: EventTypeEnum[] | null | undefined,
  allEventNames: string[],
  eventKeyToNameMap: Record<string, string>,
): WebhookEventDisplayInfo => {
  const isListeningToAll =
    eventTypes === null || eventTypes === undefined || eventTypes.includes(EventTypeEnum.All)

  if (isListeningToAll) {
    return {
      isListeningToAll: true,
      displayedEvents: allEventNames,
      eventCount: allEventNames.length,
    }
  }

  const displayedEvents = eventTypes.map((key) => eventKeyToNameMap[key] ?? key)

  return {
    isListeningToAll: false,
    displayedEvents,
    eventCount: displayedEvents.length,
  }
}

type UseWebhookEventTypes = () => {
  loading: boolean
  groups: CheckboxGroup[]
  /** All available event keys (EventTypeEnum values, excluding 'all') */
  allEventKeys: EventTypeEnum[]
  /** All available event display names (dotted format) — used for logs filter compatibility */
  allEventNames: string[]
  /** Mapping from EventTypeEnum key to display name */
  eventKeyToNameMap: Record<string, string>
  /** Default form values for all events (all unchecked) — used for form initialization */
  defaultEventFormValues: Record<string, boolean>
  /**
   * Utility function to compute display info for a webhook's eventTypes.
   * Centralizes the logic: null/All = all events, [] = none, [...] = specific.
   */
  getEventDisplayInfo: (eventTypes: EventTypeEnum[] | null | undefined) => WebhookEventDisplayInfo
}

export const useWebhookEventTypes: UseWebhookEventTypes = () => {
  const { data, loading } = useEventTypesQuery()

  // Active events: exclude deprecated and the special "all" value
  const activeEvents = useMemo(() => {
    if (!data?.eventTypes) return []
    return data.eventTypes.filter((e) => !e.deprecated && e.key !== EventTypeEnum.All)
  }, [data?.eventTypes])

  const groups = useMemo(() => {
    if (!data?.eventTypes) return []
    return transformEventTypesToGroups(data.eventTypes)
  }, [data?.eventTypes])

  const allEventKeys = useMemo(() => {
    return activeEvents.map((e) => e.key)
  }, [activeEvents])

  const allEventNames = useMemo(() => {
    return activeEvents.map((e) => e.name)
  }, [activeEvents])

  const eventKeyToNameMap = useMemo(() => {
    return activeEvents.reduce<Record<string, string>>((acc, event) => {
      acc[event.key] = event.name
      return acc
    }, {})
  }, [activeEvents])

  // Builds the default form state for webhook event checkboxes: all events set to false (unchecked).
  const defaultEventFormValues = useMemo(() => {
    return activeEvents.reduce<Record<string, boolean>>((acc, event) => {
      acc[event.key] = false
      return acc
    }, {})
  }, [activeEvents])

  const getEventDisplayInfo = useMemo(
    () => (eventTypes: EventTypeEnum[] | null | undefined) =>
      getWebhookEventDisplayInfo(eventTypes, allEventNames, eventKeyToNameMap),
    [allEventNames, eventKeyToNameMap],
  )

  return {
    loading,
    groups,
    allEventKeys,
    allEventNames,
    eventKeyToNameMap,
    defaultEventFormValues,
    getEventDisplayInfo,
  }
}
