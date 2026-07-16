import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  CustomerPaymentsTab,
  PAYMENTS_TAB_CONTAINER,
  PAYMENTS_TAB_CREATE_BUTTON,
} from '../CustomerPaymentsTab'

// --- Mocks ---

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockHasPermissions = jest.fn<boolean, [string[]]>(() => true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

const mockIsPremium = { isPremium: true }

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockIsPremium,
}))

jest.mock('~/hooks/useCustomerFilterDefaults', () => ({
  useCustomerFilterDefaults: () => null,
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useSearchParams: () => [new URLSearchParams(), jest.fn()],
}))

const mockFormatFilters = jest.fn((): { currency: string | undefined } => ({ currency: undefined }))

jest.mock('~/components/designSystem/Filters/utils', () => ({
  formatFiltersForCustomerPaymentsQuery: () => mockFormatFilters(),
}))

let mockPaymentsQueryResult: {
  data: { payments: { collection: unknown[]; metadata: unknown } } | undefined
  loading: boolean
  fetchMore: jest.Mock
}

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetPaymentsListQuery: jest.fn(() => mockPaymentsQueryResult),
}))

// Mock child components
jest.mock('~/components/customers/CustomerPaymentsList', () => ({
  CustomerPaymentsList: ({
    placeholder,
  }: {
    placeholder: { emptyState: { subtitle: string } }
  }) => (
    <div data-test="mock-payments-list" data-subtitle={placeholder?.emptyState?.subtitle}>
      PaymentsList
    </div>
  ),
}))

// --- Helpers ---

const defaultProps = {
  externalCustomerId: 'ext-cust-1',
}

const setupMocks = (overrides?: {
  payments?: unknown[]
  loading?: boolean
  hasPermissions?: boolean
  isPremium?: boolean
  currency?: string
}) => {
  mockPaymentsQueryResult = {
    data: {
      payments: {
        collection: overrides?.payments ?? [],
        metadata: { currentPage: 1, totalCount: 0, totalPages: 1 },
      },
    },
    loading: overrides?.loading ?? false,
    fetchMore: jest.fn(),
  }

  mockHasPermissions.mockImplementation((perms) =>
    overrides?.hasPermissions !== undefined
      ? overrides.hasPermissions
      : perms.includes('paymentsCreate'),
  )

  mockIsPremium.isPremium = overrides?.isPremium ?? true

  if (overrides?.currency) {
    mockFormatFilters.mockReturnValue({ currency: overrides.currency })
  } else {
    mockFormatFilters.mockReturnValue({ currency: undefined })
  }
}

const renderComponent = (overrides = {}) =>
  render(<CustomerPaymentsTab {...defaultProps} {...overrides} />)

// --- Tests ---

describe('CustomerPaymentsTab', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockIsPremium.isPremium = true
  })

  describe('GIVEN the user has paymentsCreate permission AND is premium', () => {
    describe('WHEN the component renders', () => {
      it('THEN should show the "Create payment" button', () => {
        setupMocks({ hasPermissions: true, isPremium: true })

        renderComponent()

        expect(screen.getByTestId(PAYMENTS_TAB_CREATE_BUTTON)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user does NOT have paymentsCreate permission', () => {
    describe('WHEN the component renders', () => {
      it('THEN should NOT show the "Create payment" button', () => {
        setupMocks({ hasPermissions: false, isPremium: true })

        renderComponent()

        expect(screen.queryByTestId(PAYMENTS_TAB_CREATE_BUTTON)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user is not premium', () => {
    describe('WHEN the component renders', () => {
      it('THEN should NOT show the "Create payment" button', () => {
        setupMocks({ hasPermissions: true, isPremium: false })

        renderComponent()

        expect(screen.queryByTestId(PAYMENTS_TAB_CREATE_BUTTON)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN permission and premium combinations', () => {
    it.each([
      { hasPermissions: true, isPremium: true, expected: true, label: 'both granted' },
      { hasPermissions: false, isPremium: true, expected: false, label: 'no permission' },
      { hasPermissions: true, isPremium: false, expected: false, label: 'not premium' },
      { hasPermissions: false, isPremium: false, expected: false, label: 'neither' },
    ])(
      'THEN button visibility is correct when $label',
      ({ hasPermissions, isPremium, expected }) => {
        setupMocks({ hasPermissions, isPremium })

        renderComponent()

        if (expected) {
          expect(screen.getByTestId(PAYMENTS_TAB_CREATE_BUTTON)).toBeInTheDocument()
        } else {
          expect(screen.queryByTestId(PAYMENTS_TAB_CREATE_BUTTON)).not.toBeInTheDocument()
        }
      },
    )
  })

  describe('GIVEN a currency filter is active', () => {
    describe('WHEN the payments list is empty', () => {
      it('THEN should pass the filtering-specific empty state subtitle', () => {
        setupMocks({ currency: 'EUR', payments: [] })

        renderComponent()

        const list = screen.getByTestId('mock-payments-list')

        expect(list).toHaveAttribute('data-subtitle', 'text_66ab48ea4ed9cd01084c60b8')
      })
    })
  })

  describe('GIVEN no currency filter is active', () => {
    describe('WHEN the payments list is empty', () => {
      it('THEN should pass the default empty state subtitle', () => {
        setupMocks({ payments: [] })

        renderComponent()

        const list = screen.getByTestId('mock-payments-list')

        expect(list).toHaveAttribute('data-subtitle', 'text_1738056040178gw94jzmzckx')
      })
    })
  })

  describe('GIVEN both feature flags are enabled', () => {
    describe('WHEN the user has permission and is premium', () => {
      it('THEN should render the container with the create button', () => {
        setupMocks({ hasPermissions: true, isPremium: true })

        renderComponent()

        expect(screen.getByTestId(PAYMENTS_TAB_CONTAINER)).toBeInTheDocument()
        expect(screen.getByTestId(PAYMENTS_TAB_CREATE_BUTTON)).toBeInTheDocument()
      })
    })

    describe('WHEN a currency filter is active', () => {
      it('THEN should pass the filtering-specific empty state subtitle', () => {
        setupMocks({ hasPermissions: true, isPremium: true, currency: 'USD' })

        renderComponent()

        const list = screen.getByTestId('mock-payments-list')

        expect(list).toHaveAttribute('data-subtitle', 'text_66ab48ea4ed9cd01084c60b8')
      })
    })
  })

  describe('GIVEN the component renders', () => {
    describe('WHEN mounted', () => {
      it('THEN should render the container', () => {
        setupMocks()

        renderComponent()

        expect(screen.getByTestId(PAYMENTS_TAB_CONTAINER)).toBeInTheDocument()
      })
    })
  })
})
