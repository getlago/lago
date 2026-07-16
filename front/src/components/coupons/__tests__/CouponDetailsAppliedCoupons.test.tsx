import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'

import {
  AppliedCouponStatusEnum,
  GetAppliedCouponsForCouponDetailsDocument,
} from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { CouponDetailsAppliedCoupons } from '../CouponDetailsAppliedCoupons'

// Mock IntersectionObserver for InfiniteScroll component
const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})
window.IntersectionObserver = mockIntersectionObserver

const mockTerminateCoupon = jest.fn()

jest.mock('~/hooks/useTerminateAppliedCoupon', () => ({
  useTerminateAppliedCoupon: () => ({ terminateCoupon: mockTerminateCoupon }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

let mockHasPermissions = jest.fn(() => true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({ open: mockDialogOpen }),
}))

const mockAppliedCouponActive = {
  __typename: 'AppliedCoupon' as const,
  id: 'applied-coupon-1',
  status: AppliedCouponStatusEnum.Active,
  createdAt: '2024-01-15T00:00:00Z',
  terminatedAt: null as string | null,
  amountCents: '10000',
  amountCentsRemaining: '10000',
  amountCurrency: 'USD',
  percentageRate: null,
  frequency: 'once',
  frequencyDuration: null,
  frequencyDurationRemaining: null,
  coupon: {
    __typename: 'Coupon' as const,
    id: 'coupon-1',
    name: 'Test Coupon',
    code: 'TEST_COUPON',
  },
  customer: {
    __typename: 'Customer' as const,
    id: 'customer-1',
    name: 'John Doe',
    displayName: 'John Doe',
    externalId: 'ext-1',
  },
}

const mockAppliedCouponTerminated = {
  ...mockAppliedCouponActive,
  id: 'applied-coupon-2',
  status: AppliedCouponStatusEnum.Terminated,
  terminatedAt: '2024-02-01T00:00:00Z',
  customer: {
    __typename: 'Customer' as const,
    id: 'customer-2',
    name: 'Jane Smith',
    displayName: 'Jane Smith',
    externalId: 'ext-2',
  },
}

const buildMocks = (collection = [mockAppliedCouponActive]): TestMocksType => [
  {
    request: {
      query: GetAppliedCouponsForCouponDetailsDocument,
      variables: { couponCode: ['TEST_CODE'], limit: 20 },
    },
    result: {
      data: {
        appliedCoupons: {
          __typename: 'AppliedCouponCollection',
          metadata: {
            __typename: 'CollectionMetadata',
            currentPage: 1,
            totalPages: 1,
          },
          collection,
        },
      },
    },
  },
]

const renderComponent = (mocks: TestMocksType = buildMocks()) => {
  return render(<CouponDetailsAppliedCoupons couponCode="TEST_CODE" />, {
    wrapper: ({ children }) =>
      AllTheProviders({
        children,
        mocks,
        forceTypenames: true,
      }),
  })
}

describe('CouponDetailsAppliedCoupons', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions = jest.fn(() => true)
  })

  describe('GIVEN the query returns applied coupons', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the table', async () => {
        renderComponent()

        await waitFor(() => {
          expect(screen.getByTestId('table-coupon-details-applied-coupons')).toBeInTheDocument()
        })
      })

      it('THEN should display customer name', async () => {
        renderComponent()

        await waitFor(() => {
          expect(screen.getByText('John Doe')).toBeInTheDocument()
        })
      })

      it('THEN should display customer external ID', async () => {
        renderComponent()

        await waitFor(() => {
          expect(screen.getByText('ext-1')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the user has couponsDetach permission', () => {
    describe('WHEN the applied coupon is active', () => {
      it('THEN should show the trash button', async () => {
        renderComponent()

        await waitFor(() => {
          expect(screen.getByTestId('button')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN the applied coupon is terminated', () => {
      it('THEN should not show the trash button', async () => {
        renderComponent(buildMocks([mockAppliedCouponTerminated]))

        await waitFor(() => {
          expect(screen.getByText('Jane Smith')).toBeInTheDocument()
        })

        expect(screen.queryByTestId('button')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user lacks couponsDetach permission', () => {
    describe('WHEN the component renders with an active coupon', () => {
      it('THEN should not show the trash button', async () => {
        mockHasPermissions = jest.fn(() => false)

        renderComponent()

        await waitFor(() => {
          expect(screen.getByText('John Doe')).toBeInTheDocument()
        })

        expect(screen.queryByTestId('button')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user clicks the trash button', () => {
    describe('WHEN the dialog opens', () => {
      it('THEN should call centralizedDialog.open with danger colorVariant', async () => {
        renderComponent()

        await waitFor(() => {
          expect(screen.getByTestId('button')).toBeInTheDocument()
        })

        fireEvent.click(screen.getByTestId('button'))

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
          }),
        )
      })
    })

    describe('WHEN the dialog onAction is triggered', () => {
      it('THEN should call terminateCoupon with the applied coupon id', async () => {
        mockTerminateCoupon.mockResolvedValueOnce(undefined)

        renderComponent()

        await waitFor(() => {
          expect(screen.getByTestId('button')).toBeInTheDocument()
        })

        fireEvent.click(screen.getByTestId('button'))

        const onAction = mockDialogOpen.mock.calls[0][0].onAction

        await act(async () => {
          await onAction()
        })

        expect(mockTerminateCoupon).toHaveBeenCalledWith('applied-coupon-1')
      })
    })
  })
})
