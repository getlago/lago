import { Settings } from 'luxon'

import {
  buildCreditNoteDocumentData,
  buildInvoiceDocumentData,
  buildPaymentDocumentData,
} from '~/components/emails/buildDocumentData'
import { CurrencyEnum, PaymentTypeEnum, ProviderTypeEnum, TimezoneEnum } from '~/generated/graphql'

const originalDefaultZone = Settings.defaultZone

describe('buildDocumentData', () => {
  beforeAll(() => {
    Settings.defaultZone = 'UTC'
  })

  afterAll(() => {
    Settings.defaultZone = originalDefaultZone
  })

  // --- buildInvoiceDocumentData ---

  describe('buildInvoiceDocumentData', () => {
    describe('GIVEN a null or undefined invoice', () => {
      describe('WHEN called with null', () => {
        it('THEN should return an empty object', () => {
          expect(buildInvoiceDocumentData(null)).toEqual({})
        })
      })

      describe('WHEN called with undefined', () => {
        it('THEN should return an empty object', () => {
          expect(buildInvoiceDocumentData(undefined)).toEqual({})
        })
      })
    })

    describe('GIVEN a complete invoice', () => {
      describe('WHEN all fields are provided', () => {
        it('THEN should return formatted amount, invoice number, and issue date', () => {
          const result = buildInvoiceDocumentData({
            totalAmountCents: 123456,
            currency: CurrencyEnum.Usd,
            number: 'INV-2026-001',
            issuingDate: '2026-03-10T00:00:00Z',
          })

          expect(result).toEqual({
            amount: expect.any(String),
            invoiceNumber: 'INV-2026-001',
            issueDate: expect.any(String),
          })
          expect(result.amount).toContain('1,234.56')
          expect(result.issueDate).toBeTruthy()
        })
      })
    })

    describe('GIVEN an invoice with missing optional fields', () => {
      describe('WHEN issuingDate is null', () => {
        it('THEN should return undefined for issueDate', () => {
          const result = buildInvoiceDocumentData({
            totalAmountCents: 10000,
            currency: CurrencyEnum.Eur,
            number: 'INV-001',
            issuingDate: null,
          })

          expect(result.issueDate).toBeUndefined()
          expect(result.invoiceNumber).toBe('INV-001')
        })
      })

      describe('WHEN number is null', () => {
        it('THEN should return undefined for invoiceNumber', () => {
          const result = buildInvoiceDocumentData({
            totalAmountCents: 5000,
            currency: CurrencyEnum.Usd,
            number: null,
          })

          expect(result.invoiceNumber).toBeUndefined()
        })
      })

      describe('WHEN totalAmountCents is null', () => {
        it('THEN should default to 0 for the amount', () => {
          const result = buildInvoiceDocumentData({
            totalAmountCents: null,
            currency: CurrencyEnum.Usd,
          })

          expect(result.amount).toBeTruthy()
          expect(result.amount).toContain('0')
        })
      })

      describe('WHEN currency is null', () => {
        it('THEN should default to USD', () => {
          const result = buildInvoiceDocumentData({
            totalAmountCents: 10000,
            currency: null,
          })

          expect(result.amount).toContain('$')
        })
      })
    })
  })

  // --- buildCreditNoteDocumentData ---

  describe('buildCreditNoteDocumentData', () => {
    describe('GIVEN a null or undefined credit note', () => {
      describe('WHEN called with null', () => {
        it('THEN should return an empty object', () => {
          expect(buildCreditNoteDocumentData(null)).toEqual({})
        })
      })

      describe('WHEN called with undefined', () => {
        it('THEN should return an empty object', () => {
          expect(buildCreditNoteDocumentData(undefined)).toEqual({})
        })
      })
    })

    describe('GIVEN a complete credit note', () => {
      describe('WHEN all fields are provided including related invoice', () => {
        it('THEN should return formatted amount, credit note number, invoice number, and issue date', () => {
          const result = buildCreditNoteDocumentData({
            totalAmountCents: 50000,
            currency: CurrencyEnum.Usd,
            number: 'CN-2026-001',
            createdAt: '2026-03-10T12:00:00Z',
            invoice: { number: 'INV-2026-005' },
          })

          expect(result).toEqual({
            amount: expect.any(String),
            creditNoteNumber: 'CN-2026-001',
            invoiceNumber: 'INV-2026-005',
            issueDate: expect.any(String),
          })
          expect(result.amount).toContain('500')
        })
      })
    })

    describe('GIVEN a credit note with missing optional fields', () => {
      describe('WHEN invoice is null', () => {
        it('THEN should return undefined for invoiceNumber', () => {
          const result = buildCreditNoteDocumentData({
            totalAmountCents: 10000,
            currency: CurrencyEnum.Usd,
            number: 'CN-001',
            invoice: null,
          })

          expect(result.invoiceNumber).toBeUndefined()
          expect(result.creditNoteNumber).toBe('CN-001')
        })
      })

      describe('WHEN createdAt is null', () => {
        it('THEN should return undefined for issueDate', () => {
          const result = buildCreditNoteDocumentData({
            totalAmountCents: 10000,
            currency: CurrencyEnum.Usd,
            number: 'CN-001',
            createdAt: null,
          })

          expect(result.issueDate).toBeUndefined()
        })
      })
    })
  })

  // --- buildPaymentDocumentData ---

  describe('buildPaymentDocumentData', () => {
    const mockTranslate = (key: string) => key

    const basePaymentInput = {
      amountCents: 200000,
      amountCurrency: CurrencyEnum.Usd as CurrencyEnum | null,
      createdAt: '2026-03-10T14:30:00Z' as string | null,
      paymentType: PaymentTypeEnum.Provider as PaymentTypeEnum | null,
      paymentProviderType: ProviderTypeEnum.Stripe as ProviderTypeEnum | null,
      paymentReceipt: { number: 'REC-2026-001' },
      invoices: [
        { number: 'INV-001', totalAmountCents: 100000, currency: CurrencyEnum.Usd },
        { number: 'INV-002', totalAmountCents: 100000, currency: CurrencyEnum.Usd },
      ],
      translate: mockTranslate,
    }

    describe('GIVEN a complete payment', () => {
      describe('WHEN all fields are provided with a provider payment type', () => {
        it('THEN should return all formatted payment fields', () => {
          const result = buildPaymentDocumentData(basePaymentInput)

          expect(result.amount).toContain('2,000')
          expect(result.receiptNumber).toBe('REC-2026-001')
          expect(result.paymentDate).toBeTruthy()
          expect(result.paymentMethod).toBeTruthy()
          expect(result.amountPaid).toContain('2,000')
          expect(result.invoices).toHaveLength(2)
          expect(result.invoices?.[0]?.number).toBe('INV-001')
          expect(result.invoices?.[0]?.amount).toContain('1,000')
          expect(result.invoices?.[1]?.number).toBe('INV-002')
        })
      })
    })

    describe('GIVEN a manual payment', () => {
      describe('WHEN paymentType is Manual', () => {
        it('THEN should use the manual payment label key', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            paymentType: PaymentTypeEnum.Manual,
            paymentProviderType: null,
          })

          expect(result.paymentMethod).toBe('text_173799550683709p2rqkoqd5')
        })
      })
    })

    describe('GIVEN different provider types', () => {
      describe.each([
        [ProviderTypeEnum.Stripe, 'text_62b1edddbf5f461ab971277d'],
        [ProviderTypeEnum.Adyen, 'text_645d071272418a14c1c76a6d'],
        [ProviderTypeEnum.Gocardless, 'text_634ea0ecc6147de10ddb6625'],
        [ProviderTypeEnum.Cashfree, 'text_17367626793434wkg1rk0114'],
        [ProviderTypeEnum.Flutterwave, 'text_1749724395108m0swrna0zt4'],
        [ProviderTypeEnum.Moneyhash, 'text_1733427981129n3wxjui0bex'],
      ])('WHEN provider is %s', (provider, expectedKey) => {
        it('THEN should translate the correct provider label key', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            paymentProviderType: provider,
          })

          expect(result.paymentMethod).toBe(expectedKey)
        })
      })
    })

    describe('GIVEN missing payment method info', () => {
      describe('WHEN both paymentType and paymentProviderType are null', () => {
        it('THEN should return undefined for paymentMethod', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            paymentType: null,
            paymentProviderType: null,
          })

          expect(result.paymentMethod).toBeUndefined()
        })
      })
    })

    describe('GIVEN missing payment fields', () => {
      describe('WHEN createdAt is null', () => {
        it('THEN should return undefined for paymentDate', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            createdAt: null,
          })

          expect(result.paymentDate).toBeUndefined()
        })
      })

      describe('WHEN paymentReceipt is null', () => {
        it('THEN should return undefined for receiptNumber', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            paymentReceipt: null,
          })

          expect(result.receiptNumber).toBeUndefined()
        })
      })

      describe('WHEN amountCents is null', () => {
        it('THEN should default to 0 for amount', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            amountCents: null,
          })

          expect(result.amount).toContain('0')
          expect(result.amountPaid).toContain('0')
        })
      })
    })

    describe('GIVEN invoices without amount data', () => {
      describe('WHEN invoice totalAmountCents is null', () => {
        it('THEN should return empty string for invoice amount', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            invoices: [{ number: 'INV-001', totalAmountCents: null, currency: null }],
          })

          expect(result.invoices?.[0]?.amount).toBe('')
        })
      })

      describe('WHEN invoices array is empty', () => {
        it('THEN should return empty invoices array', () => {
          const result = buildPaymentDocumentData({
            ...basePaymentInput,
            invoices: [],
          })

          expect(result.invoices).toEqual([])
        })
      })
    })

    describe('GIVEN a timezone', () => {
      describe('WHEN timezone is provided', () => {
        it('THEN should format the date with the timezone', () => {
          const resultWithTz = buildPaymentDocumentData({
            ...basePaymentInput,
            timezone: TimezoneEnum.TzAmericaNewYork,
          })

          const resultWithoutTz = buildPaymentDocumentData({
            ...basePaymentInput,
            timezone: null,
          })

          // Both should have a date, but they may differ due to timezone
          expect(resultWithTz.paymentDate).toBeTruthy()
          expect(resultWithoutTz.paymentDate).toBeTruthy()
        })
      })
    })
  })
})
