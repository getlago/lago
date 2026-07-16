import { renderHook } from '@testing-library/react'

import { ActivityTypeEnum, CurrencyEnum, ResourceTypeEnum } from '~/generated/graphql'

import { useActivityLogsInformation } from '../useActivityLogsInformation'

const mockTranslate = jest.fn((key, params) => {
  if (params) {
    return `translated:${key}:${JSON.stringify(params)}`
  }
  return `translated:${key}`
})

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

describe('useActivityLogsInformation', () => {
  beforeEach(() => {
    mockTranslate.mockClear()
  })

  describe('getResourceType', () => {
    it('should return translation key for known resource types', () => {
      const { result } = renderHook(() => useActivityLogsInformation())

      expect(result.current.getResourceType('Invoice')).toBe(
        'translated:text_63fcc3218d35b9377840f5b3',
      )
      expect(result.current.getResourceType('Customer')).toBe(
        'translated:text_65201c5a175a4b0238abf29a',
      )
      expect(result.current.getResourceType('Plan')).toBe(
        'translated:text_63d3a658c6d84a5843032145',
      )
      expect(result.current.getResourceType('Wallet')).toBe(
        'translated:text_62d175066d2dbf1d50bc9384',
      )
    })

    it('should return the resource type itself for unknown types', () => {
      const { result } = renderHook(() => useActivityLogsInformation())

      expect(result.current.getResourceType('UnknownType')).toBe('translated:UnknownType')
    })
  })

  describe('getActivityDescription', () => {
    it('should return description for AppliedCouponCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        coupon_code: 'SUMMER2024',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.AppliedCouponCreated,
        {
          activityObject,
          externalCustomerId: 'customer-123',
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714mt6os3k8404:{"couponCode":"SUMMER2024","externalCustomerId":"customer-123"}',
      )
    })

    it('should return description for AppliedCouponDeleted', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        coupon_code: 'WINTER2024',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.AppliedCouponDeleted,
        {
          activityObject,
          externalCustomerId: 'customer-456',
        },
      )

      expect(description).toBe(
        'translated:text_1747404902717ou47ei2bfd3:{"couponCode":"WINTER2024","externalCustomerId":"customer-456"}',
      )
    })

    it('should return description for BillableMetricCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'api_calls',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.BillableMetricCreated,
        {
          activityObject,
        },
      )

      expect(description).toBe('translated:text_17474046566318icwya96cm4:{"code":"api_calls"}')
    })

    it('should return description for BillableMetricDeleted', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'storage_gb',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.BillableMetricDeleted,
        {
          activityObject,
        },
      )

      expect(description).toBe('translated:text_17474046566319c9b81v2r5b:{"code":"storage_gb"}')
    })

    it('should return description for BillableMetricUpdated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'bandwidth_gb',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.BillableMetricUpdated,
        {
          activityObject,
        },
      )

      expect(description).toBe('translated:text_17474046566311zhsu2i0thx:{"code":"bandwidth_gb"}')
    })

    it('should return description for BillingEntitiesCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        name: 'Entity Name',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.BillingEntitiesCreated,
        {
          activityObject,
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714wz80iiebunk:{"entityName":"Entity Name"}',
      )
    })

    it('should return description for CouponCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'DISCOUNT50',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.CouponCreated, {
        activityObject,
      })

      expect(description).toBe(
        'translated:text_1747404806714yvdfvc0bveg:{"couponCode":"DISCOUNT50"}',
      )
    })

    it('should return description for CreditNoteCreated with formatted amount', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        number: 'CN-001',
        currency: CurrencyEnum.Usd,
        total_amount_cents: 10000,
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.CreditNoteCreated,
        {
          activityObject,
        },
      )

      expect(description).toContain('translated:text_1747404806714iqx0zaabim9:')
      expect(description).toContain('"creditNoteNumber":"CN-001"')
      expect(description).toContain('100')
    })

    it('should return description for CustomerCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {}

      const description = result.current.getActivityDescription(ActivityTypeEnum.CustomerCreated, {
        activityObject,
        externalCustomerId: 'ext-customer-123',
      })

      expect(description).toBe(
        'translated:text_1747404656632oqee107ov8u:{"externalCustomerId":"ext-customer-123"}',
      )
    })

    it('should return description for CustomerDeleted', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {}

      const description = result.current.getActivityDescription(ActivityTypeEnum.CustomerDeleted, {
        activityObject,
        externalCustomerId: 'ext-customer-456',
      })

      expect(description).toBe(
        'translated:text_1747404656632qp9qrpp0k7g:{"externalCustomerId":"ext-customer-456"}',
      )
    })

    it('should return description for CustomerUpdated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {}

      const description = result.current.getActivityDescription(ActivityTypeEnum.CustomerUpdated, {
        activityObject,
        externalCustomerId: 'ext-customer-789',
      })

      expect(description).toBe(
        'translated:text_1747404656632j5yxb9h6lsu:{"externalCustomerId":"ext-customer-789"}',
      )
    })

    it('should return description for EmailSent with valid email activity', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        document: {
          lago_id: 'invoice-123',
          number: 'INV-001',
          type: ResourceTypeEnum.Invoice,
        },
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.EmailSent, {
        activityObject,
      })

      expect(description).toContain('translated:text_17691652749726aa4es5s80q:')
      expect(mockTranslate).toHaveBeenCalled()
    })

    it('should return description for EmailSent with invalid email activity', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        // Invalid email activity object
        invalid: 'data',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.EmailSent, {
        activityObject,
      })

      expect(description).toBe('translated:text_17691652749726aa4es5s80q:{}')
    })

    it('should return description for InvoiceCreated with formatted amount', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        number: 'INV-001',
        currency: CurrencyEnum.Eur,
        total_amount_cents: 50000,
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.InvoiceCreated, {
        activityObject,
      })

      expect(description).toContain('translated:text_174740465663205ip0mama6w:')
      expect(description).toContain('"invoiceNumber":"INV-001"')
      expect(description).toContain('500')
    })

    it('should return description for InvoiceGenerated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        number: 'INV-002',
        currency: CurrencyEnum.Usd,
        total_amount_cents: 25000,
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.InvoiceGenerated, {
        activityObject,
      })

      expect(description).toContain('translated:text_174740465663232x0p7cp9d3:')
      expect(description).toContain('"invoiceNumber":"INV-002"')
      expect(description).toContain('250')
    })

    it('should return description for InvoicePaymentFailure', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        number: 'INV-003',
        currency: CurrencyEnum.Usd,
        total_amount_cents: 15000,
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.InvoicePaymentFailure,
        {
          activityObject,
        },
      )

      expect(description).toContain('translated:text_1747404656632e428r46tabf:')
      expect(description).toContain('"invoiceNumber":"INV-003"')
      expect(description).toContain('150')
    })

    it('should return description for FeatureCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'feature_code_123',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.FeatureCreated, {
        activityObject,
      })

      expect(description).toBe(
        'translated:text_1754570508183f0dl9q0pqtx:{"featureCode":"feature_code_123"}',
      )
    })

    it('should return description for PaymentReceiptCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        number: 'RECEIPT-001',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.PaymentReceiptCreated,
        {
          activityObject,
        },
      )

      expect(description).toBe(
        'translated:text_1747404656632xnc93fx6cw8:{"receiptNumber":"RECEIPT-001"}',
      )
    })

    it('should return description for PaymentRequestCreated with formatted amount', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        currency: CurrencyEnum.Usd,
        amount_cents: 30000,
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.PaymentRequestCreated,
        {
          activityObject,
        },
      )

      expect(description).toContain('translated:text_1749561986883tqfllead7o3:')
      expect(description).toContain('300')
    })

    it('should return description for PaymentRecorded with formatted amount', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        currency: CurrencyEnum.Gbp,
        amount_cents: 20000,
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.PaymentRecorded, {
        activityObject,
      })

      expect(description).toContain('translated:text_1747404806714jl31k553sr3:')
      expect(description).toContain('200')
    })

    it('should return description for PlanCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'premium_plan',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.PlanCreated, {
        activityObject,
      })

      expect(description).toBe('translated:text_17474046566311qv73xswmnm:{"code":"premium_plan"}')
    })

    it('should return description for PlanDeleted', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'basic_plan',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.PlanDeleted, {
        activityObject,
      })

      expect(description).toBe('translated:text_1747404656631vh02b35uq80:{"code":"basic_plan"}')
    })

    it('should return description for PlanUpdated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        code: 'enterprise_plan',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.PlanUpdated, {
        activityObject,
      })

      expect(description).toBe(
        'translated:text_1747404656631mkfxe18tzkx:{"code":"enterprise_plan"}',
      )
    })

    it('should return description for SubscriptionStarted', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {}

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.SubscriptionStarted,
        {
          activityObject,
          externalSubscriptionId: 'sub-123',
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714xgkold0s07a:{"externalSubscriptionId":"sub-123"}',
      )
    })

    it('should return description for SubscriptionTerminated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {}

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.SubscriptionTerminated,
        {
          activityObject,
          externalSubscriptionId: 'sub-456',
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714tszk62qvleq:{"externalSubscriptionId":"sub-456"}',
      )
    })

    it('should return description for SubscriptionUpdated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {}

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.SubscriptionUpdated,
        {
          activityObject,
          externalSubscriptionId: 'sub-789',
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714d01vx7xuhzc:{"externalSubscriptionId":"sub-789"}',
      )
    })

    it('should return description for WalletCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        lago_id: 'wallet-123',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.WalletCreated, {
        activityObject,
      })

      expect(description).toBe('translated:text_1747404806714dnwyhj6r0l9:{"walletId":"wallet-123"}')
    })

    it('should return description for WalletUpdated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        lago_id: 'wallet-456',
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.WalletUpdated, {
        activityObject,
      })

      expect(description).toBe('translated:text_1747404806714x0expgzlcnt:{"walletId":"wallet-456"}')
    })

    it('should return description for WalletTransactionCreated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        lago_wallet_id: 'wallet-789',
        lago_id: 'transaction-123',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.WalletTransactionCreated,
        {
          activityObject,
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714tl9vk3y3mzw:{"walletId":"wallet-789","transactionId":"transaction-123"}',
      )
    })

    it('should return description for WalletTransactionPaymentFailure', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        lago_wallet_id: 'wallet-abc',
        lago_id: 'transaction-def',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.WalletTransactionPaymentFailure,
        {
          activityObject,
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714mghtx7cickp:{"walletId":"wallet-abc","transactionId":"transaction-def"}',
      )
    })

    it('should return description for WalletTransactionUpdated', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        lago_wallet_id: 'wallet-xyz',
        lago_id: 'transaction-uvw',
      }

      const description = result.current.getActivityDescription(
        ActivityTypeEnum.WalletTransactionUpdated,
        {
          activityObject,
        },
      )

      expect(description).toBe(
        'translated:text_1747404806714etwdmgd36ni:{"walletId":"wallet-xyz","transactionId":"transaction-uvw"}',
      )
    })

    it('should handle zero amount correctly', () => {
      const { result } = renderHook(() => useActivityLogsInformation())
      const activityObject = {
        number: 'INV-000',
        currency: CurrencyEnum.Usd,
        total_amount_cents: 0,
      }

      const description = result.current.getActivityDescription(ActivityTypeEnum.InvoiceCreated, {
        activityObject,
      })

      expect(description).toContain('translated:text_174740465663205ip0mama6w:')
      expect(description).toContain('"invoiceNumber":"INV-000"')
      expect(description).toContain('"totalAmount"')
    })
  })
})
