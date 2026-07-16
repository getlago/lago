import { renderHook } from '@testing-library/react'

import { BillingEntityEmailSettingsEnum } from '~/generated/graphql'
import { useEmailPreviewTranslationsKey } from '~/hooks/useEmailPreviewTranslationsKey'
import { AllTheProviders } from '~/test-utils'

describe('useEmailPreviewTranslationsKey', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
    })

  it('returns mapTranslationsKey function', () => {
    const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
      wrapper: customWrapper,
    })

    expect(result.current.mapTranslationsKey).toBeDefined()
    expect(typeof result.current.mapTranslationsKey).toBe('function')
  })

  describe('mapTranslationsKey', () => {
    it('returns InvoiceFinalized translations when type is InvoiceFinalized', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(
        BillingEntityEmailSettingsEnum.InvoiceFinalized,
      )

      expect(translations).toEqual({
        header: 'text_6407684eaf41130074c4b2f0',
        title: 'text_6407684eaf41130074c4b2f3',
        subtitle: 'text_6407684eaf41130074c4b2f4',
        subject: 'text_64188b3d9735d5007d71225c',
        invoice_from: 'text_64188b3d9735d5007d712266',
        amount: 'text_64188b3d9735d5007d712249',
        invoice_number: 'text_64188b3d9735d5007d71226c',
        invoice_number_value: 'text_64188b3d9735d5007d71226e',
        issue_date: 'text_64188b3d9735d5007d712270',
        issue_date_value: 'text_64188b3d9735d5007d712272',
      })
    })

    it('returns PaymentReceiptCreated translations when type is PaymentReceiptCreated', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(
        BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
      )

      expect(translations).toEqual({
        header: 'text_1741334140002zdl3cl599ib',
        title: 'text_1741334140002zdl3cl599ib',
        subtitle: 'text_1741334140002wx0sbk2bd13',
        subject: 'text_17413343926218dbogzsvk4w',
        invoice_from: 'text_1741334392621wr13yk143fc',
        amount: 'text_17413343926218vamtw2ybko',
        total: 'text_1741334392621yu0957trt4n',
        receipt_number: 'text_17416040051091zpga3ugijs',
        receipt_number_value: 'text_1741604005109q6qlr3qcc1u',
        payment_date: 'text_1741604005109kywirovj4yo',
        payment_date_value: 'text_17416040051098005r277i71',
        amount_paid: 'text_1741604005109aspaz4chd7y',
        amount_paid_value: 'text_1741604005109w5ns73xmam9',
        payment_method: 'text_17440371192353kif37ol194',
        payment_method_value: 'text_1744037119235rz9n0rfhwcp',
      })
    })

    it('returns default (CreditNote) translations when type is undefined', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(undefined)

      expect(translations).toEqual({
        header: 'text_1741334140002zdl3cl599ib',
        title: 'text_6408d642d50da800533e43d8',
        subtitle: 'text_6408d64fb486aa006163f043',
        subject: 'text_64188b3d9735d5007d712271',
        invoice_from: 'text_64188b3d9735d5007d71227b',
        amount: 'text_64188b3d9735d5007d71227d',
        total: 'text_64188b3d9735d5007d71227e',
        credit_note_number: 'text_64188b3d9735d5007d71227f',
        credit_note_number_value: 'text_64188b3d9735d5007d712280',
        invoice_number: 'text_64188b3d9735d5007d712281',
        invoice_number_value: 'text_64188b3d9735d5007d712282',
        issue_date: 'text_64188b3d9735d5007d712283',
        issue_date_value: 'text_64188b3d9735d5007d712284',
      })
    })

    it('returns default (CreditNote) translations when type is CreditNoteCreated', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(
        BillingEntityEmailSettingsEnum.CreditNoteCreated,
      )

      expect(translations).toEqual({
        header: 'text_1741334140002zdl3cl599ib',
        title: 'text_6408d642d50da800533e43d8',
        subtitle: 'text_6408d64fb486aa006163f043',
        subject: 'text_64188b3d9735d5007d712271',
        invoice_from: 'text_64188b3d9735d5007d71227b',
        amount: 'text_64188b3d9735d5007d71227d',
        total: 'text_64188b3d9735d5007d71227e',
        credit_note_number: 'text_64188b3d9735d5007d71227f',
        credit_note_number_value: 'text_64188b3d9735d5007d712280',
        invoice_number: 'text_64188b3d9735d5007d712281',
        invoice_number_value: 'text_64188b3d9735d5007d712282',
        issue_date: 'text_64188b3d9735d5007d712283',
        issue_date_value: 'text_64188b3d9735d5007d712284',
      })
    })

    it('includes invoice_number and issue_date for InvoiceFinalized', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(
        BillingEntityEmailSettingsEnum.InvoiceFinalized,
      )

      expect(translations.invoice_number).toBeDefined()
      expect(translations.invoice_number_value).toBeDefined()
      expect(translations.issue_date).toBeDefined()
      expect(translations.issue_date_value).toBeDefined()
    })

    it('includes receipt_number and payment_date for PaymentReceiptCreated', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(
        BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
      )

      expect(translations.receipt_number).toBeDefined()
      expect(translations.receipt_number_value).toBeDefined()
      expect(translations.payment_date).toBeDefined()
      expect(translations.payment_date_value).toBeDefined()
    })

    it('includes credit_note_number for CreditNoteCreated', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(
        BillingEntityEmailSettingsEnum.CreditNoteCreated,
      )

      expect(translations.credit_note_number).toBeDefined()
      expect(translations.credit_note_number_value).toBeDefined()
    })

    it('includes amount_paid and payment_method for PaymentReceiptCreated', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const translations = result.current.mapTranslationsKey(
        BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
      )

      expect(translations.amount_paid).toBeDefined()
      expect(translations.amount_paid_value).toBeDefined()
      expect(translations.payment_method).toBeDefined()
      expect(translations.payment_method_value).toBeDefined()
    })

    it('all translation types include common fields', () => {
      const { result } = renderHook(() => useEmailPreviewTranslationsKey(), {
        wrapper: customWrapper,
      })

      const types = [
        BillingEntityEmailSettingsEnum.InvoiceFinalized,
        BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
        BillingEntityEmailSettingsEnum.CreditNoteCreated,
      ]

      types.forEach((type) => {
        const translations = result.current.mapTranslationsKey(type)

        expect(translations.header).toBeDefined()
        expect(translations.title).toBeDefined()
        expect(translations.subtitle).toBeDefined()
        expect(translations.subject).toBeDefined()
        expect(translations.invoice_from).toBeDefined()
        expect(translations.amount).toBeDefined()
      })
    })
  })
})
