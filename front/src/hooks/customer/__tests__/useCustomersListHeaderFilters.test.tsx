import { configure, render, screen } from '@testing-library/react'

import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { UseDebouncedSearch } from '~/hooks/useDebouncedSearch'

import { useCustomersListHeaderFilters } from '../useCustomersListHeaderFilters'

configure({ testIdAttribute: 'data-test' })

const mockDebouncedSearch =
  jest.fn() as unknown as ReturnType<UseDebouncedSearch>['debouncedSearch']
const mockHasOrganizationPremiumAddon = jest.fn(() => false)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
  }),
}))

// Mock the Filters component to capture its props
const mockFiltersProvider = jest.fn(({ children }: { children: React.ReactNode }) => (
  <div data-test="filters-provider">{children}</div>
))
const mockQuickFilters = jest.fn(() => <div data-test="quick-filters" />)
const mockFiltersComponent = jest.fn(() => <div data-test="filters-component" />)

jest.mock('~/components/designSystem/Filters', () => ({
  ...jest.requireActual('~/components/designSystem/Filters'),
  Filters: {
    Provider: (props: Record<string, unknown>) => mockFiltersProvider(props as never),
    QuickFilters: () => mockQuickFilters(),
    Component: () => mockFiltersComponent(),
  },
  AvailableFiltersEnum: jest.requireActual('~/components/designSystem/Filters')
    .AvailableFiltersEnum,
  AvailableQuickFilters: jest.requireActual('~/components/designSystem/Filters')
    .AvailableQuickFilters,
  CustomerAvailableFilters: jest.requireActual('~/components/designSystem/Filters')
    .CustomerAvailableFilters,
}))

jest.mock('~/components/SearchInput', () => ({
  SearchInput: (props: { 'data-test'?: string }) => (
    <input data-test={props['data-test'] || 'search-input'} />
  ),
}))

// Wrapper component that renders the hook's output
function TestComponent() {
  const filtersSection = useCustomersListHeaderFilters({ debouncedSearch: mockDebouncedSearch })

  return <div data-test="test-wrapper">{filtersSection}</div>
}

describe('useCustomersListHeaderFilters', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasOrganizationPremiumAddon.mockReturnValue(false)
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN rendered', () => {
      it('THEN should render the filters provider', () => {
        render(<TestComponent />)

        expect(screen.getByTestId('filters-provider')).toBeInTheDocument()
      })

      it('THEN should render the search input', () => {
        render(<TestComponent />)

        expect(screen.getByTestId('search-customers')).toBeInTheDocument()
      })

      it('THEN should render quick filters', () => {
        render(<TestComponent />)

        expect(screen.getByTestId('quick-filters')).toBeInTheDocument()
      })

      it('THEN should render the filters component', () => {
        render(<TestComponent />)

        expect(screen.getByTestId('filters-component')).toBeInTheDocument()
      })
    })

    describe('WHEN organization has revenue share addon', () => {
      it('THEN should pass all customer available filters to the provider', () => {
        mockHasOrganizationPremiumAddon.mockImplementation(
          ((type: PremiumIntegrationTypeEnum) =>
            type === PremiumIntegrationTypeEnum.RevenueShare) as unknown as () => boolean,
        )

        render(<TestComponent />)

        expect(mockHasOrganizationPremiumAddon).toHaveBeenCalledWith(
          PremiumIntegrationTypeEnum.RevenueShare,
        )
        expect(mockFiltersProvider).toHaveBeenCalledWith(
          expect.objectContaining({
            availableFilters: expect.any(Array),
          }),
        )
      })
    })

    describe('WHEN organization does not have revenue share addon', () => {
      it('THEN should filter out the customerAccountType filter', () => {
        mockHasOrganizationPremiumAddon.mockReturnValue(false)

        render(<TestComponent />)

        const providerCall = mockFiltersProvider.mock.calls[0] as unknown as [
          { availableFilters: string[] },
        ]

        expect(providerCall[0].availableFilters).not.toContain('customerAccountType')
      })
    })
  })
})
