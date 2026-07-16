import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { addToast } from '~/core/apolloClient'
import { AllTheProviders } from '~/test-utils'

import { useDeleteWalletAlertDialog } from '../DeleteWalletAlertDialog'

const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: mockDialogOpen,
  }),
}))

const mockDeleteWalletAlert = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useDestroyWalletAlertMutation: () => [mockDeleteWalletAlert],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const wrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders>{children}</AllTheProviders>
)

describe('useDeleteWalletAlertDialog', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return openDeleteWalletAlertDialog function', () => {
        const { result } = renderHook(() => useDeleteWalletAlertDialog(), { wrapper })

        expect(result.current.openDeleteWalletAlertDialog).toBeDefined()
        expect(typeof result.current.openDeleteWalletAlertDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openDeleteWalletAlertDialog is called', () => {
    describe('WHEN called with alert data', () => {
      it('THEN should open the dialog with danger variant', () => {
        const { result } = renderHook(() => useDeleteWalletAlertDialog(), { wrapper })

        act(() => {
          result.current.openDeleteWalletAlertDialog({ alertId: 'alert-123' })
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
            title: expect.any(String),
            description: expect.any(String),
            actionText: expect.any(String),
          }),
        )
      })
    })

    describe('WHEN onAction is triggered and mutation succeeds', () => {
      it('THEN should call the mutation with correct alertId', async () => {
        mockDeleteWalletAlert.mockResolvedValueOnce({
          data: { destroyCustomerWalletAlert: { id: 'alert-456' } },
        })

        const { result } = renderHook(() => useDeleteWalletAlertDialog(), { wrapper })

        act(() => {
          result.current.openDeleteWalletAlertDialog({ alertId: 'alert-456' })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockDeleteWalletAlert).toHaveBeenCalledWith({
          variables: { input: { id: 'alert-456' } },
        })
      })

      it('THEN should call callback and addToast with severity success', async () => {
        mockDeleteWalletAlert.mockResolvedValueOnce({
          data: { destroyCustomerWalletAlert: { id: 'alert-789' } },
        })
        const callback = jest.fn()

        const { result } = renderHook(() => useDeleteWalletAlertDialog(), { wrapper })

        act(() => {
          result.current.openDeleteWalletAlertDialog({
            alertId: 'alert-789',
            callback,
          })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(callback).toHaveBeenCalled()
        expect(addToast).toHaveBeenCalledWith(
          expect.objectContaining({
            severity: 'success',
            message: expect.any(String),
          }),
        )
      })
    })

    describe('WHEN alertId is undefined', () => {
      it('THEN should pass empty string to mutation', async () => {
        mockDeleteWalletAlert.mockResolvedValueOnce({
          data: { destroyCustomerWalletAlert: { id: '' } },
        })

        const { result } = renderHook(() => useDeleteWalletAlertDialog(), { wrapper })

        act(() => {
          result.current.openDeleteWalletAlertDialog({ alertId: undefined })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockDeleteWalletAlert).toHaveBeenCalledWith({
          variables: { input: { id: '' } },
        })
      })
    })
  })
})
