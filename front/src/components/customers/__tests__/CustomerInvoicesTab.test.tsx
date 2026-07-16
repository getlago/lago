import { screen } from '@testing-library/react'

import { CurrencyEnum, TimezoneEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  CustomerInvoicesTab,
  INVOICES_TAB_CONTAINER,
  INVOICES_TAB_DRAFT_SECTION,
  INVOICES_TAB_FINALIZED_SECTION,
  INVOICES_TAB_SEE_MORE,
} from '../CustomerInvoicesTab'

// --- Mocks ---

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useCustomerFilterDefaults', () => ({
  useCustomerFilterDefaults: () => null,
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useSearchParams: () => [new URLSearchParams(), jest.fn()],
}))

jest.mock('~/components/designSystem/Filters/utils', () => ({
  formatFiltersForCustomerInvoicesQuery: () => ({
    currency: undefined,
    billingEntityId: undefined,
  }),
}))

// Mock child components
jest.mock('~/components/customers/overview/CustomerOverview', () => ({
  CustomerOverview: () => <div data-test="mock-customer-overview">Overview</div>,
}))

jest.mock('~/components/customers/CustomerInvoicesList', () => ({
  CustomerInvoicesList: () => <div data-test="mock-invoices-list">InvoicesList</div>,
}))

jest.mock('~/components/SearchInput', () => ({
  SearchInput: ({ onChange }: { onChange: (v: string) => void }) => (
    <input data-test="mock-search-input" onChange={(e) => onChange(e.target.value)} />
  ),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomerInvoicesQuery: jest.fn(),
}))

const { useGetCustomerInvoicesQuery } = jest.requireMock('~/generated/graphql') as {
  useGetCustomerInvoicesQuery: jest.Mock
}

// --- Helpers ---

const defaultProps = {
  customerId: 'cust-1',
  customerTimezone: TimezoneEnum.TzUtc,
  customerBillingEntity: { id: 'be-1', code: 'code-1', name: 'Entity One' },
  externalId: 'ext-1',
  userCurrency: CurrencyEnum.Eur,
  isPartner: false,
}

/**
 * The component calls `useGetCustomerInvoicesQuery` twice — once for drafts,
 * once for finalized — so we feed two sequential return values.
 */
const setupMocks = (draftTotalCount = 0) => {
  const draftResult = {
    data: {
      customerInvoices: {
        metadata: { totalCount: draftTotalCount },
      },
    },
    loading: false,
    error: null,
  }
  const finalizedResult = {
    data: null,
    loading: false,
    error: null,
    fetchMore: jest.fn(),
  }

  useGetCustomerInvoicesQuery.mockReturnValueOnce(draftResult).mockReturnValueOnce(finalizedResult)
}

const renderComponent = (overrides = {}) =>
  render(<CustomerInvoicesTab {...defaultProps} {...overrides} />)

// --- Tests ---

describe('CustomerInvoicesTab', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the user is not a partner', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the CustomerOverview section', () => {
        setupMocks()

        renderComponent({ isPartner: false })

        expect(screen.getByTestId('mock-customer-overview')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user is a partner', () => {
    describe('WHEN the component renders', () => {
      it('THEN should NOT render the CustomerOverview section', () => {
        setupMocks()

        renderComponent({ isPartner: true })

        expect(screen.queryByTestId('mock-customer-overview')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN draft invoice count exceeds the display limit', () => {
    describe('WHEN there are more than 4 draft invoices', () => {
      it('THEN should show the "See More" button', () => {
        setupMocks(5)

        renderComponent()

        expect(screen.getByTestId(INVOICES_TAB_SEE_MORE)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN draft invoice count is within the display limit', () => {
    describe.each([
      { count: 3, label: '3 drafts' },
      { count: 4, label: '4 drafts (exact limit)' },
    ])('WHEN there are $label', ({ count }) => {
      it('THEN should NOT show the "See More" button', () => {
        setupMocks(count)

        renderComponent()

        expect(screen.queryByTestId(INVOICES_TAB_SEE_MORE)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the customer has no draft invoices and no filter is active', () => {
    describe('WHEN the component renders', () => {
      it('THEN should hide the Draft section entirely', () => {
        setupMocks(0)

        renderComponent()

        expect(screen.queryByTestId(INVOICES_TAB_DRAFT_SECTION)).not.toBeInTheDocument()
      })

      it('THEN should still render the Finalized section', () => {
        setupMocks(0)

        renderComponent()

        expect(screen.getByTestId(INVOICES_TAB_FINALIZED_SECTION)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the customer has at least one draft invoice', () => {
    describe('WHEN the component renders as non-partner', () => {
      it('THEN should render the overview section', () => {
        setupMocks(1)

        renderComponent({ isPartner: false })

        expect(screen.getByTestId('mock-customer-overview')).toBeInTheDocument()
      })

      it('THEN should render both draft and finalized sections', () => {
        setupMocks(1)

        renderComponent({ isPartner: false })

        expect(screen.getByTestId(INVOICES_TAB_DRAFT_SECTION)).toBeInTheDocument()
        expect(screen.getByTestId(INVOICES_TAB_FINALIZED_SECTION)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the tab renders with drafts present', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should render the container', () => {
        setupMocks(1)

        renderComponent()

        expect(screen.getByTestId(INVOICES_TAB_CONTAINER)).toBeInTheDocument()
      })
    })
  })
})
