import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { addToast } from '~/core/apolloClient'
import { AllTheProviders } from '~/test-utils'

import { useTerminateAppliedCoupon } from '../useTerminateAppliedCoupon'

const mockTerminateAppliedCoupon = jest.fn()
let capturedOnCompleted: ((data: Record<string, unknown>) => void) | undefined

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useRemoveCouponMutation: (options: { onCompleted: (data: Record<string, unknown>) => void }) => {
    capturedOnCompleted = options.onCompleted

    return [mockTerminateAppliedCoupon]
  },
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

describe('useTerminateAppliedCoupon', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnCompleted = undefined
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return terminateCoupon function', () => {
        const { result } = renderHook(() => useTerminateAppliedCoupon(), { wrapper })

        expect(result.current.terminateCoupon).toBeDefined()
        expect(typeof result.current.terminateCoupon).toBe('function')
      })
    })
  })

  describe('GIVEN terminateCoupon is called', () => {
    describe('WHEN called with an appliedCouponId', () => {
      it('THEN should call the mutation with correct variables', async () => {
        mockTerminateAppliedCoupon.mockResolvedValueOnce({})

        const { result } = renderHook(() => useTerminateAppliedCoupon(), { wrapper })

        await act(async () => {
          await result.current.terminateCoupon('applied-coupon-123')
        })

        expect(mockTerminateAppliedCoupon).toHaveBeenCalledWith({
          variables: { input: { id: 'applied-coupon-123' } },
        })
      })
    })

    describe('WHEN the mutation completes with a truthy result', () => {
      it('THEN should call addToast with success severity', () => {
        renderHook(() => useTerminateAppliedCoupon(), { wrapper })

        act(() => {
          capturedOnCompleted?.({ terminateAppliedCoupon: { id: 'applied-coupon-456' } })
        })

        expect(addToast).toHaveBeenCalledWith(
          expect.objectContaining({
            severity: 'success',
            message: expect.any(String),
          }),
        )
      })
    })

    describe('WHEN the mutation completes with a falsy result', () => {
      it('THEN should not call addToast', () => {
        renderHook(() => useTerminateAppliedCoupon(), { wrapper })

        act(() => {
          capturedOnCompleted?.({ terminateAppliedCoupon: null })
        })

        expect(addToast).not.toHaveBeenCalled()
      })
    })
  })
})
