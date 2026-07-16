import { renderHook } from '@testing-library/react'

import { BillingEntityEmailSettingsEnum, LagoApiError } from '~/generated/graphql'
import { useResendEmail } from '~/hooks/useResendEmail'
import { AllTheProviders } from '~/test-utils'

const mockResendCreditNoteEmail = jest.fn()
const mockResendInvoiceEmail = jest.fn()
const mockResendPaymentReceiptEmail = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useResendCreditNoteEmailMutation: () => [mockResendCreditNoteEmail],
  useResendInvoiceEmailMutation: () => [mockResendInvoiceEmail],
  useResendPaymentReceiptEmailMutation: () => [mockResendPaymentReceiptEmail],
}))

const expectedContext = {
  silentErrorCodes: [LagoApiError.UnprocessableEntity],
}

describe('useResendEmail', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return a resendEmail function', () => {
        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.resendEmail).toBe('function')
      })
    })
  })

  describe('GIVEN the type is CreditNoteCreated', () => {
    describe('WHEN resendEmail is called successfully', () => {
      it('THEN should call resendCreditNoteEmail mutation with correct variables and context', async () => {
        mockResendCreditNoteEmail.mockResolvedValue({
          data: { resendCreditNoteEmail: { id: 'cn-1' } },
        })

        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        const response = await result.current.resendEmail({
          type: BillingEntityEmailSettingsEnum.CreditNoteCreated,
          documentId: 'cn-1',
          to: ['test@example.com'],
        })

        expect(mockResendCreditNoteEmail).toHaveBeenCalledWith({
          variables: {
            input: {
              id: 'cn-1',
              to: ['test@example.com'],
            },
          },
          context: expectedContext,
        })
        expect(response).toEqual({
          success: true,
          response: { resendCreditNoteEmail: { id: 'cn-1' } },
        })
      })
    })
  })

  describe('GIVEN the type is InvoiceFinalized', () => {
    describe('WHEN resendEmail is called successfully', () => {
      it('THEN should call resendInvoiceEmail mutation with correct variables and context', async () => {
        mockResendInvoiceEmail.mockResolvedValue({
          data: { resendInvoiceEmail: { id: 'inv-1' } },
        })

        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        const response = await result.current.resendEmail({
          type: BillingEntityEmailSettingsEnum.InvoiceFinalized,
          documentId: 'inv-1',
          to: ['to@example.com'],
          cc: ['cc@example.com'],
          bcc: ['bcc@example.com'],
        })

        expect(mockResendInvoiceEmail).toHaveBeenCalledWith({
          variables: {
            input: {
              id: 'inv-1',
              to: ['to@example.com'],
              cc: ['cc@example.com'],
              bcc: ['bcc@example.com'],
            },
          },
          context: expectedContext,
        })
        expect(response).toEqual({
          success: true,
          response: { resendInvoiceEmail: { id: 'inv-1' } },
        })
      })
    })
  })

  describe('GIVEN the type is PaymentReceiptCreated', () => {
    describe('WHEN resendEmail is called successfully', () => {
      it('THEN should call resendPaymentReceiptEmail mutation with correct variables and context', async () => {
        mockResendPaymentReceiptEmail.mockResolvedValue({
          data: { resendPaymentReceiptEmail: { id: 'pr-1' } },
        })

        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        const response = await result.current.resendEmail({
          type: BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
          documentId: 'pr-1',
        })

        expect(mockResendPaymentReceiptEmail).toHaveBeenCalledWith({
          variables: {
            input: {
              id: 'pr-1',
            },
          },
          context: expectedContext,
        })
        expect(response).toEqual({
          success: true,
          response: { resendPaymentReceiptEmail: { id: 'pr-1' } },
        })
      })
    })
  })

  describe('GIVEN empty recipient arrays are provided', () => {
    describe('WHEN resendEmail is called', () => {
      it('THEN should omit empty recipient arrays from the input', async () => {
        mockResendInvoiceEmail.mockResolvedValue({
          data: { resendInvoiceEmail: { id: 'inv-1' } },
        })

        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        await result.current.resendEmail({
          type: BillingEntityEmailSettingsEnum.InvoiceFinalized,
          documentId: 'inv-1',
          to: [],
          cc: [],
          bcc: [],
        })

        expect(mockResendInvoiceEmail).toHaveBeenCalledWith({
          variables: {
            input: {
              id: 'inv-1',
            },
          },
          context: expectedContext,
        })
      })
    })
  })

  describe('GIVEN the mutation returns GraphQL errors', () => {
    describe('WHEN resendEmail is called', () => {
      it('THEN should return failure with graphQLErrors', async () => {
        const mockErrors = [
          {
            message: 'Unprocessable Entity',
            extensions: {
              status: 422,
              code: 'unprocessable_entity',
              details: { billingEntity: ['must have email configured'] },
            },
          },
        ]

        mockResendInvoiceEmail.mockResolvedValue({
          data: { resendInvoiceEmail: null },
          errors: mockErrors,
        })

        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        const response = await result.current.resendEmail({
          type: BillingEntityEmailSettingsEnum.InvoiceFinalized,
          documentId: 'inv-1',
        })

        expect(response).toEqual({
          success: false,
          graphQLErrors: mockErrors,
        })
      })
    })
  })

  describe('GIVEN the mutation throws a network error', () => {
    describe('WHEN resendEmail is called', () => {
      it('THEN should return failure without graphQLErrors', async () => {
        mockResendInvoiceEmail.mockRejectedValue(new Error('Network error'))

        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        const response = await result.current.resendEmail({
          type: BillingEntityEmailSettingsEnum.InvoiceFinalized,
          documentId: 'inv-1',
        })

        expect(response).toEqual({
          success: false,
        })
      })
    })
  })

  describe('GIVEN an unsupported type', () => {
    describe('WHEN resendEmail is called', () => {
      it('THEN should return failure', async () => {
        const { result } = renderHook(() => useResendEmail(), {
          wrapper: customWrapper,
        })

        const response = await result.current.resendEmail({
          type: 'unsupported_type' as BillingEntityEmailSettingsEnum,
          documentId: 'doc-1',
        })

        expect(response).toEqual({
          success: false,
        })
      })
    })
  })
})
