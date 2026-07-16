import { render } from '~/test-utils'

import PlansList from '../PlansList'

const mockMainHeaderConfigure = jest.fn()
const mockTableProps = jest.fn()
const mockHasPermissions = jest.fn()

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

jest.mock('~/components/plans/DeletePlanDialog', () => ({
  useDeletePlanDialog: () => ({ openDeletePlanDialog: jest.fn() }),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: jest.fn(() => jest.fn()),
  generatePath: jest.fn((route: string) => route),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
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

jest.mock('~/core/apolloClient/reactiveVars/duplicatePlanVar', () => ({
  updateDuplicatePlanVar: jest.fn(),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  usePlansLazyQuery: () => [
    jest.fn(),
    { data: null, error: null, loading: false, fetchMore: jest.fn(), variables: {} },
  ],
}))

describe('PlansList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN user has plansCreate permission', () => {
      it('THEN should pass a create action to MainHeader.Configure', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => perms.includes('plansCreate'))

        render(<PlansList />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({
              items: expect.arrayContaining([
                expect.objectContaining({
                  type: 'action',
                  dataTest: 'create-plan',
                }),
              ]),
            }),
          }),
        )
      })
    })

    describe('WHEN user has no create permission', () => {
      it('THEN should pass empty actions to MainHeader.Configure', () => {
        mockHasPermissions.mockReturnValue(false)

        render(<PlansList />)

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
      mockHasPermissions.mockReturnValue(false)

      render(<PlansList />)

      expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
        expect.objectContaining({
          entity: expect.objectContaining({
            viewName: expect.any(String),
          }),
        }),
      )
    })

    it('THEN should pass filtersSection to MainHeader.Configure', () => {
      mockHasPermissions.mockReturnValue(false)

      render(<PlansList />)

      expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
        expect.objectContaining({
          filtersSection: expect.anything(),
        }),
      )
    })
  })

  describe('GIVEN user has all row-level permissions', () => {
    describe('WHEN actionColumn is called for a plan', () => {
      it('THEN should return edit, duplicate, and delete actions', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<PlansList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => { startIcon: string }[]

        const actions = actionColumn({ id: 'plan-1', name: 'Test Plan', code: 'test' })

        expect(actions).toHaveLength(3)
        expect(actions[0]).toEqual(expect.objectContaining({ startIcon: 'pen' }))
        expect(actions[1]).toEqual(expect.objectContaining({ startIcon: 'duplicate' }))
        expect(actions[2]).toEqual(expect.objectContaining({ startIcon: 'trash' }))
      })
    })
  })

  describe('GIVEN user has no row-level permissions', () => {
    describe('WHEN actionColumn is called for a plan', () => {
      it('THEN should return empty array', () => {
        mockHasPermissions.mockReturnValue(false)

        render(<PlansList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => unknown[]

        const actions = actionColumn({ id: 'plan-1', name: 'Test Plan', code: 'test' })

        expect(actions).toEqual([])
      })
    })
  })

  describe('GIVEN user has only plansUpdate permission', () => {
    describe('WHEN actionColumn is called', () => {
      it('THEN should return only the edit action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => perms.includes('plansUpdate'))

        render(<PlansList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => { startIcon: string }[]

        const actions = actionColumn({ id: 'plan-1', name: 'Test Plan', code: 'test' })

        expect(actions).toHaveLength(1)
        expect(actions[0]).toEqual(expect.objectContaining({ startIcon: 'pen' }))
      })
    })
  })

  describe('GIVEN user has only plansCreate permission', () => {
    describe('WHEN actionColumn is called', () => {
      it('THEN should return only the duplicate action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => perms.includes('plansCreate'))

        render(<PlansList />)

        const actionColumn = mockTableProps.mock.calls[0]?.[0]?.actionColumn as (
          item: Record<string, unknown>,
        ) => { startIcon: string }[]

        const actions = actionColumn({ id: 'plan-1', name: 'Test Plan', code: 'test' })

        expect(actions).toHaveLength(1)
        expect(actions[0]).toEqual(expect.objectContaining({ startIcon: 'duplicate' }))
      })
    })
  })
})
