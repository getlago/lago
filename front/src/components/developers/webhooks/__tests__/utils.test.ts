import { StatusType } from '~/components/designSystem/Status'
import { WebhookStatusEnum } from '~/generated/graphql'

import { formatWebhookResponseLabel, statusWebhookMapping } from '../utils'

describe('webhook utils', () => {
  describe('statusWebhookMapping', () => {
    describe('GIVEN a webhook status enum value', () => {
      describe('WHEN status is Succeeded', () => {
        it('THEN should return success type with delivered label', () => {
          const result = statusWebhookMapping(WebhookStatusEnum.Succeeded)

          expect(result).toEqual({
            type: StatusType.success,
            label: 'delivered',
          })
        })
      })

      describe('WHEN status is Failed', () => {
        it('THEN should return danger type with failed label', () => {
          const result = statusWebhookMapping(WebhookStatusEnum.Failed)

          expect(result).toEqual({
            type: StatusType.danger,
            label: 'failed',
          })
        })
      })

      describe('WHEN status is Pending', () => {
        it('THEN should return default type with pending label', () => {
          const result = statusWebhookMapping(WebhookStatusEnum.Pending)

          expect(result).toEqual({
            type: StatusType.default,
            label: 'pending',
          })
        })
      })
    })

    describe('GIVEN a nullish value', () => {
      describe('WHEN status is null', () => {
        it('THEN should return default type with pending label', () => {
          const result = statusWebhookMapping(null)

          expect(result).toEqual({
            type: StatusType.default,
            label: 'pending',
          })
        })
      })

      describe('WHEN status is undefined', () => {
        it('THEN should return default type with pending label', () => {
          const result = statusWebhookMapping(undefined)

          expect(result).toEqual({
            type: StatusType.default,
            label: 'pending',
          })
        })
      })
    })
  })

  describe('formatWebhookResponseLabel', () => {
    describe('GIVEN an http status and a webhook status', () => {
      describe('WHEN status is Failed with numeric http status', () => {
        it('THEN should format as "500 Failed"', () => {
          const result = formatWebhookResponseLabel(500, WebhookStatusEnum.Failed)

          expect(result).toBe('500 Failed')
        })
      })

      describe('WHEN status is Succeeded with 200', () => {
        it('THEN should format as "200 Delivered"', () => {
          const result = formatWebhookResponseLabel(200, WebhookStatusEnum.Succeeded)

          expect(result).toBe('200 Delivered')
        })
      })

      describe('WHEN status is Pending with null http status', () => {
        it('THEN should format as "null Pending"', () => {
          const result = formatWebhookResponseLabel(null, WebhookStatusEnum.Pending)

          expect(result).toBe('null Pending')
        })
      })

      describe('WHEN http status is a string', () => {
        it('THEN should format correctly with string value', () => {
          const result = formatWebhookResponseLabel('404', WebhookStatusEnum.Failed)

          expect(result).toBe('404 Failed')
        })
      })
    })

    describe('GIVEN an undefined webhook status', () => {
      describe('WHEN status is undefined', () => {
        it('THEN should default to Pending label', () => {
          const result = formatWebhookResponseLabel(200, undefined)

          expect(result).toBe('200 Pending')
        })
      })
    })
  })
})
