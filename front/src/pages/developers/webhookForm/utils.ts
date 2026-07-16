import { EventTypeEnum } from '~/generated/graphql'

/**
 * Converts the webhookEvents form state (Record<EventTypeEnum, boolean>) to the eventTypes
 * API value:
 *  - [EventTypeEnum.All] → all checkboxes selected → receive everything
 *  - []                  → no checkbox selected → receive nothing
 *  - EventTypeEnum[]     → only selected events
 */
export const formValuesToEventTypes = (webhookEvents: Record<string, boolean>): EventTypeEnum[] => {
  const entries = Object.entries(webhookEvents)
  const selectedEvents = entries
    .filter(([, checked]) => checked)
    .map(([key]) => key as EventTypeEnum)

  // All selected → send [All] (backend sends everything)
  if (selectedEvents.length === entries.length && entries.length > 0) {
    return [EventTypeEnum.All]
  }

  // None or partial selection → return the array (possibly empty)
  return selectedEvents
}

/**
 * Converts the eventTypes from the API back to the webhookEvents form state.
 *  - undefined                                      → all checkboxes false (creation mode)
 *  - null / contains EventTypeEnum.All             → all checkboxes true (receive everything)
 *  - EventTypeEnum[]                               → matching checkboxes true
 *
 * @param eventTypes  - value from the API
 * @param allFormKeys - all available form keys (EventTypeEnum values from the event types list)
 */
export const eventTypesToFormValues = (
  eventTypes: EventTypeEnum[] | null | undefined,
  allFormKeys: string[],
): Record<string, boolean> => {
  // Build a fresh record with all keys set to false
  const values: Record<string, boolean> = {}

  for (const key of allFormKeys) {
    values[key] = false
  }

  // undefined → all checkboxes false (creation mode, no webhook loaded)
  if (eventTypes === undefined) {
    return values
  }

  // null or contains "all" means filtering OFF → all events selected
  if (eventTypes === null || eventTypes.includes(EventTypeEnum.All)) {
    for (const key of allFormKeys) {
      values[key] = true
    }

    return values
  }

  // Empty array or specific events → set matching ones to true
  for (const eventKey of eventTypes) {
    if (eventKey in values) {
      values[eventKey] = true
    }
  }

  return values
}
