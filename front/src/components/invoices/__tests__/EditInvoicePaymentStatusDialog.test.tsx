import { act, renderHook } from '@testing-library/react'

import { addToast } from '~/core/apolloClient'
import {
  InvoiceForUpdateInvoicePaymentStatusFragment,
  InvoicePaymentStatusTypeEnum,
} from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import {
  UPDATE_INVOICE_PAYMENT_STATUS_FORM_ID,
  useUpdateInvoicePaymentStatusDialog,
} from '../EditInvoicePaymentStatusDialog'

const mockFormDialogOpen = jest.fn()
const mockUpdateInvoice = jest.fn()

jest.mock('~/components/dialogs/FormDialog', () => ({
  ...jest.requireActual('~/components/dialogs/FormDialog'),
  useFormDialog: () => ({
    open: mockFormDialogOpen,
    close: jest.fn(),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/generated/graphql', () => {
  const actual = jest.requireActual('~/generated/graphql')

  return {
    ...actual,
    useUpdateInvoicePaymentStatusMutation: (options?: {
      onCompleted?: (data: unknown) => void
    }) => [
      async (variables: unknown) => {
        const result = await mockUpdateInvoice(variables)

        if (result?.data) {
          options?.onCompleted?.(result.data)
        }

        return result
      },
    ],
  }
})

const INVOICE_ID = 'invoice-1'

const buildInvoice = (
  overrides: Partial<InvoiceForUpdateInvoicePaymentStatusFragment> = {},
): InvoiceForUpdateInvoicePaymentStatusFragment => ({
  __typename: 'Invoice',
  id: INVOICE_ID,
  paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
  ...overrides,
})

const buildSuccessResult = () => ({
  data: {
    updateInvoice: {
      __typename: 'Invoice',
      id: INVOICE_ID,
      paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
    },
  },
  errors: undefined,
})

describe('useUpdateInvoicePaymentStatusDialog', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openUpdateInvoicePaymentStatusDialog function', () => {
        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openUpdateInvoicePaymentStatusDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openUpdateInvoicePaymentStatusDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open once', () => {
        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it('THEN should include closeOnError false', () => {
        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.closeOnError).toBe(false)
      })

      it('THEN should pass cancelOrCloseText as cancel', () => {
        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.cancelOrCloseText).toBe('cancel')
      })

      it.each([
        ['title', 'string'],
        ['description', 'string'],
        ['children', 'object'],
        ['mainAction', 'object'],
      ])('THEN should include %s', (prop, expectedType) => {
        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with the expected id and a submit function', () => {
        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form).toBeDefined()
        expect(callArgs.form.id).toBe(UPDATE_INVOICE_PAYMENT_STATUS_FORM_ID)
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN a payment status is provided', () => {
      it('THEN should call the mutation with the invoice id and payment status', async () => {
        mockUpdateInvoice.mockResolvedValue(buildSuccessResult())
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openUpdateInvoicePaymentStatusDialog(
            buildInvoice({ paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded }),
          )
        })

        expect(mockUpdateInvoice).toHaveBeenCalledWith({
          variables: {
            input: {
              id: INVOICE_ID,
              paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
            },
          },
        })
      })
    })

    describe('WHEN the mutation succeeds', () => {
      it('THEN should show a success toast', async () => {
        mockUpdateInvoice.mockResolvedValue(buildSuccessResult())
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN the mutation returns no data', () => {
      it('THEN handleSubmit should throw Submit failed', async () => {
        mockUpdateInvoice.mockResolvedValue({ data: null, errors: undefined })

        let submitError: unknown = null

        mockFormDialogOpen.mockImplementation(async (config) => {
          try {
            await config.form.submit()
          } catch (err) {
            submitError = err
          }

          return { reason: 'close' }
        })

        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        expect(submitError).toBeInstanceOf(Error)
        expect((submitError as Error).message).toBe('Submit failed')
      })
    })
  })

  describe('GIVEN the dialog resolves with close', () => {
    describe('WHEN the dialog is cancelled before submit', () => {
      it('THEN should not call the mutation', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        expect(mockUpdateInvoice).not.toHaveBeenCalled()
      })

      it('THEN should not show a toast', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useUpdateInvoicePaymentStatusDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openUpdateInvoicePaymentStatusDialog(buildInvoice())
        })

        expect(addToast).not.toHaveBeenCalled()
      })
    })
  })
})
