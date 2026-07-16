import { CouponStatusEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import CouponDetails from '../CouponDetails'

const mockMainHeaderConfigure = jest.fn()
const mockHasPermissions = jest.fn()
const mockIsPremium = jest.fn()
const mockUseGetCouponForDetailsQuery = jest.fn()

const mockCanCreate = jest.fn()
const mockCanEdit = jest.fn()
const mockCanTerminate = jest.fn()
const mockCanDelete = jest.fn()

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: {
    Configure: (props: Record<string, unknown>) => {
      mockMainHeaderConfigure(props)
      return null
    },
  },
}))

jest.mock('~/components/MainHeader/useMainHeaderTabContent', () => ({
  useMainHeaderTabContent: () => null,
}))

jest.mock('~/components/layouts/DetailsPage', () => ({
  DetailsPage: {
    Container: ({ children }: { children: React.ReactNode }) => <>{children}</>,
  },
}))

jest.mock('~/components/coupons/CouponDetailsOverview', () => ({
  CouponDetailsOverview: () => null,
}))

jest.mock('~/components/coupons/CouponDetailsActivityLogs', () => ({
  CouponDetailsActivityLogs: () => null,
}))

jest.mock('~/components/coupons/useDeleteCoupon', () => ({
  useDeleteCoupon: () => ({ openDialog: jest.fn() }),
}))

jest.mock('~/components/coupons/useTerminateCoupon', () => ({
  useTerminateCoupon: () => ({ openDialog: jest.fn() }),
}))

jest.mock('~/components/coupons/utils', () => ({
  formatCouponValue: () => '$10.00',
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/usePermissionsCouponActions', () => ({
  usePermissionsCouponActions: () => ({
    canCreate: mockCanCreate,
    canEdit: mockCanEdit,
    canTerminate: mockCanTerminate,
    canDelete: mockCanDelete,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: mockIsPremium() }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCouponForDetailsQuery: (options: Record<string, unknown>) =>
    mockUseGetCouponForDetailsQuery(options),
}))

interface MainHeaderDropdownAction {
  type: string
  items: { hidden?: boolean; disabled?: boolean; label: string }[]
}

interface MainHeaderTabConfig {
  title: string
  hidden?: boolean
}

describe('CouponDetails', () => {
  const mockActiveCoupon = {
    id: 'coupon-123',
    name: 'Test Coupon',
    status: CouponStatusEnum.Active,
    couponType: 'fixed_amount',
    percentageRate: null,
    amountCents: 1000,
    amountCurrency: 'USD',
    frequency: 'once',
  }

  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ couponId: 'coupon-123' })
    mockIsPremium.mockReturnValue(true)
    mockHasPermissions.mockReturnValue(true)
    mockCanCreate.mockReturnValue(true)
    mockCanEdit.mockReturnValue(true)
    mockCanTerminate.mockReturnValue(true)
    mockCanDelete.mockReturnValue(true)
    mockUseGetCouponForDetailsQuery.mockReturnValue({
      data: { coupon: mockActiveCoupon },
      loading: false,
    })
  })

  describe('GIVEN the component is rendered with data', () => {
    describe('WHEN the coupon is loaded', () => {
      it('THEN should configure MainHeader with breadcrumb', () => {
        render(<CouponDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            breadcrumb: expect.arrayContaining([
              expect.objectContaining({
                label: expect.any(String),
                path: expect.any(String),
              }),
            ]),
          }),
        )
      })

      it('THEN should configure MainHeader with entity name and metadata', () => {
        render(<CouponDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            entity: expect.objectContaining({
              viewName: 'Test Coupon',
              metadata: expect.any(String),
            }),
          }),
        )
      })

      it('THEN should pass loading false to MainHeader.Configure', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<CouponDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({ loading: false }),
          }),
        )
      })

      it('THEN should configure tabs', () => {
        render(<CouponDetails />)

        const tabs = mockMainHeaderConfigure.mock.calls[0]?.[0]?.tabs as MainHeaderTabConfig[]

        expect(tabs.length).toBeGreaterThanOrEqual(1)
      })
    })
  })

  describe('GIVEN user has all permissions and coupon is active', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should include dropdown with edit, terminate, and delete items all visible', () => {
        render(<CouponDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]

        expect(actions).toHaveLength(1)
        expect(actions[0]?.type).toBe('dropdown')

        const visibleItems = actions[0]?.items.filter((i) => !i.hidden)

        expect(visibleItems).toHaveLength(3)
      })

      it('THEN should not have disabled edit and terminate actions', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<CouponDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const editItem = actions[0]?.items[0]
        const terminateItem = actions[0]?.items[1]

        expect(editItem?.disabled).toBeFalsy()
        expect(terminateItem?.disabled).toBeFalsy()
      })
    })
  })

  describe('GIVEN the coupon is terminated', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the terminate action but keep edit visible', () => {
        mockCanTerminate.mockReturnValue(false)
        mockUseGetCouponForDetailsQuery.mockReturnValue({
          data: {
            coupon: { ...mockActiveCoupon, status: CouponStatusEnum.Terminated },
          },
          loading: false,
        })

        render(<CouponDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const editItem = actions[0]?.items[0]
        const terminateItem = actions[0]?.items[1]
        const deleteItem = actions[0]?.items[2]

        expect(editItem?.hidden).toBe(false)
        expect(terminateItem?.hidden).toBe(true)
        expect(deleteItem?.hidden).toBe(false)
      })
    })
  })

  describe('GIVEN user has no couponsUpdate permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the edit and terminate actions', () => {
        mockCanEdit.mockReturnValue(false)
        mockCanTerminate.mockReturnValue(false)

        render(<CouponDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const editItem = actions[0]?.items[0]
        const terminateItem = actions[0]?.items[1]

        expect(editItem?.hidden).toBe(true)
        expect(terminateItem?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN user has no couponsDelete permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the delete action', () => {
        mockCanDelete.mockReturnValue(false)

        render(<CouponDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const deleteItem = actions[0]?.items[2]

        expect(deleteItem?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN user is not premium', () => {
    describe('WHEN tabs are configured', () => {
      it('THEN should hide the activity logs tab', () => {
        mockIsPremium.mockReturnValue(false)

        render(<CouponDetails />)

        const tabs = mockMainHeaderConfigure.mock.calls[0]?.[0]?.tabs as MainHeaderTabConfig[]
        const activityLogsTab = tabs.find((t) => t.hidden === true)

        expect(activityLogsTab).toBeDefined()
      })
    })
  })

  describe('GIVEN user does not have auditLogsView permission', () => {
    describe('WHEN tabs are configured', () => {
      it('THEN should hide the activity logs tab', () => {
        mockHasPermissions.mockReturnValue(false)

        render(<CouponDetails />)

        const tabs = mockMainHeaderConfigure.mock.calls[0]?.[0]?.tabs as MainHeaderTabConfig[]
        const activityLogsTab = tabs.find((t) => t.hidden === true)

        expect(activityLogsTab).toBeDefined()
      })
    })
  })
})
