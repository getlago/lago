import { EventTypeEnum } from '~/generated/graphql'

import { eventTypesToFormValues, formValuesToEventTypes } from '../utils'

describe('webhookForm utils', () => {
  describe('formValuesToEventTypes', () => {
    describe('GIVEN all events are selected', () => {
      describe('WHEN converting to event types', () => {
        it('THEN should return [EventTypeEnum.All]', () => {
          const webhookEvents = {
            [EventTypeEnum.CustomerCreated]: true,
            [EventTypeEnum.InvoiceCreated]: true,
            [EventTypeEnum.SubscriptionStarted]: true,
          }

          expect(formValuesToEventTypes(webhookEvents)).toEqual([EventTypeEnum.All])
        })
      })
    })

    describe('GIVEN no events are selected', () => {
      describe('WHEN converting to event types', () => {
        it('THEN should return empty array', () => {
          const webhookEvents = {
            [EventTypeEnum.CustomerCreated]: false,
            [EventTypeEnum.InvoiceCreated]: false,
            [EventTypeEnum.SubscriptionStarted]: false,
          }

          expect(formValuesToEventTypes(webhookEvents)).toEqual([])
        })
      })
    })

    describe('GIVEN some events are selected', () => {
      describe('WHEN converting to event types', () => {
        it('THEN should return array with selected EventTypeEnum values', () => {
          const webhookEvents = {
            [EventTypeEnum.CustomerCreated]: true,
            [EventTypeEnum.InvoiceCreated]: false,
            [EventTypeEnum.SubscriptionStarted]: true,
          }

          const result = formValuesToEventTypes(webhookEvents)

          expect(result).toEqual([EventTypeEnum.CustomerCreated, EventTypeEnum.SubscriptionStarted])
        })
      })
    })

    describe('GIVEN an empty record', () => {
      describe('WHEN converting to event types', () => {
        it('THEN should return empty array', () => {
          const webhookEvents = {}

          expect(formValuesToEventTypes(webhookEvents)).toEqual([])
        })
      })
    })
  })

  describe('eventTypesToFormValues', () => {
    const allFormKeys = [
      EventTypeEnum.CustomerCreated,
      EventTypeEnum.InvoiceCreated,
      EventTypeEnum.SubscriptionStarted,
    ]

    describe('GIVEN eventTypes is null', () => {
      describe('WHEN converting to form values', () => {
        it('THEN should return all keys set to true (listening to all)', () => {
          const result = eventTypesToFormValues(null, allFormKeys)

          expect(result).toEqual({
            [EventTypeEnum.CustomerCreated]: true,
            [EventTypeEnum.InvoiceCreated]: true,
            [EventTypeEnum.SubscriptionStarted]: true,
          })
        })
      })
    })

    describe('GIVEN eventTypes is undefined', () => {
      describe('WHEN converting to form values', () => {
        it('THEN should return all keys set to false (creation mode)', () => {
          const result = eventTypesToFormValues(undefined, allFormKeys)

          expect(result).toEqual({
            [EventTypeEnum.CustomerCreated]: false,
            [EventTypeEnum.InvoiceCreated]: false,
            [EventTypeEnum.SubscriptionStarted]: false,
          })
        })
      })
    })

    describe('GIVEN eventTypes contains EventTypeEnum.All', () => {
      describe('WHEN converting to form values', () => {
        it('THEN should return all keys set to true', () => {
          const result = eventTypesToFormValues([EventTypeEnum.All], allFormKeys)

          expect(result).toEqual({
            [EventTypeEnum.CustomerCreated]: true,
            [EventTypeEnum.InvoiceCreated]: true,
            [EventTypeEnum.SubscriptionStarted]: true,
          })
        })
      })
    })

    describe('GIVEN eventTypes is an empty array', () => {
      describe('WHEN converting to form values', () => {
        it('THEN should return all keys set to false (listening to none)', () => {
          const result = eventTypesToFormValues([], allFormKeys)

          expect(result).toEqual({
            [EventTypeEnum.CustomerCreated]: false,
            [EventTypeEnum.InvoiceCreated]: false,
            [EventTypeEnum.SubscriptionStarted]: false,
          })
        })
      })
    })

    describe('GIVEN eventTypes has specific events', () => {
      describe('WHEN converting to form values', () => {
        it('THEN should return matching keys set to true, others false', () => {
          const eventTypes = [EventTypeEnum.CustomerCreated, EventTypeEnum.SubscriptionStarted]
          const result = eventTypesToFormValues(eventTypes, allFormKeys)

          expect(result).toEqual({
            [EventTypeEnum.CustomerCreated]: true,
            [EventTypeEnum.InvoiceCreated]: false,
            [EventTypeEnum.SubscriptionStarted]: true,
          })
        })
      })
    })

    describe('GIVEN eventTypes has events not in allFormKeys', () => {
      describe('WHEN converting to form values', () => {
        it('THEN should ignore unknown events', () => {
          const eventTypes = [EventTypeEnum.CustomerCreated, EventTypeEnum.WalletCreated]
          const result = eventTypesToFormValues(eventTypes, allFormKeys)

          expect(result).toEqual({
            [EventTypeEnum.CustomerCreated]: true,
            [EventTypeEnum.InvoiceCreated]: false,
            [EventTypeEnum.SubscriptionStarted]: false,
          })
        })
      })
    })

    describe('GIVEN allFormKeys is empty', () => {
      describe('WHEN converting to form values', () => {
        it('THEN should return empty object regardless of eventTypes', () => {
          expect(eventTypesToFormValues(null, [])).toEqual({})
          expect(eventTypesToFormValues([EventTypeEnum.CustomerCreated], [])).toEqual({})
        })
      })
    })
  })
})
