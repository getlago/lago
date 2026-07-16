import { CreditTypeEnum } from '~/components/creditNote/types'
import { serializeCreditNoteInput } from '~/core/serializers/serializeCreditNoteInput'
import { CreditNoteReasonEnum, CurrencyEnum } from '~/generated/graphql'

describe('serializeCreditNoteInput', () => {
  const invoiceId = '993589e0-e8ff-46a4-a471-36618225d8e6'

  describe('GIVEN a simple credit note with only credit', () => {
    it('THEN should return serialized credit note input', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 0.74,
          amountCurrency: CurrencyEnum.Eur,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          fees: {
            '5db47206-183b-4b2b-9ce2-f8399448c2c2': {
              subscriptionName: 'Group Plan',
              fees: [
                {
                  id: 'd185efb0-dd54-4676-84ae-8feb9e5d58b6',
                  checked: true,
                  value: 0.74,
                  name: 'Group Plan',
                  maxAmount: 74,
                  appliedTaxes: [{ id: '1234', taxName: 'VAT', taxRate: 0.2 }],
                },
              ],
            },
          },
          payBack: [{ value: 0.74, type: CreditTypeEnum.credit }],
          metadata: [],
        },
        CurrencyEnum.Eur,
      )

      expect(result).toStrictEqual({
        invoiceId,
        reason: 'other',
        creditAmountCents: 74,
        description: undefined,
        refundAmountCents: 0,
        offsetAmountCents: 0,
        items: [{ feeId: 'd185efb0-dd54-4676-84ae-8feb9e5d58b6', amountCents: 74 }],
        metadata: [],
      })
    })
  })

  describe('GIVEN a credit note with credit and refund', () => {
    it('THEN should serialize both credit and refund amounts', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 50,
          amountCurrency: CurrencyEnum.Eur,
          refundAmount: 30,
          reason: CreditNoteReasonEnum.DuplicatedCharge,
          fees: {
            sub1: {
              subscriptionName: 'Plan',
              fees: [
                {
                  id: 'fee-1',
                  checked: true,
                  value: 80,
                  name: 'Fee',
                  maxAmount: 8000,
                },
              ],
            },
          },
          payBack: [
            { value: 50, type: CreditTypeEnum.credit },
            { value: 30, type: CreditTypeEnum.refund },
          ],
          metadata: [],
        },
        CurrencyEnum.Eur,
      )

      expect(result).toStrictEqual({
        invoiceId,
        reason: 'duplicated_charge',
        creditAmountCents: 5000,
        description: undefined,
        refundAmountCents: 3000,
        offsetAmountCents: 0,
        items: [{ feeId: 'fee-1', amountCents: 8000 }],
        metadata: [],
      })
    })
  })

  describe('GIVEN a credit note with offset allocation', () => {
    it('THEN should serialize offsetAmountCents', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 0,
          amountCurrency: CurrencyEnum.Usd,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          fees: {
            sub1: {
              subscriptionName: 'Plan',
              fees: [
                {
                  id: 'fee-1',
                  checked: true,
                  value: 100,
                  name: 'Fee',
                  maxAmount: 10000,
                },
              ],
            },
          },
          payBack: [
            { value: 50, type: CreditTypeEnum.credit },
            { value: 50, type: CreditTypeEnum.offset },
          ],
          metadata: [],
        },
        CurrencyEnum.Usd,
      )

      expect(result).toStrictEqual({
        invoiceId,
        reason: 'other',
        creditAmountCents: 5000,
        description: undefined,
        refundAmountCents: 0,
        offsetAmountCents: 5000,
        items: [{ feeId: 'fee-1', amountCents: 10000 }],
        metadata: [],
      })
    })
  })

  describe('GIVEN a credit note with all three allocation types', () => {
    it('THEN should serialize all allocation amounts', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 0,
          amountCurrency: CurrencyEnum.Eur,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.FraudulentCharge,
          fees: {
            sub1: {
              subscriptionName: 'Plan',
              fees: [
                {
                  id: 'fee-1',
                  checked: true,
                  value: 100,
                  name: 'Fee',
                  maxAmount: 10000,
                },
              ],
            },
          },
          payBack: [
            { value: 40, type: CreditTypeEnum.credit },
            { value: 35, type: CreditTypeEnum.refund },
            { value: 25, type: CreditTypeEnum.offset },
          ],
          metadata: [],
        },
        CurrencyEnum.Eur,
      )

      expect(result).toStrictEqual({
        invoiceId,
        reason: 'fraudulent_charge',
        creditAmountCents: 4000,
        description: undefined,
        refundAmountCents: 3500,
        offsetAmountCents: 2500,
        items: [{ feeId: 'fee-1', amountCents: 10000 }],
        metadata: [],
      })
    })
  })

  describe('GIVEN a credit note with multiple grouped fees', () => {
    it('THEN should serialize only checked fees with value > 0', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 90674,
          amountCurrency: CurrencyEnum.Eur,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          fees: {
            '5db47206-183b-4b2b-9ce2-f8399448c2c2': {
              subscriptionName: 'Group Plan',
              fees: [
                {
                  id: 'd185efb0-dd54-4676-84ae-8feb9e5d58b6',
                  checked: true,
                  value: 0.74,
                  name: 'Group Plan',
                  maxAmount: 74,
                  appliedTaxes: [{ id: '1234', taxName: 'VAT', taxRate: 0.2 }],
                },
                {
                  id: '42b948dc-cd51-4951-bc7e-8a25414e994f',
                  checked: true,
                  value: 274,
                  name: 'france',
                  maxAmount: 27400,
                  appliedTaxes: [{ id: '1234', taxName: 'VAT', taxRate: 0.2 }],
                },
                {
                  id: '3aa1eca1-4a22-4b61-ae65-7f16ee06a670',
                  checked: true,
                  value: 345,
                  name: 'italy',
                  maxAmount: 34500,
                  appliedTaxes: [{ id: '1234', taxName: 'VAT', taxRate: 0.2 }],
                },
                {
                  id: '87b3d55f-16aa-48e7-ba73-8cbac8520d77',
                  checked: false,
                  value: 0,
                  name: 'AWS • usa',
                  maxAmount: 0,
                  appliedTaxes: [{ id: '1234', taxName: 'VAT', taxRate: 0.2 }],
                },
                {
                  id: '7097d3cd-71e9-488a-8d84-6d87e94f120e',
                  checked: true,
                  value: 124,
                  name: 'AWS • europe',
                  maxAmount: 12400,
                  appliedTaxes: [{ id: '1234', taxName: 'VAT', taxRate: 0.2 }],
                },
                {
                  id: 'eb7332f7-146c-4b7f-82aa-ba6f74c06d29',
                  checked: true,
                  value: 163,
                  name: 'Google • usa',
                  maxAmount: 16300,
                  appliedTaxes: [{ id: '1234', taxName: 'VAT', taxRate: 0.2 }],
                },
              ],
            },
          },
          payBack: [{ value: 906.74, type: CreditTypeEnum.credit }],
          metadata: [],
        },
        CurrencyEnum.Eur,
      )

      expect(result).toStrictEqual({
        invoiceId,
        reason: 'other',
        creditAmountCents: 90674,
        description: undefined,
        refundAmountCents: 0,
        offsetAmountCents: 0,
        items: [
          { feeId: 'd185efb0-dd54-4676-84ae-8feb9e5d58b6', amountCents: 74 },
          { feeId: '42b948dc-cd51-4951-bc7e-8a25414e994f', amountCents: 27400 },
          { feeId: '3aa1eca1-4a22-4b61-ae65-7f16ee06a670', amountCents: 34500 },
          { feeId: '7097d3cd-71e9-488a-8d84-6d87e94f120e', amountCents: 12400 },
          { feeId: 'eb7332f7-146c-4b7f-82aa-ba6f74c06d29', amountCents: 16300 },
        ],
        metadata: [],
      })
    })
  })

  describe('GIVEN a credit note with addOnFee', () => {
    it('THEN should serialize addon fees', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 100,
          amountCurrency: CurrencyEnum.Usd,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          addOnFee: [
            { id: 'addon-1', checked: true, value: 50, name: 'Addon 1', maxAmount: 5000 },
            { id: 'addon-2', checked: false, value: 30, name: 'Addon 2', maxAmount: 3000 },
            { id: 'addon-3', checked: true, value: 50, name: 'Addon 3', maxAmount: 5000 },
          ],
          payBack: [{ value: 100, type: CreditTypeEnum.credit }],
          metadata: [],
        },
        CurrencyEnum.Usd,
      )

      expect(result.items).toStrictEqual([
        { feeId: 'addon-1', amountCents: 5000 },
        { feeId: 'addon-3', amountCents: 5000 },
      ])
    })
  })

  describe('GIVEN a credit note with creditFee (prepaid credits)', () => {
    it('THEN should serialize credit fees', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 100,
          amountCurrency: CurrencyEnum.Usd,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          creditFee: [
            { id: 'credit-1', checked: true, value: 100, name: 'Credit 1', maxAmount: 10000 },
          ],
          payBack: [{ value: 100, type: CreditTypeEnum.credit }],
          metadata: [],
        },
        CurrencyEnum.Usd,
      )

      expect(result.items).toStrictEqual([{ feeId: 'credit-1', amountCents: 10000 }])
    })
  })

  describe('GIVEN undefined payBack', () => {
    it('THEN should return 0 for all allocation amounts', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 0,
          amountCurrency: CurrencyEnum.Eur,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          fees: {},
          payBack: undefined as unknown as [],
          metadata: [],
        },
        CurrencyEnum.Eur,
      )

      expect(result.creditAmountCents).toBe(0)
      expect(result.refundAmountCents).toBe(0)
      expect(result.offsetAmountCents).toBe(0)
    })
  })

  describe('GIVEN metadata', () => {
    it('THEN should include metadata in the output', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 50,
          amountCurrency: CurrencyEnum.Eur,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          fees: {
            sub1: {
              subscriptionName: 'Plan',
              fees: [{ id: 'fee-1', checked: true, value: 50, name: 'Fee', maxAmount: 5000 }],
            },
          },
          payBack: [{ value: 50, type: CreditTypeEnum.credit }],
          metadata: [
            { key: 'order_id', value: '12345' },
            { key: 'customer_ref', value: 'ABC' },
          ],
        },
        CurrencyEnum.Eur,
      )

      expect(result.metadata).toStrictEqual([
        { key: 'order_id', value: '12345' },
        { key: 'customer_ref', value: 'ABC' },
      ])
    })
  })

  describe('GIVEN description', () => {
    it('THEN should include description in the output', () => {
      const result = serializeCreditNoteInput(
        invoiceId,
        {
          creditAmount: 50,
          amountCurrency: CurrencyEnum.Eur,
          refundAmount: 0,
          reason: CreditNoteReasonEnum.Other,
          description: 'Customer requested refund',
          fees: {
            sub1: {
              subscriptionName: 'Plan',
              fees: [{ id: 'fee-1', checked: true, value: 50, name: 'Fee', maxAmount: 5000 }],
            },
          },
          payBack: [{ value: 50, type: CreditTypeEnum.credit }],
          metadata: [],
        },
        CurrencyEnum.Eur,
      )

      expect(result.description).toBe('Customer requested refund')
    })
  })
})
