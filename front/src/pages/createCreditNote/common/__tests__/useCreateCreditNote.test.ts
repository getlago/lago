import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'

import { GetInvoiceCreateCreditNoteDocument } from '~/generated/graphql'
import {
  fullOneOffInvoiceMockAndExpect,
  fullSubscriptionInvoiceGroupTrueUpMockAndExpect,
  fullSubscriptionInvoiceMockAndExpect,
  INVOICE_FIXTURE_ID,
  invoiceWithNoCredOrRefundAmountMockAndExpect,
} from '~/hooks/__tests__/fixtures'
import { AllTheProviders } from '~/test-utils'

import { useCreateCreditNote } from '../useCreateCreditNote'

type PrepareType = { mock?: Record<string, unknown> }

async function prepare({ mock }: PrepareType = {}) {
  const mocks = [
    {
      request: {
        query: GetInvoiceCreateCreditNoteDocument,
        variables: { id: INVOICE_FIXTURE_ID },
      },
      result: {
        data: mock,
      },
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      useParams: { id: '1', invoiceId: INVOICE_FIXTURE_ID },
      forceTypenames: true,
    })

  const { result } = renderHook(() => useCreateCreditNote(), {
    wrapper: customWrapper,
  })

  return { result: result }
}

describe('useCreateCreditNote()', () => {
  it('returns default datas', async () => {
    const { mock } = fullSubscriptionInvoiceMockAndExpect()
    const { result } = await prepare({ mock })

    expect(result.current.loading).toBeTruthy()

    // Skip loading state
    await act(() => wait(0))

    expect(result.current.loading).toBeFalsy()
    expect(result.current.invoice).toBeDefined()
    expect(result.current.feesPerInvoice).toBeDefined()
    expect(result.current.feeForAddOn).not.toBeDefined()
    expect(result.current.onCreate).toBeDefined()
  })

  it('should format feeForAddOn correctly', async () => {
    const { mock, transformedObject } = fullOneOffInvoiceMockAndExpect()

    const { result } = await prepare({ mock })

    // Skip loading state
    await act(() => wait(0))

    expect(result.current.feeForAddOn).toStrictEqual(transformedObject)
  })

  it('should format feesPerInvoice correctly', async () => {
    const { mock, transformedObject } = fullSubscriptionInvoiceGroupTrueUpMockAndExpect()

    const { result } = await prepare({ mock })

    // Skip loading state
    await act(() => wait(0))

    expect(result.current.feesPerInvoice).toStrictEqual(transformedObject)
  })

  describe('hasCreditableOrRefundableAmount', () => {
    it('should return true when creditableAmountCents > 0', async () => {
      const { mock } = fullOneOffInvoiceMockAndExpect()
      const { result } = await prepare({ mock })

      await act(() => wait(0))

      expect(result.current.hasCreditableOrRefundableAmount).toBe(true)
    })

    it('should return true when refundableAmountCents > 0', async () => {
      const { mock } = fullSubscriptionInvoiceMockAndExpect()
      // Modify mock to have refundableAmountCents > 0
      const modifiedMock = {
        invoice: {
          ...mock.invoice,
          creditableAmountCents: '0',
          refundableAmountCents: '1000',
        },
      }
      const { result } = await prepare({ mock: modifiedMock })

      await act(() => wait(0))

      expect(result.current.hasCreditableOrRefundableAmount).toBe(true)
    })

    it('should return false when both creditableAmountCents and refundableAmountCents are 0', async () => {
      const { mock } = invoiceWithNoCredOrRefundAmountMockAndExpect()
      const { result } = await prepare({ mock })

      await act(() => wait(0))

      expect(result.current.hasCreditableOrRefundableAmount).toBe(false)
    })
  })

  describe('offsettableAmountCents fallback', () => {
    it('should use offsettableAmountCents when hasCreditableOrRefundableAmount is false', async () => {
      const { mock, transformedObject } = invoiceWithNoCredOrRefundAmountMockAndExpect()
      const { result } = await prepare({ mock })

      await act(() => wait(0))

      expect(result.current.hasCreditableOrRefundableAmount).toBe(false)
      expect(result.current.feeForAddOn).toStrictEqual(transformedObject)
    })

    it('should set isReadOnly to true when using offsettableAmountCents', async () => {
      const { mock } = invoiceWithNoCredOrRefundAmountMockAndExpect()
      const { result } = await prepare({ mock })

      await act(() => wait(0))

      expect(result.current.feeForAddOn?.[0]?.isReadOnly).toBe(true)
      expect(result.current.feeForAddOn?.[1]?.isReadOnly).toBe(true)
    })

    it('should set isReadOnly to false when using creditableAmountCents', async () => {
      const { mock } = fullOneOffInvoiceMockAndExpect()
      const { result } = await prepare({ mock })

      await act(() => wait(0))

      expect(result.current.feeForAddOn?.[0]?.isReadOnly).toBe(false)
    })
  })
})
