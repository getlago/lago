import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { CreditNoteReasonEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import CreateCreditNote, { CLOSE_BUTTON_TEST_ID, CREDIT_NOTE_REASONS } from '../CreateCreditNote'

const mockOnCreate = jest.fn()
const mockUseCreateCreditNote = jest.fn()

jest.mock('../common/useCreateCreditNote', () => ({
  useCreateCreditNote: () => mockUseCreateCreditNote(),
}))

const defaultMockInvoice = {
  id: 'invoice-123',
  number: 'INV-001',
  currency: 'USD',
  status: 'finalized',
  paymentStatus: 'succeeded',
  creditableAmountCents: '10000',
  refundableAmountCents: '10000',
  subTotalIncludingTaxesAmountCents: '10000',
  availableToCreditAmountCents: '10000',
  totalPaidAmountCents: '10000',
  totalAmountCents: '10000',
  paymentDisputeLostAt: null,
  invoiceType: 'subscription',
}

const defaultMockFeesPerInvoice = {
  'sub-1': {
    subscriptionName: 'Test Subscription',
    fees: [
      {
        id: 'fee-1',
        checked: true,
        value: 100,
        name: 'Test Fee',
        maxAmount: '10000',
        appliedTaxes: [],
      },
    ],
  },
}

describe('CreateCreditNote', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    // Set up useParams mock (test-utils already mocks react-router-dom)
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      customerId: 'customer-123',
      invoiceId: 'invoice-123',
    })

    // Set up useCreateCreditNote mock with default values
    mockUseCreateCreditNote.mockReturnValue({
      loading: false,
      invoice: defaultMockInvoice,
      feesPerInvoice: defaultMockFeesPerInvoice,
      feeForAddOn: undefined,
      feeForCredit: undefined,
      onCreate: mockOnCreate,
    })
  })

  afterEach(() => {
    cleanup()
  })

  describe('rendering', () => {
    it('renders the page header with invoice number', async () => {
      await act(() => render(<CreateCreditNote />))

      // Header shows "Issue a credit note on INV-001"
      expect(screen.getByText(/Issue a credit note on INV-001/)).toBeInTheDocument()
    })

    it('renders the credit note title', async () => {
      await act(() => render(<CreateCreditNote />))

      // Title is "Issue a credit note"
      expect(screen.getByText('Issue a credit note')).toBeInTheDocument()
    })

    it('renders the reason combobox', async () => {
      await act(() => render(<CreateCreditNote />))

      expect(screen.getByText('Reason')).toBeInTheDocument()
    })

    it('renders the internal note field', async () => {
      await act(() => render(<CreateCreditNote />))

      // Label is "Internal note (optional)" (text_636bedf292786b19d3398ed4)
      expect(screen.getByText('Internal note (optional)')).toBeInTheDocument()
    })

    it('renders the items to credit section', async () => {
      await act(() => render(<CreateCreditNote />))

      // Section title is "Items to credit" (text_636bedf292786b19d3398ed8)
      expect(screen.getByText('Items to credit')).toBeInTheDocument()
    })

    it('renders the metadata form card', async () => {
      await act(() => render(<CreateCreditNote />))

      expect(screen.getByText('Metadata')).toBeInTheDocument()
    })

    it('renders the submit button', async () => {
      await act(() => render(<CreateCreditNote />))

      // Button text is "Issue credit note" (text_636bedf292786b19d3398f12)
      expect(screen.getByText('Issue credit note')).toBeInTheDocument()
    })
  })

  describe('loading state', () => {
    it('does not render form content when loading', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: true,
        invoice: undefined,
        feesPerInvoice: undefined,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        onCreate: mockOnCreate,
      })

      await act(() => render(<CreateCreditNote />))

      // Form elements should not be present when loading
      expect(screen.queryByText('Reason')).not.toBeInTheDocument()
      const submitButton = screen.getByText('Issue credit note')

      expect(submitButton.closest('button')).toBeDisabled()
    })
  })

  describe('form interactions', () => {
    it('disables submit button when form is invalid', async () => {
      await act(() => render(<CreateCreditNote />))

      const submitButton = screen.getByText('Issue credit note')

      expect(submitButton.closest('button')).toBeDisabled()
    })
  })

  describe('close button', () => {
    it('navigates back without warning when form is not dirty', async () => {
      const user = userEvent.setup()

      await act(() => render(<CreateCreditNote />))

      // Find close button by data-test
      const closeButton = screen.getByTestId(CLOSE_BUTTON_TEST_ID)

      await user.click(closeButton)

      // Since form is not dirty, should navigate without warning
      expect(testMockNavigateFn).toHaveBeenCalled()
    })
  })

  describe('CREDIT_NOTE_REASONS constant', () => {
    it('exports all credit note reasons', () => {
      expect(CREDIT_NOTE_REASONS).toHaveLength(6)
      expect(CREDIT_NOTE_REASONS.map((r) => r.reason)).toEqual([
        CreditNoteReasonEnum.DuplicatedCharge,
        CreditNoteReasonEnum.FraudulentCharge,
        CreditNoteReasonEnum.OrderCancellation,
        CreditNoteReasonEnum.OrderChange,
        CreditNoteReasonEnum.Other,
        CreditNoteReasonEnum.ProductUnsatisfactory,
      ])
    })
  })

  describe('snapshots', () => {
    it('matches snapshot in loading state', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: true,
        invoice: undefined,
        feesPerInvoice: undefined,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        onCreate: mockOnCreate,
      })

      const { container } = await act(() => render(<CreateCreditNote />))

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with invoice data', async () => {
      const { container } = await act(() => render(<CreateCreditNote />))

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with no payment (credit only mode)', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          totalPaidAmountCents: '0',
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        onCreate: mockOnCreate,
      })

      const { container } = await act(() => render(<CreateCreditNote />))

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with payment dispute lost', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          paymentDisputeLostAt: '2024-01-15T00:00:00Z',
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        onCreate: mockOnCreate,
      })

      const { container } = await act(() => render(<CreateCreditNote />))

      expect(container).toMatchSnapshot()
    })
  })
})
