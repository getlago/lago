import { render } from '~/test-utils'

import BillableMetricsList from '../BillableMetricsList'

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

jest.mock('~/components/billableMetrics/DeleteBillableMetricDialog', () => ({
  useDeleteBillableMetricDialog: () => ({ openDeleteBillableMetricDialog: jest.fn() }),
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
  useInternationalization: () => ({ translate: (key: string) => key, locale: 'en' }),
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
  useBillableMetricsLazyQuery: () => [
    jest.fn(),
    { data: null, error: null, loading: false, fetchMore: jest.fn(), variables: {} },
  ],
}))

describe('BillableMetricsList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN user has billableMetricsCreate permission', () => {
      it('THEN should pass a create action to MainHeader.Configure', () => {
        mockHasPermissions.mockImplementation((perms: string[]) =>
          perms.includes('billableMetricsCreate'),
        )

        render(<BillableMetricsList />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({
              items: expect.arrayContaining([
                expect.objectContaining({
                  type: 'action',
                  dataTest: 'create-bm',
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

        render(<BillableMetricsList />)

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

      render(<BillableMetricsList />)

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

      render(<BillableMetricsList />)

      expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
        expect.objectContaining({
          filtersSection: expect.anything(),
        }),
      )
    })
  })

  type RowAction = { startIcon: string; title: string }

  const ROW = { id: 'bm-1', name: 'Test BM', code: 'test' }

  const EDIT_TITLE = 'text_6256de3bba111e00b3bfa531'
  const DUPLICATE_TITLE = 'text_64fa170e02f348164797a6af'
  const DELETE_TITLE = 'text_6256de3bba111e00b3bfa533'

  const setPermissions = (perms: string[]) => {
    mockHasPermissions.mockImplementation((requested: string[]) =>
      requested.every((p) => perms.includes(p)),
    )
  }

  const getTableProps = () => mockTableProps.mock.calls[0]?.[0]

  const getActionsFor = (item: Record<string, unknown>): RowAction[] =>
    (getTableProps().actionColumn as (i: Record<string, unknown>) => RowAction[])(item)

  const getTooltipFor = (item: Record<string, unknown>): string =>
    (getTableProps().actionColumnTooltip as (i: Record<string, unknown>) => string)(item)

  describe('GIVEN actionColumn', () => {
    it.each([
      {
        name: 'no permissions',
        permissions: [],
        expectedIcons: [] as string[],
      },
      {
        name: 'only update',
        permissions: ['billableMetricsUpdate'],
        expectedIcons: ['pen'],
      },
      {
        name: 'only create',
        permissions: ['billableMetricsCreate'],
        expectedIcons: ['duplicate'],
      },
      {
        name: 'only delete',
        permissions: ['billableMetricsDelete'],
        expectedIcons: ['trash'],
      },
      {
        name: 'update + create',
        permissions: ['billableMetricsUpdate', 'billableMetricsCreate'],
        expectedIcons: ['pen', 'duplicate'],
      },
      {
        name: 'update + delete',
        permissions: ['billableMetricsUpdate', 'billableMetricsDelete'],
        expectedIcons: ['pen', 'trash'],
      },
      {
        name: 'create + delete',
        permissions: ['billableMetricsCreate', 'billableMetricsDelete'],
        expectedIcons: ['duplicate', 'trash'],
      },
      {
        name: 'all permissions',
        permissions: ['billableMetricsUpdate', 'billableMetricsCreate', 'billableMetricsDelete'],
        expectedIcons: ['pen', 'duplicate', 'trash'],
      },
    ])(
      'WHEN $name THEN returns $expectedIcons.length action(s) in expected order',
      ({ permissions, expectedIcons }) => {
        setPermissions(permissions)

        render(<BillableMetricsList />)

        const actions = getActionsFor(ROW)

        expect(actions).toHaveLength(expectedIcons.length)
        expect(actions.map((a) => a.startIcon)).toEqual(expectedIcons)
      },
    )
  })

  describe('GIVEN actionColumnTooltip', () => {
    it.each([
      { name: 'no permissions', permissions: [] as string[], expected: '' },
      {
        name: 'only update',
        permissions: ['billableMetricsUpdate'],
        expected: EDIT_TITLE,
      },
      {
        name: 'only create',
        permissions: ['billableMetricsCreate'],
        expected: DUPLICATE_TITLE,
      },
      {
        name: 'only delete',
        permissions: ['billableMetricsDelete'],
        expected: DELETE_TITLE,
      },
      {
        name: 'update + create',
        permissions: ['billableMetricsUpdate', 'billableMetricsCreate'],
        expected: `${EDIT_TITLE} or ${DUPLICATE_TITLE}`,
      },
      {
        name: 'update + delete',
        permissions: ['billableMetricsUpdate', 'billableMetricsDelete'],
        expected: `${EDIT_TITLE} or ${DELETE_TITLE}`,
      },
      {
        name: 'create + delete',
        permissions: ['billableMetricsCreate', 'billableMetricsDelete'],
        expected: `${DUPLICATE_TITLE} or ${DELETE_TITLE}`,
      },
      {
        name: 'all permissions (no Oxford comma)',
        permissions: ['billableMetricsUpdate', 'billableMetricsCreate', 'billableMetricsDelete'],
        expected: `${EDIT_TITLE}, ${DUPLICATE_TITLE} or ${DELETE_TITLE}`,
      },
    ])('WHEN $name THEN tooltip is "$expected"', ({ permissions, expected }) => {
      setPermissions(permissions)

      render(<BillableMetricsList />)

      expect(getTooltipFor(ROW)).toBe(expected)
    })
  })
})
