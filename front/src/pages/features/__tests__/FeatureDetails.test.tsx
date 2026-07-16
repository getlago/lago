import { render } from '~/test-utils'

import FeatureDetails from '../FeatureDetails'

const mockMainHeaderConfigure = jest.fn()
const mockHasPermissions = jest.fn()
const mockIsPremium = jest.fn()
const mockUseGetFeatureForDetailsQuery = jest.fn()

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

jest.mock('~/components/features/FeatureDetailsOverview', () => ({
  FeatureDetailsOverview: () => null,
}))

jest.mock('~/components/features/FeatureDetailsActivityLogs', () => ({
  FeatureDetailsActivityLogs: () => null,
}))

jest.mock('~/components/features/DeleteFeatureDialog', () => ({
  useDeleteFeatureDialog: () => ({ openDeleteFeatureDialog: jest.fn() }),
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

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetFeatureForDetailsQuery: (options: Record<string, unknown>) =>
    mockUseGetFeatureForDetailsQuery(options),
}))

interface MainHeaderDropdownAction {
  type: string
  items: { hidden?: boolean; label: string }[]
}

interface MainHeaderTabConfig {
  title: string
  hidden?: boolean
}

describe('FeatureDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ featureId: 'feat-123' })
    mockIsPremium.mockReturnValue(true)
    mockUseGetFeatureForDetailsQuery.mockReturnValue({
      data: {
        feature: {
          id: 'feat-123',
          name: 'Test Feature',
          code: 'test-feature',
        },
      },
      loading: false,
    })
  })

  describe('GIVEN the component is rendered with data', () => {
    describe('WHEN the feature is loaded', () => {
      it('THEN should configure MainHeader with breadcrumb', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<FeatureDetails />)

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

        render(<FeatureDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            entity: expect.objectContaining({
              viewName: 'Test Feature',
              metadata: 'test-feature',
            }),
          }),
        )
      })

      it('THEN should pass loading false to MainHeader.Configure', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<FeatureDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({ loading: false }),
          }),
        )
      })

      it('THEN should configure tabs', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<FeatureDetails />)

        const tabs = mockMainHeaderConfigure.mock.calls[0]?.[0]?.tabs as MainHeaderTabConfig[]

        expect(tabs.length).toBeGreaterThanOrEqual(1)
      })
    })
  })

  describe('GIVEN user has all permissions and feature is loaded', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should include dropdown with edit and delete items', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<FeatureDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]

        expect(actions).toHaveLength(1)
        expect(actions[0]?.type).toBe('dropdown')

        const visibleItems = actions[0]?.items.filter((i) => !i.hidden)

        expect(visibleItems).toHaveLength(2)
      })
    })
  })

  describe('GIVEN feature is not yet loaded', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should return empty actions array', () => {
        mockUseGetFeatureForDetailsQuery.mockReturnValue({
          data: null,
          loading: true,
        })
        mockHasPermissions.mockReturnValue(true)

        render(<FeatureDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]

        expect(actions).toEqual([])
      })
    })
  })

  describe('GIVEN user has no featuresUpdate permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the edit action', () => {
        mockHasPermissions.mockImplementation(
          (perms: string[]) => !perms.includes('featuresUpdate'),
        )

        render(<FeatureDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]

        expect(actions).toHaveLength(1)
        expect(actions[0]?.items[0]?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN user has no featuresDelete permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the delete action', () => {
        mockHasPermissions.mockImplementation(
          (perms: string[]) => !perms.includes('featuresDelete'),
        )

        render(<FeatureDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]

        expect(actions).toHaveLength(1)
        expect(actions[0]?.items[1]?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN user is not premium', () => {
    describe('WHEN tabs are configured', () => {
      it('THEN should hide the activity logs tab', () => {
        mockIsPremium.mockReturnValue(false)
        mockHasPermissions.mockReturnValue(true)

        render(<FeatureDetails />)

        const tabs = mockMainHeaderConfigure.mock.calls[0]?.[0]?.tabs as MainHeaderTabConfig[]
        const activityLogsTab = tabs.find((t) => t.hidden === true)

        expect(activityLogsTab).toBeDefined()
      })
    })
  })
})
