import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { GENERIC_PLACEHOLDER_TEST_ID } from '~/components/designSystem/GenericPlaceholder'
import { CurrencyEnum, FeatureFlagEnum, TimezoneEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { CustomerCreditNotesList } from '../CustomerCreditNotesList'

// --- Mocks ---

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockHasFeatureFlag = jest.fn<boolean, [FeatureFlagEnum]>(() => false)

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasFeatureFlag: mockHasFeatureFlag,
  }),
}))

jest.mock('~/hooks/useCustomerFilterDefaults', () => ({
  useCustomerFilterDefaults: () => null,
}))

const mockGetCreditNotes = jest.fn()
let mockQueryResult: {
  data: unknown
  loading: boolean
  error: unknown
  fetchMore: jest.Mock
  variables: Record<string, unknown>
} = {
  data: null,
  loading: false,
  error: null,
  fetchMore: jest.fn(),
  variables: {},
}

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomerCreditNotesLazyQuery: jest.fn(() => [mockGetCreditNotes, mockQueryResult]),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useSearchParams: () => [new URLSearchParams(), jest.fn()],
}))

jest.mock('~/components/designSystem/Filters/utils', () => ({
  formatFiltersForCustomerCreditNotesQuery: () => ({
    currency: undefined,
    billingEntityId: undefined,
  }),
}))

// Mock child components to isolate unit tests
jest.mock('~/components/customers/CustomerCreditNotesBreakdown', () => ({
  CustomerCreditNotesBreakdown: () => <div data-test="mock-credit-notes-breakdown">Breakdown</div>,
}))

jest.mock('~/components/customers/CustomerCreditNotesLegacyCard', () => ({
  CustomerCreditNotesLegacyCard: () => (
    <div data-test="mock-credit-notes-legacy-card">LegacyCard</div>
  ),
}))

jest.mock('~/components/creditNote/CreditNotesTable', () => ({
  __esModule: true,
  default: () => <div data-test="mock-credit-notes-table">Table</div>,
}))

jest.mock('~/components/SearchInput', () => ({
  SearchInput: ({ onChange }: { onChange: (v: string) => void }) => (
    <input data-test="mock-search-input" onChange={(e) => onChange(e.target.value)} />
  ),
}))

jest.mock('~/public/images/maneki/error.svg', () => {
  const ErrorSvg = () => <svg data-test="error-svg" />

  ErrorSvg.displayName = 'ErrorSvg'

  return ErrorSvg
})

// --- Helpers ---

const defaultProps = {
  customerId: 'cust-1',
  customerBillingEntity: { id: 'be-1', code: 'code-1', name: 'Entity One' },
  creditNotesBalances: [],
  userCurrency: CurrencyEnum.Eur,
  customerTimezone: TimezoneEnum.TzUtc,
}

const renderComponent = (overrides = {}) =>
  render(<CustomerCreditNotesList {...defaultProps} {...overrides} />)

// --- Tests ---

describe('CustomerCreditNotesList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockQueryResult = {
      data: null,
      loading: false,
      error: null,
      fetchMore: jest.fn(),
      variables: {},
    }
  })

  describe('GIVEN the multi_currency feature flag is enabled', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render CustomerCreditNotesBreakdown', () => {
        mockHasFeatureFlag.mockImplementation((flag) => flag === FeatureFlagEnum.MultiCurrency)

        renderComponent()

        expect(screen.getByTestId('mock-credit-notes-breakdown')).toBeInTheDocument()
        expect(screen.queryByTestId('mock-credit-notes-legacy-card')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the multi_entity_billing feature flag is enabled', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render CustomerCreditNotesBreakdown', () => {
        mockHasFeatureFlag.mockImplementation((flag) => flag === FeatureFlagEnum.MultiEntityBilling)

        renderComponent()

        expect(screen.getByTestId('mock-credit-notes-breakdown')).toBeInTheDocument()
        expect(screen.queryByTestId('mock-credit-notes-legacy-card')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN both feature flags are disabled', () => {
    describe('WHEN the component renders', () => {
      it('THEN should fall back to CustomerCreditNotesLegacyCard', () => {
        mockHasFeatureFlag.mockReturnValue(false)

        renderComponent()

        expect(screen.getByTestId('mock-credit-notes-legacy-card')).toBeInTheDocument()
        expect(screen.queryByTestId('mock-credit-notes-breakdown')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the query returns an error', () => {
    describe('WHEN the component renders', () => {
      it('THEN should show the error placeholder', () => {
        mockQueryResult = {
          ...mockQueryResult,
          error: new Error('Network error'),
          loading: false,
        }
        mockHasFeatureFlag.mockReturnValue(false)

        renderComponent()

        expect(screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId('mock-credit-notes-table')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the query is loading', () => {
    describe('WHEN there is also an error', () => {
      it('THEN should NOT show the error placeholder (loading takes precedence)', () => {
        mockQueryResult = {
          ...mockQueryResult,
          error: new Error('Network error'),
          loading: true,
        }
        mockHasFeatureFlag.mockReturnValue(false)

        renderComponent()

        expect(screen.queryByTestId(GENERIC_PLACEHOLDER_TEST_ID)).not.toBeInTheDocument()
        expect(screen.getByTestId('mock-credit-notes-table')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the search input', () => {
    describe('WHEN the user types a search term', () => {
      it('THEN should trigger the lazy query with the debounced search term', async () => {
        jest.useFakeTimers()
        mockHasFeatureFlag.mockReturnValue(false)

        renderComponent()

        const searchInput = screen.getByTestId('mock-search-input') as HTMLInputElement

        await userEvent
          .setup({ advanceTimers: jest.advanceTimersByTime })
          .type(searchInput, 'test-search')

        // Advance past the debounce delay
        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(mockGetCreditNotes).toHaveBeenCalled()
        })

        jest.useRealTimers()
      })
    })
  })

  describe('GIVEN both multi_currency and multi_entity_billing flags are enabled', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render CustomerCreditNotesBreakdown (not legacy card)', () => {
        mockHasFeatureFlag.mockReturnValue(true)

        renderComponent()

        expect(screen.getByTestId('mock-credit-notes-breakdown')).toBeInTheDocument()
        expect(screen.queryByTestId('mock-credit-notes-legacy-card')).not.toBeInTheDocument()
      })

      it('THEN should call the lazy query on mount', () => {
        mockHasFeatureFlag.mockReturnValue(true)

        renderComponent()

        expect(mockGetCreditNotes).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN feature flags are checked', () => {
    describe('WHEN both multi_currency and multi_entity_billing are enabled', () => {
      it.each([
        { flag: FeatureFlagEnum.MultiCurrency, label: 'multi_currency' },
        { flag: FeatureFlagEnum.MultiEntityBilling, label: 'multi_entity_billing' },
      ])('THEN should render breakdown when $label is enabled alone', ({ flag }) => {
        mockHasFeatureFlag.mockImplementation((f) => f === flag)

        renderComponent()

        expect(screen.getByTestId('mock-credit-notes-breakdown')).toBeInTheDocument()
      })
    })
  })
})
