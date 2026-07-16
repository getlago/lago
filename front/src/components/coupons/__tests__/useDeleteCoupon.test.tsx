import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { AllTheProviders } from '~/test-utils'

import { useDeleteCoupon } from '../useDeleteCoupon'

const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: mockDialogOpen,
  }),
}))

const mockDeleteCoupon = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useDeleteCouponMutation: () => [mockDeleteCoupon],
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

describe('useDeleteCoupon', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return openDialog function', () => {
        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        expect(result.current.openDialog).toBeDefined()
        expect(typeof result.current.openDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openDialog is called', () => {
    describe('WHEN called with coupon params', () => {
      it('THEN should open the dialog with danger variant', () => {
        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-123',
            couponName: 'Summer Sale',
            appliedCouponsCount: 0,
          })
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
          }),
        )
      })

      it('THEN should pass title, description, and actionText', () => {
        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-123',
            couponName: 'Summer Sale',
            appliedCouponsCount: 0,
          })
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

    describe('WHEN called with appliedCouponsCount > 0', () => {
      it('THEN should open the dialog with a description containing the count', () => {
        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-123',
            couponName: 'Summer Sale',
            appliedCouponsCount: 5,
          })
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
            description: expect.anything(),
          }),
        )
      })
    })

    describe('WHEN called with appliedCouponsCount = 0', () => {
      it('THEN should open the dialog with a default description', () => {
        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-123',
            couponName: 'Summer Sale',
            appliedCouponsCount: 0,
          })
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            description: expect.anything(),
          }),
        )
      })
    })

    describe('WHEN onAction is triggered and delete succeeds', () => {
      it('THEN should call deleteCoupon mutation with correct ID', async () => {
        mockDeleteCoupon.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-456',
            couponName: 'Winter Deal',
            appliedCouponsCount: 0,
          })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockDeleteCoupon).toHaveBeenCalledWith({
          variables: { input: { id: 'coupon-456' } },
        })
      })

      it('THEN should call callback if provided', async () => {
        mockDeleteCoupon.mockResolvedValueOnce({})
        const callback = jest.fn()

        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-456',
            couponName: 'Winter Deal',
            appliedCouponsCount: 0,
            callback,
          })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(callback).toHaveBeenCalled()
      })

      it('THEN should return success reason', async () => {
        mockDeleteCoupon.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-456',
            couponName: 'Winter Deal',
            appliedCouponsCount: 0,
          })
        })

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        let actionResult: { reason: string } | undefined

        await act(async () => {
          actionResult = await onAction()
        })

        expect(actionResult).toEqual({ reason: 'success' })
      })
    })

    describe('WHEN called without callback', () => {
      it('THEN should not throw when delete succeeds', async () => {
        mockDeleteCoupon.mockResolvedValueOnce({})

        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-789',
            couponName: 'No Callback',
            appliedCouponsCount: 0,
          })
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

  describe('GIVEN multiple coupons are deleted', () => {
    describe('WHEN openDialog is called multiple times', () => {
      it('THEN should use the correct coupon ID for each call', async () => {
        mockDeleteCoupon.mockResolvedValue({})

        const { result } = renderHook(() => useDeleteCoupon(), { wrapper })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-1',
            couponName: 'Coupon A',
            appliedCouponsCount: 0,
          })
        })
        const onAction1 = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction1()
        })

        act(() => {
          result.current.openDialog({
            couponId: 'coupon-2',
            couponName: 'Coupon B',
            appliedCouponsCount: 3,
          })
        })
        const onAction2 = mockDialogOpen.mock.calls[1][0].onAction

        await act(async () => {
          await onAction2()
        })

        expect(mockDeleteCoupon).toHaveBeenNthCalledWith(1, {
          variables: { input: { id: 'coupon-1' } },
        })
        expect(mockDeleteCoupon).toHaveBeenNthCalledWith(2, {
          variables: { input: { id: 'coupon-2' } },
        })
      })
    })
  })
})
