import { act, renderHook } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import {
  EDIT_INVOICE_ITEM_DESCRIPTION_FORM_ID,
  useEditInvoiceItemDescriptionDialog,
} from '../EditInvoiceItemDescriptionDialog'

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

describe('useEditInvoiceItemDescriptionDialog', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openEditInvoiceItemDescriptionDialog function', () => {
        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openEditInvoiceItemDescriptionDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openEditInvoiceItemDescriptionDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open once', () => {
        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'A description',
            callback: jest.fn(),
          })
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it('THEN should include closeOnError false', () => {
        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'A description',
            callback: jest.fn(),
          })
        })

        expect(mockFormDialogOpen.mock.calls[0][0].closeOnError).toBe(false)
      })

      it('THEN should pass cancelOrCloseText as cancel', () => {
        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'A description',
            callback: jest.fn(),
          })
        })

        expect(mockFormDialogOpen.mock.calls[0][0].cancelOrCloseText).toBe('cancel')
      })

      it.each([
        ['title', 'string'],
        ['description', 'string'],
        ['children', 'object'],
        ['mainAction', 'object'],
      ])('THEN should include %s', (prop, expectedType) => {
        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'A description',
            callback: jest.fn(),
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with the expected id and a submit function', () => {
        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'A description',
            callback: jest.fn(),
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form.id).toBe(EDIT_INVOICE_ITEM_DESCRIPTION_FORM_ID)
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN a description is provided', () => {
      it('THEN should invoke the callback with that description', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'A description',
            callback,
          })
        })

        expect(callback).toHaveBeenCalledWith('A description')
      })
    })

    describe('WHEN the description exceeds the max length', () => {
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

        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'a'.repeat(256),
            callback,
          })
        })

        expect(callback).not.toHaveBeenCalled()
        expect(submitThrew).toBe(true)
      })
    })
  })

  describe('GIVEN the dialog resolves with close', () => {
    describe('WHEN the dialog is cancelled before submit', () => {
      it('THEN should not invoke the callback', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditInvoiceItemDescriptionDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceItemDescriptionDialog({
            description: 'A description',
            callback,
          })
        })

        expect(callback).not.toHaveBeenCalled()
      })
    })
  })
})
