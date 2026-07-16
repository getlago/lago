import { screen } from '@testing-library/react'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { FeatureFlagEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import SubscriptionsPage from '../SubscriptionsPage'

let capturedConfig: MainHeaderConfig | null = null

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: Object.assign(() => null, {
    Configure: (props: MainHeaderConfig) => {
      capturedConfig = props
      return null
    },
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockDebouncedSearch = jest.fn()

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: () => ({
    debouncedSearch: mockDebouncedSearch,
    isLoading: false,
  }),
}))

const mockHasFeatureFlag = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasFeatureFlag: mockHasFeatureFlag,
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetSubscriptionsListLazyQuery: () => [
    jest.fn(),
    {
      data: {
        subscriptions: {
          metadata: { currentPage: 1, totalPages: 1, totalCount: 0 },
          collection: [],
        },
      },
      loading: false,
      error: null,
      fetchMore: jest.fn(),
      variables: {},
    },
  ],
}))

let capturedListProps: Record<string, any> | null = null

jest.mock('~/components/subscriptions/SubscriptionsList', () => ({
  SubscriptionsList: (props: Record<string, any>) => {
    capturedListProps = props
    return <div data-test="subscriptions-list-mock">{props.name}</div>
  },
}))

jest.mock('~/components/designSystem/InfiniteScroll', () => ({
  InfiniteScroll: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
}))

describe('SubscriptionsPage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
    capturedListProps = null
    mockHasFeatureFlag.mockReturnValue(false)
  })

  describe('GIVEN the page is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the SubscriptionsList component', () => {
        render(<SubscriptionsPage />)

        expect(screen.getByTestId('subscriptions-list-mock')).toBeInTheDocument()
      })

      it('THEN should configure MainHeader with entity viewName', () => {
        render(<SubscriptionsPage />)

        expect(capturedConfig?.entity?.viewName).toBe('text_6250304370f0f700a8fdc28d')
      })

      it('THEN should configure MainHeader with a filtersSection', () => {
        render(<SubscriptionsPage />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })

      it('THEN should not configure any actions', () => {
        render(<SubscriptionsPage />)

        expect(capturedConfig?.actions).toBeUndefined()
      })
    })
  })

  describe('GIVEN MultiEntityBilling feature flag is enabled', () => {
    describe('WHEN the page renders', () => {
      it('THEN should include billingEntityId column in SubscriptionsList', () => {
        mockHasFeatureFlag.mockImplementation(
          (flag: FeatureFlagEnum) => flag === FeatureFlagEnum.MultiEntityBilling,
        )

        render(<SubscriptionsPage />)

        const columnKeys = capturedListProps?.columns?.map(
          (col: { key: string }) => col.key,
        ) as string[]

        expect(columnKeys).toContain('billingEntityId')
      })
    })
  })

  describe('GIVEN MultiEntityBilling feature flag is disabled', () => {
    describe('WHEN the page renders', () => {
      it('THEN should not include billingEntityId column in SubscriptionsList', () => {
        mockHasFeatureFlag.mockReturnValue(false)

        render(<SubscriptionsPage />)

        const columnKeys = capturedListProps?.columns?.map(
          (col: { key: string }) => col.key,
        ) as string[]

        expect(columnKeys).not.toContain('billingEntityId')
      })
    })
  })

  describe('GIVEN both feature flags are enabled', () => {
    describe('WHEN the page renders', () => {
      it('THEN should include billingEntityId column in SubscriptionsList', () => {
        mockHasFeatureFlag.mockReturnValue(true)

        render(<SubscriptionsPage />)

        const columnKeys = capturedListProps?.columns?.map(
          (col: { key: string }) => col.key,
        ) as string[]

        expect(columnKeys).toContain('billingEntityId')
      })

      it('THEN should render the SubscriptionsList component', () => {
        mockHasFeatureFlag.mockReturnValue(true)

        render(<SubscriptionsPage />)

        expect(screen.getByTestId('subscriptions-list-mock')).toBeInTheDocument()
      })

      it('THEN should configure MainHeader with a filtersSection', () => {
        mockHasFeatureFlag.mockReturnValue(true)

        render(<SubscriptionsPage />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })
    })
  })

  describe('GIVEN search params are present', () => {
    describe('WHEN the page renders with empty results', () => {
      it('THEN should pass search-specific empty state placeholder to SubscriptionsList', () => {
        render(<SubscriptionsPage />)

        // With empty variables (no search params), hasSearchParams is false
        // so the emptyState title should be the no-search-params variant
        expect(capturedListProps?.placeholder?.emptyState?.title).toBe(
          'text_1751969008731m6hlinilrky',
        )
      })
    })
  })
})
