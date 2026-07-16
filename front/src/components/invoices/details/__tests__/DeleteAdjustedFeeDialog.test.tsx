import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { TExtendedRemainingFee } from '~/core/formats/formatInvoiceItemsMap'
import { AllTheProviders } from '~/test-utils'

import { useDeleteAdjustedFeeDialog } from '../DeleteAdjustedFeeDialog'

const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: mockDialogOpen,
  }),
}))

const mockDestroyFee = jest.fn()
let mockMutationConfig: { onCompleted: (data: unknown) => void } | undefined

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useDestroyAdjustedFeeMutation: (config: { onCompleted: (data: unknown) => void }) => {
    mockMutationConfig = config
    return [mockDestroyFee]
  },
}))

const mockAddToast = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (...args: unknown[]) => mockAddToast(...args),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const wrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders>{children}</AllTheProviders>
)

const buildFee = (overrides = {}) =>
  ({
    id: 'fee-1',
    invoiceId: 'invoice-1',
    ...overrides,
  }) as TExtendedRemainingFee

describe('useDeleteAdjustedFeeDialog', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockMutationConfig = undefined
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return openDeleteAdjustedFeeDialog function', () => {
        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        expect(result.current.openDeleteAdjustedFeeDialog).toBeDefined()
        expect(typeof result.current.openDeleteAdjustedFeeDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openDeleteAdjustedFeeDialog is called', () => {
    describe('WHEN called with a fee', () => {
      it('THEN should open the dialog with danger variant', () => {
        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: buildFee() })
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
          }),
        )
      })

      it('THEN should pass title, description and actionText', () => {
        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: buildFee() })
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            title: expect.any(String),
            description: expect.anything(),
            actionText: expect.any(String),
          }),
        )
      })
    })
  })

  describe('GIVEN onAction is triggered in default flow', () => {
    describe('WHEN onDelete is not provided', () => {
      it('THEN should call destroyFee mutation with the fee id', async () => {
        mockDestroyFee.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: buildFee({ id: 'fee-42' }) })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockDestroyFee).toHaveBeenCalledWith({
          variables: { input: { id: 'fee-42' } },
        })
      })

      it('THEN should call destroyFee with empty id when fee is undefined', async () => {
        mockDestroyFee.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: undefined })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockDestroyFee).toHaveBeenCalledWith({
          variables: { input: { id: '' } },
        })
      })
    })
  })

  describe('GIVEN onAction is triggered in regenerate flow', () => {
    describe('WHEN onDelete is provided', () => {
      it('THEN should call onDelete with the fee id', async () => {
        const onDelete = jest.fn()

        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: buildFee({ id: 'fee-7' }), onDelete })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(onDelete).toHaveBeenCalledWith('fee-7')
      })

      it('THEN should not call destroyFee mutation', async () => {
        const onDelete = jest.fn()

        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: buildFee(), onDelete })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockDestroyFee).not.toHaveBeenCalled()
      })

      it('THEN should call onDelete with empty id when fee is undefined', async () => {
        const onDelete = jest.fn()

        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: undefined, onDelete })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(onDelete).toHaveBeenCalledWith('')
      })
    })
  })

  describe('GIVEN the destroy mutation completes', () => {
    describe('WHEN destroyAdjustedFee returns an id', () => {
      it('THEN should display a success toast', () => {
        renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          mockMutationConfig?.onCompleted({ destroyAdjustedFee: { id: 'fee-1' } })
        })

        expect(mockAddToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN destroyAdjustedFee returns no id', () => {
      it('THEN should not display a toast', () => {
        renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          mockMutationConfig?.onCompleted({ destroyAdjustedFee: null })
        })

        expect(mockAddToast).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the dialog is opened multiple times', () => {
    describe('WHEN openDeleteAdjustedFeeDialog is called with different fees', () => {
      it('THEN should use the correct fee id for each call', async () => {
        mockDestroyFee.mockResolvedValue({})

        const { result } = renderHook(() => useDeleteAdjustedFeeDialog(), { wrapper })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: buildFee({ id: 'fee-a' }) })
        })
        await act(async () => {
          await mockDialogOpen.mock.calls[0][0].onAction()
        })

        act(() => {
          result.current.openDeleteAdjustedFeeDialog({ fee: buildFee({ id: 'fee-b' }) })
        })
        await act(async () => {
          await mockDialogOpen.mock.calls[1][0].onAction()
        })

        expect(mockDestroyFee).toHaveBeenNthCalledWith(1, {
          variables: { input: { id: 'fee-a' } },
        })
        expect(mockDestroyFee).toHaveBeenNthCalledWith(2, {
          variables: { input: { id: 'fee-b' } },
        })
      })
    })
  })
})
