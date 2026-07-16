import { AvailableFiltersEnum } from '~/components/designSystem/Filters'
import {
  ActivityTypeEnum,
  BillingEntity,
  CreditNote,
  Invoice,
  ResourceTypeEnum,
  Wallet,
} from '~/generated/graphql'

import {
  buildLinkToActivityLog,
  formatActivityType,
  getResourceLink,
  isDeletedActivityType,
} from '../utils'

describe('activityLogs utils', () => {
  describe('formatActivityType', () => {
    it('should format activity type with created suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.CustomerCreated)).toBe('customer.created')
    })

    it('should format activity type with deleted suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.CustomerDeleted)).toBe('customer.deleted')
    })

    it('should format activity type with updated suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.CustomerUpdated)).toBe('customer.updated')
    })

    it('should format activity type with generated suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoiceGenerated)).toBe('invoice.generated')
    })

    it('should format activity type with payment_status_updated suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoicePaymentStatusUpdated)).toBe(
        'invoice.payment_status_updated',
      )
    })

    it('should format activity type with ready_to_finalize suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoiceReadyToFinalize)).toBe(
        'invoice.ready_to_finalize',
      )
    })

    it('should format activity type with paid_credit_added suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoicePaidCreditAdded)).toBe(
        'invoice.paid_credit_added',
      )
    })

    it('should format activity type with refund_failure suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.CreditNoteRefundFailure)).toBe(
        'credit_note.refund_failure',
      )
    })

    it('should format activity type with payment_failure suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoicePaymentFailure)).toBe(
        'invoice.payment_failure',
      )
    })

    it('should format activity type with payment_overdue suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoicePaymentOverdue)).toBe(
        'invoice.payment_overdue',
      )
    })

    it('should format activity type with one_off_created suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoiceOneOffCreated)).toBe(
        'invoice.one_off_created',
      )
    })

    it('should format activity type with terminated suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.SubscriptionTerminated)).toBe(
        'subscription.terminated',
      )
    })

    it('should format activity type with drafted suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoiceDrafted)).toBe('invoice.drafted')
    })

    it('should format activity type with failed suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoiceFailed)).toBe('invoice.failed')
    })

    it('should format activity type with voided suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.InvoiceVoided)).toBe('invoice.voided')
    })

    it('should format activity type with recorded suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.PaymentRecorded)).toBe('payment.recorded')
    })

    it('should format activity type with started suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.SubscriptionStarted)).toBe('subscription.started')
    })

    it('should format activity type with sent suffix', () => {
      expect(formatActivityType(ActivityTypeEnum.EmailSent)).toBe('email.sent')
    })

    it('should return unchanged if no known suffix matches', () => {
      // Mock an enum value that doesn't match any known patterns
      const unknownType = 'unknown_type' as ActivityTypeEnum

      expect(formatActivityType(unknownType)).toBe('unknown_type')
    })
  })

  describe('isDeletedActivityType', () => {
    it('should return true for deleted activity types', () => {
      expect(isDeletedActivityType(ActivityTypeEnum.CustomerDeleted)).toBe(true)
      expect(isDeletedActivityType(ActivityTypeEnum.CouponDeleted)).toBe(true)
      expect(isDeletedActivityType(ActivityTypeEnum.PlanDeleted)).toBe(true)
      expect(isDeletedActivityType(ActivityTypeEnum.BillableMetricDeleted)).toBe(true)
    })

    it('should return false for non-deleted activity types', () => {
      expect(isDeletedActivityType(ActivityTypeEnum.CustomerCreated)).toBe(false)
      expect(isDeletedActivityType(ActivityTypeEnum.CustomerUpdated)).toBe(false)
      expect(isDeletedActivityType(ActivityTypeEnum.InvoiceGenerated)).toBe(false)
      expect(isDeletedActivityType(ActivityTypeEnum.EmailSent)).toBe(false)
    })
  })

  describe('getResourceLink', () => {
    it('should return null when resource is null', () => {
      expect(
        getResourceLink(null, {
          resourceType: 'Invoice',
          activityType: ActivityTypeEnum.InvoiceGenerated,
        }),
      ).toBeNull()
    })

    it('should return null when resource is undefined', () => {
      expect(
        getResourceLink(undefined, {
          resourceType: 'Invoice',
          activityType: ActivityTypeEnum.InvoiceGenerated,
        }),
      ).toBeNull()
    })

    it('should return null for deleted resources', () => {
      expect(
        getResourceLink(
          { id: 'coupon-123', __typename: 'Coupon' as const },
          { resourceType: 'Coupon', activityType: ActivityTypeEnum.CouponDeleted },
        ),
      ).toBeNull()
    })

    it('should return null when activityType is not provided', () => {
      expect(
        getResourceLink({ id: 'invoice-123', __typename: 'Invoice' as const } as Invoice, {
          resourceType: 'Invoice',
        }),
      ).toBeNull()
    })

    it('should return path for BillableMetric', () => {
      const link = getResourceLink(
        { id: 'metric-123', __typename: 'BillableMetric' as const },
        { resourceType: 'BillableMetric', activityType: ActivityTypeEnum.BillableMetricCreated },
      )

      expect(link).toContain('metric-123')
    })

    it('should return path for BillingEntity using its code', () => {
      const link = getResourceLink(
        {
          id: 'entity-123',
          code: 'entity-code',
          __typename: 'BillingEntity' as const,
        } as BillingEntity,
        { resourceType: 'BillingEntity', activityType: ActivityTypeEnum.BillingEntitiesCreated },
      )

      expect(link).toContain('entity-code')
    })

    it('should return path for Coupon', () => {
      const link = getResourceLink(
        { id: 'coupon-123', __typename: 'Coupon' as const },
        { resourceType: 'Coupon', activityType: ActivityTypeEnum.CouponCreated },
      )

      expect(link).toContain('coupon-123')
    })

    it('should return path for CreditNote when both customer and invoice are present', () => {
      const link = getResourceLink(
        {
          id: 'credit-note-123',
          customer: { id: 'customer-123' },
          invoice: { id: 'invoice-123' },
          __typename: 'CreditNote' as const,
        } as CreditNote,
        { resourceType: 'CreditNote', activityType: ActivityTypeEnum.CreditNoteCreated },
      )

      expect(link).toContain('customer-123')
      expect(link).toContain('invoice-123')
      expect(link).toContain('credit-note-123')
    })

    it('should return null for CreditNote without customer or invoice', () => {
      const link = getResourceLink(
        { id: 'credit-note-123', __typename: 'CreditNote' as const } as CreditNote,
        { resourceType: 'CreditNote', activityType: ActivityTypeEnum.CreditNoteCreated },
      )

      expect(link).toBeNull()
    })

    it('should return path for Invoice', () => {
      const link = getResourceLink(
        {
          id: 'invoice-123',
          customer: { id: 'customer-123' },
          __typename: 'Invoice' as const,
        } as Invoice,
        { resourceType: 'Invoice', activityType: ActivityTypeEnum.InvoiceGenerated },
      )

      expect(link).toContain('customer-123')
      expect(link).toContain('invoice-123')
    })

    it('should return path for Feature', () => {
      const link = getResourceLink(
        { id: 'feature-123', __typename: 'FeatureObject' as const },
        { resourceType: 'Feature', activityType: ActivityTypeEnum.FeatureCreated },
      )

      expect(link).toContain('feature-123')
    })

    it('should return path for Plan', () => {
      const link = getResourceLink(
        { id: 'plan-123', __typename: 'Plan' as const },
        { resourceType: 'Plan', activityType: ActivityTypeEnum.PlanCreated },
      )

      expect(link).toContain('plan-123')
    })

    it("should return path for Wallet using its customer's id", () => {
      const link = getResourceLink(
        {
          id: 'wallet-123',
          walletCustomer: { id: 'customer-123' },
          __typename: 'Wallet' as const,
        } as unknown as Wallet,
        { resourceType: 'Wallet', activityType: ActivityTypeEnum.WalletCreated },
      )

      expect(link).toContain('customer-123')
    })

    it('should return null for unsupported resource types', () => {
      expect(
        getResourceLink(
          { id: 'subscription-123', __typename: 'Subscription' as const },
          {
            resourceType: 'Subscription' as keyof typeof ResourceTypeEnum,
            activityType: ActivityTypeEnum.SubscriptionStarted,
          },
        ),
      ).toBeNull()
    })
  })
  describe('buildLinkToActivityLog', () => {
    it('should build link with default activityIds filter', () => {
      const result = buildLinkToActivityLog('log-123')

      expect(result).toContain('/devtool/activity-logs/log-123')
      expect(result).toContain('actl_activityIds=log-123')
    })

    it('should build link with custom filter', () => {
      const result = buildLinkToActivityLog('log-456', AvailableFiltersEnum.resourceIds)

      expect(result).toContain('/devtool/activity-logs/log-456')
      expect(result).toContain('actl_resourceIds=log-456')
    })

    it('should build link with activity IDs filter explicitly', () => {
      const result = buildLinkToActivityLog('log-789', AvailableFiltersEnum.activityIds)

      expect(result).toContain('/devtool/activity-logs/log-789')
      expect(result).toContain('actl_activityIds=log-789')
    })

    it('should encode special characters in activity ID', () => {
      const result = buildLinkToActivityLog('log-with-special-chars-#-&-=')

      expect(result).toContain('/devtool/activity-logs/log-with-special-chars-#-&-=')
      expect(result).toContain('actl_activityIds=')
    })
  })
})
