import { act, renderHook } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import {
  EDIT_INVOICE_DISPLAY_NAME_FORM_ID,
  useEditInvoiceDisplayNameDialog,
} from '../useEditInvoiceDisplayName'

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

describe('useEditInvoiceDisplayNameDialog', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openEditInvoiceDisplayNameDialog function', () => {
        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openEditInvoiceDisplayNameDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openEditInvoiceDisplayNameDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open once', () => {
        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: 'My invoice',
            callback: jest.fn(),
          })
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it('THEN should include closeOnError false', () => {
        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: 'My invoice',
            callback: jest.fn(),
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.closeOnError).toBe(false)
      })

      it('THEN should pass cancelOrCloseText as cancel', () => {
        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: 'My invoice',
            callback: jest.fn(),
          })
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
        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: 'My invoice',
            callback: jest.fn(),
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with the expected id and a submit function', () => {
        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: 'My invoice',
            callback: jest.fn(),
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form).toBeDefined()
        expect(callArgs.form.id).toBe(EDIT_INVOICE_DISPLAY_NAME_FORM_ID)
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN a display name was provided', () => {
      it('THEN should invoke the callback with that display name', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: 'My invoice',
            callback,
          })
        })

        expect(callback).toHaveBeenCalledWith('My invoice')
      })
    })

    describe('WHEN the initial display name is empty', () => {
      it('THEN should invoke the callback with an empty string', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: null,
            callback,
          })
        })

        expect(callback).toHaveBeenCalledWith('')
      })
    })
  })

  describe('GIVEN the dialog resolves with close', () => {
    describe('WHEN the dialog is cancelled before submit', () => {
      it('THEN should not invoke the callback', async () => {
        const callback = jest.fn()

        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditInvoiceDisplayNameDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: 'My invoice',
            callback,
          })
        })

        expect(callback).not.toHaveBeenCalled()
      })
    })
  })
})
