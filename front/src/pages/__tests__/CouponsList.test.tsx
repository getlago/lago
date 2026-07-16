import { CouponStatusEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import CouponsList from '../CouponsList'

const mockMainHeaderConfigure = jest.fn()
const mockTableProps = jest.fn()

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

jest.mock('~/components/designSystem/Table/Table', () => ({
  Table: (props: Record<string, unknown>) => {
    mockTableProps(props)
    return null
  },
}))

jest.mock('~/components/designSystem/InfiniteScroll', () => ({
  InfiniteScroll: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}))

jest.mock('~/components/SearchInput', () => ({
  SearchInput: () => null,
}))

jest.mock('~/components/coupons/useDeleteCoupon', () => ({
  useDeleteCoupon: () => ({ openDialog: jest.fn() }),
}))

jest.mock('~/components/coupons/useTerminateCoupon', () => ({
  useTerminateCoupon: () => ({ openDialog: jest.fn() }),
}))

jest.mock('~/components/coupons/CouponCaption', () => ({
  CouponCaption: () => null,
}))

jest.mock('~/components/designSystem/Status', () => ({
  Status: () => null,
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: jest.fn(() => jest.fn()),
  generatePath: jest.fn((route: string) => route),
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

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: () => ({ date: '2024-01-01' }),
  }),
}))

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: () => ({
    debouncedSearch: jest.fn(),
    isLoading: false,
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useCouponsLazyQuery: () => [
    jest.fn(),
    { data: null, error: null, loading: false, fetchMore: jest.fn(), variables: {} },
  ],
}))

jest.mock('~/core/constants/statusCouponMapping', () => ({
  couponStatusMapping: () => ({ type: 'success', label: 'Active' }),
}))

describe('CouponsList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockCanCreate.mockReturnValue(true)
    mockCanEdit.mockReturnValue(true)
    mockCanTerminate.mockReturnValue(true)
    mockCanDelete.mockReturnValue(true)
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN user has couponsCreate permission', () => {
      it('THEN should pass a visible create action to MainHeader.Configure', () => {
        render(<CouponsList />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({
              items: expect.arrayContaining([
                expect.objectContaining({
                  type: 'action',
                  dataTest: 'add-coupon',
                }),
              ]),
            }),
          }),
        )
      })
    })

    describe('WHEN user has no create permission', () => {
      it('THEN should pass hidden create action to MainHeader.Configure', () => {
        mockCanCreate.mockReturnValue(false)

        render(<CouponsList />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({
              items: expect.arrayContaining([
                expect.objectContaining({
                  hidden: true,
                }),
              ]),
            }),
          }),
        )
      })
    })

    it('THEN should configure entity with view name', () => {
      render(<CouponsList />)

      expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
        expect.objectContaining({
          entity: expect.objectContaining({
            viewName: expect.any(String),
          }),
        }),
      )
    })
  })

  describe('GIVEN user has all row-level permissions', () => {
    describe('WHEN actionColumn is called for an active coupon', () => {
      it('THEN should return edit, terminate, and delete actions', () => {
        render(<CouponsList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => { startIcon: string }[]

        const actions = actionColumn({
          id: 'coupon-1',
          name: 'Test Coupon',
          status: CouponStatusEnum.Active,
        })

        expect(actions).toHaveLength(3)
        expect(actions[0]).toEqual(expect.objectContaining({ startIcon: 'pen' }))
        expect(actions[1]).toEqual(expect.objectContaining({ startIcon: 'switch' }))
        expect(actions[2]).toEqual(expect.objectContaining({ startIcon: 'trash' }))
      })
    })

    describe('WHEN actionColumn is called for a terminated coupon', () => {
      it('THEN should omit the terminate action', () => {
        mockCanTerminate.mockReturnValue(false)

        render(<CouponsList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => { startIcon: string }[]

        const actions = actionColumn({
          id: 'coupon-1',
          name: 'Test Coupon',
          status: CouponStatusEnum.Terminated,
        })

        expect(actions).toHaveLength(2)
        expect(actions[0]).toEqual(expect.objectContaining({ startIcon: 'pen' }))
        expect(actions[1]).toEqual(expect.objectContaining({ startIcon: 'trash' }))
      })
    })
  })

  describe('GIVEN user has no row-level permissions', () => {
    describe('WHEN actionColumn is called for a row item', () => {
      it('THEN should return empty array', () => {
        mockCanEdit.mockReturnValue(false)
        mockCanTerminate.mockReturnValue(false)
        mockCanDelete.mockReturnValue(false)

        render(<CouponsList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => unknown[]

        const actions = actionColumn({
          id: 'coupon-1',
          name: 'Test Coupon',
          status: CouponStatusEnum.Active,
        })

        expect(actions).toEqual([])
      })
    })
  })

  describe('GIVEN user has only couponsUpdate permission', () => {
    describe('WHEN actionColumn is called for an active coupon', () => {
      it('THEN should return edit and terminate actions but not delete', () => {
        mockCanDelete.mockReturnValue(false)

        render(<CouponsList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => { startIcon: string }[]

        const actions = actionColumn({
          id: 'coupon-1',
          name: 'Test Coupon',
          status: CouponStatusEnum.Active,
        })

        expect(actions).toHaveLength(2)
        expect(actions[0]).toEqual(expect.objectContaining({ startIcon: 'pen' }))
        expect(actions[1]).toEqual(expect.objectContaining({ startIcon: 'switch' }))
      })
    })
  })

  describe('GIVEN user has only couponsDelete permission', () => {
    describe('WHEN actionColumn is called', () => {
      it('THEN should return only the delete action', () => {
        mockCanEdit.mockReturnValue(false)
        mockCanTerminate.mockReturnValue(false)

        render(<CouponsList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => { startIcon: string }[]

        const actions = actionColumn({
          id: 'coupon-1',
          name: 'Test Coupon',
          status: CouponStatusEnum.Active,
        })

        expect(actions).toHaveLength(1)
        expect(actions[0]).toEqual(expect.objectContaining({ startIcon: 'trash' }))
      })
    })
  })
})
