import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { AllTheProviders } from '~/test-utils'

import { useTerminateCoupon } from '../useTerminateCoupon'

const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: mockDialogOpen,
  }),
}))

const mockTerminateCoupon = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useTerminateCouponMutation: () => [mockTerminateCoupon],
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

describe('useTerminateCoupon', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return openDialog function', () => {
        const { result } = renderHook(() => useTerminateCoupon(), { wrapper })

        expect(result.current.openDialog).toBeDefined()
        expect(typeof result.current.openDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openDialog is called', () => {
    describe('WHEN called with a coupon', () => {
      it('THEN should open the dialog with danger variant', () => {
        const { result } = renderHook(() => useTerminateCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({ id: 'coupon-123', name: 'Summer Sale' })
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
          }),
        )
      })

      it('THEN should pass title, description, and actionText', () => {
        const { result } = renderHook(() => useTerminateCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({ id: 'coupon-123', name: 'Summer Sale' })
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

    describe('WHEN onAction is triggered and terminate succeeds', () => {
      it('THEN should call terminateCoupon mutation with correct ID', async () => {
        mockTerminateCoupon.mockResolvedValueOnce({})

        const { result } = renderHook(() => useTerminateCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({ id: 'coupon-456', name: 'Winter Deal' })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockTerminateCoupon).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: { input: { id: 'coupon-456' } },
          }),
        )
      })

      it('THEN should return success reason', async () => {
        mockTerminateCoupon.mockResolvedValueOnce({})

        const { result } = renderHook(() => useTerminateCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({ id: 'coupon-456', name: 'Winter Deal' })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        let actionResult: { reason: string } | undefined

        await act(async () => {
          actionResult = await onAction()
        })

        expect(actionResult).toEqual({ reason: 'success' })
      })
    })
  })

  describe('GIVEN multiple coupons are terminated', () => {
    describe('WHEN openDialog is called multiple times', () => {
      it('THEN should use the correct coupon ID for each call', async () => {
        mockTerminateCoupon.mockResolvedValue({})

        const { result } = renderHook(() => useTerminateCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({ id: 'coupon-1', name: 'Coupon A' })
        })
        const onAction1 = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction1()
        })

        act(() => {
          result.current.openDialog({ id: 'coupon-2', name: 'Coupon B' })
        })
        const onAction2 = mockDialogOpen.mock.calls[1][0].onAction

        await act(async () => {
          await onAction2()
        })

        expect(mockTerminateCoupon).toHaveBeenNthCalledWith(
          1,
          expect.objectContaining({
            variables: { input: { id: 'coupon-1' } },
          }),
        )
        expect(mockTerminateCoupon).toHaveBeenNthCalledWith(
          2,
          expect.objectContaining({
            variables: { input: { id: 'coupon-2' } },
          }),
        )
      })
    })
  })
})
