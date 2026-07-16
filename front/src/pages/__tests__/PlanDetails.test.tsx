import { MainHeaderTab } from '~/components/MainHeader/types'
import { render, testMockNavigateFn } from '~/test-utils'

import PlanDetails from '../PlanDetails'

const mockMainHeaderConfigure = jest.fn()
const mockHasPermissions = jest.fn()
const mockIsPremium = jest.fn()
const mockUseGetPlanForDetailsQuery = jest.fn()

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

jest.mock('~/components/plans/details-v2/PlanDetailsV2', () => ({
  PlanDetailsV2: () => null,
}))

jest.mock('~/components/plans/details/PlanDetailsActivityLogs', () => ({
  PlanDetailsActivityLogs: () => null,
}))

jest.mock('~/components/plans/details/PlanSubscriptionList', () => ({
  __esModule: true,
  default: () => null,
}))

jest.mock('~/components/plans/DeletePlanDialog', () => ({
  useDeletePlanDialog: () => ({ openDeletePlanDialog: jest.fn() }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: mockIsPremium() }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  updateDuplicatePlanVar: jest.fn(),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetPlanForDetailsQuery: (options: Record<string, unknown>) =>
    mockUseGetPlanForDetailsQuery(options),
}))

interface MainHeaderDropdownAction {
  type: string
  items: { hidden?: boolean; label: string }[]
}

describe('PlanDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ planId: 'plan-123' })
    mockIsPremium.mockReturnValue(true)
    mockUseGetPlanForDetailsQuery.mockReturnValue({
      data: {
        plan: {
          id: 'plan-123',
          name: 'Test Plan',
          code: 'test-plan',
          parent: null,
        },
      },
      loading: false,
    })
  })

  describe('GIVEN the component is rendered with data', () => {
    describe('WHEN the plan is loaded', () => {
      it('THEN should configure MainHeader with breadcrumb', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<PlanDetails />)

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

      it('THEN should configure MainHeader with entity name and code', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<PlanDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            entity: expect.objectContaining({
              viewName: expect.any(String),
              // metadata is a click-to-copy element wrapping the plan code
              metadata: expect.objectContaining({
                props: expect.objectContaining({ children: 'test-plan' }),
              }),
            }),
          }),
        )
      })

      it('THEN should pass loading false to MainHeader.Configure', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<PlanDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({ loading: false }),
          }),
        )
      })

      it('THEN should configure tabs including overview and subscriptions', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<PlanDetails />)

        const tabs = mockMainHeaderConfigure.mock.calls[0]?.[0]?.tabs as MainHeaderTab[]

        expect(tabs.length).toBeGreaterThanOrEqual(2)
      })
    })
  })

  describe('GIVEN user has all permissions', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should include dropdown with duplicate and delete items', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<PlanDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]

        expect(actions).toHaveLength(1)
        expect(actions[0]?.type).toBe('dropdown')

        const visibleItems = actions[0]?.items.filter((i) => !i.hidden)

        expect(visibleItems).toHaveLength(2)
      })
    })
  })

  describe('GIVEN user has no plansCreate permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the duplicate action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('plansCreate'))

        render(<PlanDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const duplicateItem = actions[0]?.items[0]

        expect(duplicateItem?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN user has no plansDelete permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the delete action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('plansDelete'))

        render(<PlanDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const deleteItem = actions[0]?.items[1]

        expect(deleteItem?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN the plan has a parent (overridden plan)', () => {
    describe('WHEN the component renders', () => {
      it('THEN should redirect to plans list', () => {
        mockUseGetPlanForDetailsQuery.mockReturnValue({
          data: {
            plan: {
              id: 'plan-123',
              name: 'Overridden Plan',
              code: 'override',
              parent: { id: 'parent-plan-123' },
            },
          },
          loading: false,
        })
        mockHasPermissions.mockReturnValue(true)

        render(<PlanDetails />)

        expect(testMockNavigateFn).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the v2 overview tab', () => {
    describe('WHEN the component renders', () => {
      it('THEN should always serve the v2 overview at /overview', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<PlanDetails />)

        const tabs = mockMainHeaderConfigure.mock.calls[0]?.[0]?.tabs as MainHeaderTab[]
        const overviewTab = tabs.find((t) => t.title === 'text_628cf761cbe6820138b8f2e4')

        expect(overviewTab).toBeDefined()
        expect(overviewTab?.hidden).toBeFalsy()
        expect(overviewTab?.link).toContain('/overview')
      })
    })
  })
})
