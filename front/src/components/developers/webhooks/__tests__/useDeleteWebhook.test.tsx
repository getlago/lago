import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { AllTheProviders } from '~/test-utils'

import { useDeleteWebhook } from '../useDeleteWebhook'

// Mock dependencies
const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: mockDialogOpen,
  }),
}))

const mockDeleteWebhook = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useDeleteWebhookMutation: () => [mockDeleteWebhook],
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

describe('useDeleteWebhook', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return openDialog function', () => {
        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        expect(result.current.openDialog).toBeDefined()
        expect(typeof result.current.openDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openDialog is called', () => {
    describe('WHEN called with a webhook ID', () => {
      it('THEN should open the dialog with danger variant', () => {
        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        act(() => {
          result.current.openDialog('webhook-123')
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
          }),
        )
      })

      it('THEN should pass title and description', () => {
        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        act(() => {
          result.current.openDialog('webhook-123')
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            title: expect.any(String),
            description: expect.any(String),
            actionText: expect.any(String),
          }),
        )
      })
    })

    describe('WHEN onAction is triggered and delete succeeds', () => {
      it('THEN should call deleteWebhook mutation with correct ID', async () => {
        mockDeleteWebhook.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        act(() => {
          result.current.openDialog('webhook-456')
        })

        // Get the onAction callback from the dialog.open call
        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockDeleteWebhook).toHaveBeenCalledWith({
          variables: { input: { id: 'webhook-456' } },
        })
      })

      it('THEN should call onSuccess callback if provided', async () => {
        mockDeleteWebhook.mockResolvedValueOnce({})
        const onSuccess = jest.fn()

        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        act(() => {
          result.current.openDialog('webhook-456', { onSuccess })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(onSuccess).toHaveBeenCalled()
      })

      it('THEN should return success reason', async () => {
        mockDeleteWebhook.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        act(() => {
          result.current.openDialog('webhook-456')
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        let actionResult: { reason: string } | undefined

        await act(async () => {
          actionResult = await onAction()
        })

        expect(actionResult).toEqual({ reason: 'success' })
      })
    })

    describe('WHEN called without onSuccess callback', () => {
      it('THEN should not throw when delete succeeds', async () => {
        mockDeleteWebhook.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        act(() => {
          result.current.openDialog('webhook-789')
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await expect(
          act(async () => {
            await onAction()
          }),
        ).resolves.not.toThrow()
      })
    })
  })

  describe('GIVEN multiple webhooks are deleted', () => {
    describe('WHEN openDialog is called multiple times', () => {
      it('THEN should use the correct webhook ID for each call', async () => {
        mockDeleteWebhook.mockResolvedValue({})

        const { result } = renderHook(() => useDeleteWebhook(), { wrapper })

        // First delete
        act(() => {
          result.current.openDialog('webhook-1')
        })
        const onAction1 = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction1()
        })

        // Second delete
        act(() => {
          result.current.openDialog('webhook-2')
        })
        const onAction2 = mockDialogOpen.mock.calls[1][0].onAction

        await act(async () => {
          await onAction2()
        })

        expect(mockDeleteWebhook).toHaveBeenNthCalledWith(1, {
          variables: { input: { id: 'webhook-1' } },
        })
        expect(mockDeleteWebhook).toHaveBeenNthCalledWith(2, {
          variables: { input: { id: 'webhook-2' } },
        })
      })
    })
  })
})
