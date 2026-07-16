import { act, renderHook, screen } from '@testing-library/react'

import { AllTheProviders, render } from '~/test-utils'

import {
  EDIT_INVOICE_ITEM_TAX_FORM_ID,
  useEditInvoiceItemTaxDialog,
} from '../EditInvoiceItemTaxDialog'
import { LocalFeeInput } from '../types'

const mockFormDialogOpen = jest.fn()

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

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetTaxesForInvoiceEditTaxDialogQuery: () => ({
    data: { taxes: { collection: [] } },
    loading: false,
  }),
}))

const TAX = { id: 'tax-1', name: 'VAT', rate: 20, code: 'vat' }
const validTaxes = [TAX] as unknown as LocalFeeInput['taxes']
const invalidTaxes = [{}] as unknown as LocalFeeInput['taxes']

describe('useEditInvoiceItemTaxDialog', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openEditInvoiceItemTaxDialog function', () => {
        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openEditInvoiceItemTaxDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openEditInvoiceItemTaxDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open once', () => {
        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: validTaxes, callback: jest.fn() })
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it.each([
        ['closeOnError', false],
        ['cancelOrCloseText', 'cancel'],
      ])('THEN should pass %s', (prop, expected) => {
        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: validTaxes, callback: jest.fn() })
        })

        expect(mockFormDialogOpen.mock.calls[0][0][prop]).toBe(expected)
      })

      it.each([
        ['title', 'string'],
        ['description', 'string'],
        ['children', 'object'],
        ['mainAction', 'object'],
      ])('THEN should include %s', (prop, expectedType) => {
        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: validTaxes, callback: jest.fn() })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with the expected id and a submit function', () => {
        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: validTaxes, callback: jest.fn() })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form.id).toBe(EDIT_INVOICE_ITEM_TAX_FORM_ID)
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN every tax row has an id', () => {
      it('THEN should invoke the callback with the taxes array', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: validTaxes, callback })
        })

        expect(callback).toHaveBeenCalledWith([TAX])
      })
    })

    describe('WHEN the taxes array is empty', () => {
      it('THEN should invoke the callback with an empty array', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: [], callback })
        })

        expect(callback).toHaveBeenCalledWith([])
      })
    })

    describe('WHEN a tax row has no id', () => {
      it('THEN should not invoke the callback and should throw to keep the dialog open', async () => {
        const callback = jest.fn()
        let submitThrew = false

        // Mirror FormDialog's handleContinue: it wraps form.submit() in try/catch,
        // and with closeOnError: false a throw keeps the dialog open.
        mockFormDialogOpen.mockImplementation(async (config) => {
          try {
            await config.form.submit()
          } catch {
            submitThrew = true
          }

          return { reason: 'close' }
        })

        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: invalidTaxes, callback })
        })

        expect(callback).not.toHaveBeenCalled()
        expect(submitThrew).toBe(true)
      })
    })

    describe('WHEN submitting with an empty tax row', () => {
      it('THEN should surface the validation error message on that row', async () => {
        let captured!: {
          children: React.ReactElement
          form: { submit: () => Promise<unknown> }
        }

        // Pending promise: the dialog stays "open", so the close-cleanup (form.reset)
        // never runs and the form keeps the [{}] row we want to assert on.
        mockFormDialogOpen.mockImplementation((config) => {
          captured = config

          return new Promise(() => {})
        })

        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: invalidTaxes, callback: jest.fn() })
        })

        // Render the dialog body (bound to the same form instance) to assert on the UI.
        render(captured.children)

        // No error before a submit attempt (submit-first behaviour).
        expect(screen.queryByText('text_1782385268545ex9rk4gx0rf')).not.toBeInTheDocument()

        await act(async () => {
          try {
            await captured.form.submit()
          } catch {
            // handleSubmit throws on invalid input to keep the dialog open.
          }
        })

        expect(screen.getByText('text_1782385268545ex9rk4gx0rf')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the dialog resolves with close', () => {
    describe('WHEN the dialog is cancelled before submit', () => {
      it('THEN should not invoke the callback', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditInvoiceItemTaxDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemTaxDialog({ taxes: validTaxes, callback })
        })

        expect(callback).not.toHaveBeenCalled()
      })
    })
  })
})
