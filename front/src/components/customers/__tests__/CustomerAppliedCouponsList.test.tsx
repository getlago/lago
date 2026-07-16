import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  AppliedCouponStatusEnum,
  CouponFrequency,
  CurrencyEnum,
  GetAppliedCouponsForCustomerDocument,
} from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import { CustomerAppliedCouponsList } from '../CustomerAppliedCouponsList'

// Mock IntersectionObserver for InfiniteScroll component
const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: () => null,
  unobserve: () => null,
  disconnect: () => null,
})
window.IntersectionObserver = mockIntersectionObserver

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockHasPermissions = jest.fn(() => true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

const mockTerminateCoupon = jest.fn()

jest.mock('~/hooks/useTerminateAppliedCoupon', () => ({
  useTerminateAppliedCoupon: () => ({
    terminateCoupon: mockTerminateCoupon,
  }),
}))

const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: mockDialogOpen,
  }),
}))

jest.mock('~/components/customers/AddCouponToCustomerDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => <div data-testid="add-coupon-dialog" />)

  MockDialog.displayName = 'AddCouponToCustomerDialog'
  return { AddCouponToCustomerDialog: MockDialog }
})

const mockAppliedCoupon = {
  __typename: 'AppliedCoupon' as const,
  id: 'applied-coupon-1',
  status: AppliedCouponStatusEnum.Active,
  createdAt: '2024-01-15T00:00:00Z',
  terminatedAt: null as string | null,
  amountCents: '10000',
  amountCentsRemaining: '10000',
  amountCurrency: CurrencyEnum.Usd,
  percentageRate: null,
  frequency: CouponFrequency.Once,
  frequencyDuration: null,
  frequencyDurationRemaining: null,
  coupon: {
    __typename: 'Coupon' as const,
    id: 'coupon-1',
    name: 'Test Coupon',
    code: 'TEST_COUPON',
  },
}

const createQueryMock = (
  collection = [mockAppliedCoupon],
  metadata = { __typename: 'CollectionMetadata' as const, currentPage: 1, totalPages: 1 },
): TestMocksType => [
  {
    request: {
      query: GetAppliedCouponsForCustomerDocument,
      variables: { externalCustomerId: 'ext-customer-1', page: 0, limit: 20 },
    },
    result: {
      data: {
        appliedCoupons: {
          __typename: 'AppliedCouponCollection' as const,
          metadata,
          collection,
        },
      },
    },
  },
]

const defaultProps = {
  customerId: 'customer-1',
  customerExternalId: 'ext-customer-1',
  customerDisplayName: 'Test Customer',
}

describe('CustomerAppliedCouponsList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the query returns applied coupons', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the coupon name and code in the table', async () => {
        await act(async () => {
          render(<CustomerAppliedCouponsList {...defaultProps} />, {
            mocks: createQueryMock(),
          })
        })

        await waitFor(() => {
          expect(screen.getByText('Test Coupon')).toBeInTheDocument()
        })

        expect(screen.getByText('TEST_COUPON')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user lacks couponsAttach permission', () => {
    beforeEach(() => {
      mockHasPermissions.mockImplementation(
        (permissions?: string[]) => !permissions?.includes('couponsAttach'),
      )
    })

    afterEach(() => {
      mockHasPermissions.mockImplementation(() => true)
    })

    describe('WHEN the component renders', () => {
      it('THEN should not show the add coupon action button', async () => {
        await act(async () => {
          render(<CustomerAppliedCouponsList {...defaultProps} />, {
            mocks: createQueryMock(),
          })
        })

        await waitFor(() => {
          expect(screen.getByText('Test Coupon')).toBeInTheDocument()
        })

        // The action button text is the translation key for "Add a coupon"
        expect(screen.queryByText('text_628b8dc14c71840130f8d8a1')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a terminated coupon', () => {
    describe('WHEN the component renders', () => {
      it('THEN should not show the trash button for the terminated coupon', async () => {
        const terminatedCoupon = {
          ...mockAppliedCoupon,
          id: 'applied-coupon-terminated',
          status: AppliedCouponStatusEnum.Terminated,
          terminatedAt: '2024-02-01T00:00:00Z',
        }

        await act(async () => {
          render(<CustomerAppliedCouponsList {...defaultProps} />, {
            mocks: createQueryMock([terminatedCoupon]),
          })
        })

        await waitFor(() => {
          expect(screen.getByText('Test Coupon')).toBeInTheDocument()
        })

        // No trash button should be rendered for terminated coupons
        expect(screen.queryByRole('button', { name: /trash/i })).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an active coupon with detach permission', () => {
    describe('WHEN the user clicks the trash button', () => {
      it('THEN should open the centralized dialog with danger color variant', async () => {
        await act(async () => {
          render(<CustomerAppliedCouponsList {...defaultProps} />, {
            mocks: createQueryMock(),
          })
        })

        await waitFor(() => {
          expect(screen.getByText('Test Coupon')).toBeInTheDocument()
        })

        // Find the trash button inside the action cell of the first row
        const row = document.getElementById('table-customer-coupons-list-row-0')
        const actionCell = row?.querySelector('.lago-table-action-cell')
        const trashButton = actionCell?.querySelector('button') as HTMLButtonElement

        expect(trashButton).toBeTruthy()

        await act(async () => {
          await userEvent.click(trashButton)
        })

        expect(mockDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            colorVariant: 'danger',
          }),
        )
      })
    })
  })

  describe('GIVEN the dialog onAction is triggered', () => {
    describe('WHEN the user confirms the termination', () => {
      it('THEN should call terminateCoupon with the applied coupon id', async () => {
        await act(async () => {
          render(<CustomerAppliedCouponsList {...defaultProps} />, {
            mocks: createQueryMock(),
          })
        })

        await waitFor(() => {
          expect(screen.getByText('Test Coupon')).toBeInTheDocument()
        })

        // Find the trash button inside the action cell of the first row
        const row = document.getElementById('table-customer-coupons-list-row-0')
        const actionCell = row?.querySelector('.lago-table-action-cell')
        const trashButton = actionCell?.querySelector('button') as HTMLButtonElement

        expect(trashButton).toBeTruthy()

        await act(async () => {
          await userEvent.click(trashButton)
        })

        // Extract the onAction callback from the dialog open call
        const dialogCall = mockDialogOpen.mock.calls[0][0]

        await act(async () => {
          await dialogCall.onAction()
        })

        expect(mockTerminateCoupon).toHaveBeenCalledWith('applied-coupon-1')
      })
    })
  })
})
