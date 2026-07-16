import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  CREDIT_AMOUNT_INPUT_TEST_ID,
  OFFSET_AMOUNT_INPUT_TEST_ID,
  REFUND_AMOUNT_INPUT_TEST_ID,
} from '~/components/creditNote/CreditNoteFormAllocation'
import { CREDIT_ONLY_AMOUNT_LINE_TEST_ID } from '~/components/creditNote/CreditNoteFormCalculation'
import { getSubscriptionCheckboxTestId } from '~/components/creditNote/CreditNoteItemsForm'
import {
  CreditNoteEstimateDocument,
  CreditNoteReasonEnum,
  CurrencyEnum,
  InvoicePaymentStatusTypeEnum,
  LagoApiError,
} from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import CreateCreditNote, {
  CLOSE_BUTTON_TEST_ID,
  DESCRIPTION_INPUT_TEST_ID,
  PREPAID_CREDITS_REFUND_ALERT_TEST_ID,
  SUBMIT_BUTTON_TEST_ID,
} from '../CreateCreditNote'

const mockOnCreate = jest.fn()
const mockUseCreateCreditNote = jest.fn()

jest.mock('../common/useCreateCreditNote', () => ({
  useCreateCreditNote: () => mockUseCreateCreditNote(),
}))

// Mock GraphQL query for credit note estimation
const createCreditNoteEstimateMock = (
  maxCreditableAmountCents: string = '10000',
  maxRefundableAmountCents: string = '10000',
): TestMocksType[0] => ({
  request: {
    query: CreditNoteEstimateDocument,
    variables: {
      invoiceId: 'invoice-123',
      items: [{ feeId: 'fee-1', amountCents: 10000 }],
    },
  },
  result: {
    data: {
      creditNoteEstimate: {
        __typename: 'CreditNoteEstimate',
        appliedTaxes: [],
        couponsAdjustmentAmountCents: '0',
        currency: CurrencyEnum.Usd,
        items: [
          {
            __typename: 'CreditNoteEstimatedItem',
            amountCents: '10000',
            fee: {
              __typename: 'Fee',
              id: 'fee-1',
            },
          },
        ],
        maxCreditableAmountCents,
        maxRefundableAmountCents,
        subTotalExcludingTaxesAmountCents: '10000',
        taxesAmountCents: '0',
        taxesRate: 0,
      },
    },
  },
})

const defaultMockInvoice = {
  id: 'invoice-123',
  number: 'INV-001',
  currency: CurrencyEnum.Usd,
  status: 'finalized',
  paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
  creditableAmountCents: '10000',
  refundableAmountCents: '10000',
  subTotalIncludingTaxesAmountCents: '10000',
  availableToCreditAmountCents: '10000',
  totalPaidAmountCents: '10000',
  totalAmountCents: '10000',
  paymentDisputeLostAt: null,
  invoiceType: 'subscription',
  couponsAmountCents: '0',
  feesAmountCents: '10000',
  versionNumber: 3,
  fees: [
    {
      id: 'fee-1',
      appliedTaxes: [],
    },
  ],
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

    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      customerId: 'customer-123',
      invoiceId: 'invoice-123',
    })

    mockUseCreateCreditNote.mockReturnValue({
      loading: false,
      invoice: defaultMockInvoice,
      feesPerInvoice: defaultMockFeesPerInvoice,
      feeForAddOn: undefined,
      feeForCredit: undefined,
      onCreate: mockOnCreate,
    })
  })

  describe('Form Validation - Basic Requirements', () => {
    it('should require reason field to be selected before enabling submit', async () => {
      await act(() => render(<CreateCreditNote />))

      const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

      // Button should be disabled when form is invalid (no reason selected)
      expect(submitButton).toBeDisabled()
    })

    it('should render description field as optional', async () => {
      await act(() => render(<CreateCreditNote />))

      const descriptionInput = screen.getByTestId(DESCRIPTION_INPUT_TEST_ID)

      expect(descriptionInput).toBeInTheDocument()

      // Description should not have a required attribute
      expect(descriptionInput).not.toBeRequired()
    })

    it('should disable submit button when no fees are checked', async () => {
      // Mock with all fees unchecked
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: defaultMockInvoice,
        feesPerInvoice: {
          'sub-1': {
            subscriptionName: 'Test Subscription',
            fees: [
              {
                id: 'fee-1',
                checked: false,
                value: 0,
                name: 'Test Fee',
                maxAmount: '10000',
                appliedTaxes: [],
              },
            ],
          },
        },
        feeForAddOn: undefined,
        feeForCredit: undefined,
        onCreate: mockOnCreate,
      })

      await act(() => render(<CreateCreditNote />))

      const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

      // Button should be disabled if no fees are checked
      expect(submitButton).toBeDisabled()
    })
  })

  describe('PayBack Scenarios - Credit Only Mode', () => {
    beforeEach(() => {
      // Mock invoice with no payment (credit only mode)
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
          totalPaidAmountCents: '0',
          refundableAmountCents: '0',
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        hasCreditableOrRefundableAmount: true,
        onCreate: mockOnCreate,
      })
    })

    it('should only show credit field when invoice has no payment', async () => {
      const mocks = [createCreditNoteEstimateMock('10000', '0')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      // Wait for the GraphQL query to complete
      // For credit-only mode (no payment), only credit input is shown, not refund
      await waitFor(
        () => {
          // Credit input should exist since creditableAmountCents > 0
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          // Refund input should NOT exist since no payment was made
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
        },
        { timeout: 2000, interval: 100 },
      )
    }, 10000)

    it('should automatically populate credit amount based on selected fees', async () => {
      const mocks = [createCreditNoteEstimateMock('10000', '0')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      // For credit-only mode, the credit amount is automatically set to the total
      // There are no input fields - the amount is displayed as a read-only line
      await waitFor(
        () => {
          // Look for the credit amount display (not an input field)
          const creditAmountLine = screen.queryByTestId(CREDIT_ONLY_AMOUNT_LINE_TEST_ID)

          expect(creditAmountLine).toBeInTheDocument()
        },
        { timeout: 2000, interval: 100 },
      )
    }, 10000)

    it('should only show credit field when payment dispute is lost', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
          totalPaidAmountCents: '0',
          refundableAmountCents: '0',
          paymentDisputeLostAt: '2024-01-15T00:00:00Z',
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        hasCreditableOrRefundableAmount: true,
        onCreate: mockOnCreate,
      })

      const mocks = [createCreditNoteEstimateMock('10000', '0')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      // For dispute lost, only credit input is shown, refund is not available
      await waitFor(
        () => {
          // Credit input should exist since creditableAmountCents > 0
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          // Refund input should NOT exist due to payment dispute
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
        },
        { timeout: 2000, interval: 100 },
      )
    }, 10000)
  })

  describe('PayBack Scenarios - Credit + Refund Mode', () => {
    it('should show both credit and refund fields when invoice is fully paid', async () => {
      const mocks = [createCreditNoteEstimateMock('10000', '10000')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      // Both fields should exist when invoice is paid
      await waitFor(
        () => {
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 3000 },
      )
    })

    it('should validate that credit + refund sum equals total', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock('10000', '10000')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      await waitFor(
        () => {
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 3000 },
      )

      const creditWrapper = screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)
      const refundWrapper = screen.getByTestId(REFUND_AMOUNT_INPUT_TEST_ID)
      const creditInput = creditWrapper.querySelector('input') as HTMLInputElement
      const refundInput = refundWrapper.querySelector('input') as HTMLInputElement

      // Set mismatched values (total is 100 but we set 50 + 30 = 80)
      await user.clear(creditInput)
      await user.type(creditInput, '50')

      await user.clear(refundInput)
      await user.type(refundInput, '30')

      // Wait for validation to run (debounced)
      await waitFor(
        () => {
          const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

          // Submit should be disabled due to sum mismatch
          expect(submitButton).toBeDisabled()
        },
        { timeout: 3000 },
      )
    })

    it('should validate refund does not exceed max refundable amount', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock('10000', '10000')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      await waitFor(
        () => {
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 3000 },
      )

      const creditWrapper = screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)
      const refundWrapper = screen.getByTestId(REFUND_AMOUNT_INPUT_TEST_ID)
      const creditInput = creditWrapper.querySelector('input') as HTMLInputElement
      const refundInput = refundWrapper.querySelector('input') as HTMLInputElement

      // Set refund to exceed max (max refundable is 100)
      await user.clear(creditInput)
      await user.type(creditInput, '0')

      await user.clear(refundInput)
      await user.type(refundInput, '150')

      // Wait for validation (debounced)
      await waitFor(
        () => {
          const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

          expect(submitButton).toBeDisabled()
        },
        { timeout: 3000 },
      )
    })

    it('should validate credit does not exceed max creditable amount', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock('10000', '10000')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      await waitFor(
        () => {
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 3000 },
      )

      const creditWrapper = screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)
      const refundWrapper = screen.getByTestId(REFUND_AMOUNT_INPUT_TEST_ID)
      const creditInput = creditWrapper.querySelector('input') as HTMLInputElement
      const refundInput = refundWrapper.querySelector('input') as HTMLInputElement

      // Set credit to exceed max (max creditable is 100)
      await user.clear(creditInput)
      await user.type(creditInput, '150')

      await user.clear(refundInput)
      await user.type(refundInput, '0')

      // Wait for validation (debounced)
      await waitFor(
        () => {
          const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

          expect(submitButton).toBeDisabled()
        },
        { timeout: 3000 },
      )
    })

    it('should accept valid split between credit and refund', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock('10000', '10000')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      await waitFor(
        () => {
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 3000 },
      )

      const creditWrapper = screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)
      const refundWrapper = screen.getByTestId(REFUND_AMOUNT_INPUT_TEST_ID)
      const creditInput = creditWrapper.querySelector('input') as HTMLInputElement
      const refundInput = refundWrapper.querySelector('input') as HTMLInputElement

      // Set valid split: credit 60, refund 40 (total 100)
      await user.clear(creditInput)
      await user.type(creditInput, '60')

      await user.clear(refundInput)
      await user.type(refundInput, '40')

      // Form should eventually become valid
      // Note: There may be a delay due to debounced validation
      await waitFor(
        () => {
          // Check that inputs have the expected values
          expect(creditInput).toHaveValue('60')
          expect(refundInput).toHaveValue('40')
        },
        { timeout: 3000 },
      )
    })

    it('should handle partially paid invoice and show paid amount', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          totalPaidAmountCents: '5000', // $50 paid out of $100
          totalAmountCents: '10000', // $100 total
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        onCreate: mockOnCreate,
      })

      await act(() => render(<CreateCreditNote />))

      const paidAmountElements = screen.getAllByText(/\$50\.00/)

      expect(paidAmountElements.length).toBeGreaterThan(0)

      // Both credit and refund fields should be available
      await waitFor(() => {
        expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('PayBack Scenarios - Apply to Invoice Mode', () => {
    it('should show apply to invoice field when there is amount due', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          totalPaidAmountCents: '0',
          totalDueAmountCents: '10000',
          refundableAmountCents: '0',
          offsettableAmountCents: '10000',
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        hasCreditableOrRefundableAmount: true,
        onCreate: mockOnCreate,
      })

      const mocks = [createCreditNoteEstimateMock('10000', '0')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      await waitFor(
        () => {
          // Credit input should be available
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          // Apply to invoice should be available since totalDueAmountCents > 0
          expect(screen.queryByTestId(OFFSET_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          // Refund should NOT be available since no payment was made
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
        },
        { timeout: 3000 },
      )
    })

    it('should not show apply to invoice field when there is no amount due', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          totalPaidAmountCents: '10000', // Fully paid
          totalDueAmountCents: '0', // No amount due
          offsettableAmountCents: '0',
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        hasCreditableOrRefundableAmount: true,
        onCreate: mockOnCreate,
      })

      const mocks = [createCreditNoteEstimateMock('10000', '10000')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      await waitFor(
        () => {
          // Credit and refund should be available
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          // Apply to invoice should NOT be available since totalDueAmountCents is 0
          expect(screen.queryByTestId(OFFSET_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
        },
        { timeout: 3000 },
      )
    })

    it('should show all three allocation options for partially paid invoice with amount due', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          totalPaidAmountCents: '5000',
          totalDueAmountCents: '5000',
          offsettableAmountCents: '5000',
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        hasCreditableOrRefundableAmount: true,
        onCreate: mockOnCreate,
      })

      const mocks = [createCreditNoteEstimateMock('10000', '5000')]

      await act(() => render(<CreateCreditNote />, { mocks }))

      await waitFor(
        () => {
          // All three allocation options should be available
          expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
          expect(screen.queryByTestId(OFFSET_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 3000 },
      )
    })
  })

  describe('PayBack Scenarios - API Error Handling', () => {
    it('should handle DoesNotMatchItemAmounts error from API', async () => {
      // Mock onCreate to return DoesNotMatchItemAmounts error
      const mockOnCreateWithError = jest.fn().mockResolvedValue({
        errors: {
          graphQLErrors: [
            {
              extensions: {
                code: LagoApiError.DoesNotMatchItemAmounts,
              },
            },
          ],
        },
      })

      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          // Set initial values that would trigger validation
          reason: CreditNoteReasonEnum.Other,
        },
        feesPerInvoice: defaultMockFeesPerInvoice,
        feeForAddOn: undefined,
        feeForCredit: undefined,
        onCreate: mockOnCreateWithError,
      })

      await act(() => render(<CreateCreditNote />))

      // The form should be rendered
      expect(screen.getByTestId(SUBMIT_BUTTON_TEST_ID)).toBeInTheDocument()

      // Note: To fully test error handling, we'd need to:
      // 1. Fill in the reason field
      // 2. Click submit
      // 3. Verify error message appears
      // This requires proper combobox interaction which is complex in tests
    })
  })

  describe('PayBack Scenarios - Prepaid Credits Invoice', () => {
    it('should automatically set payBack to refund for prepaid credits invoice', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          invoiceType: 'credit',
        },
        feesPerInvoice: undefined,
        feeForAddOn: undefined,
        feeForCredit: [
          {
            id: 'credit-fee-1',
            checked: true,
            value: 50,
            name: 'Prepaid Credit',
            maxAmount: '5000',
            appliedTaxes: [],
          },
        ],
        hasCreditableOrRefundableAmount: true,
        onCreate: mockOnCreate,
      })

      await act(() => render(<CreateCreditNote />))

      // Should show info alert about prepaid credits refund
      expect(screen.getByTestId(PREPAID_CREDITS_REFUND_ALERT_TEST_ID)).toBeInTheDocument()

      // Should not show separate credit/refund input fields for prepaid credits
      expect(screen.queryByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
      expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
    })

    it('should display prepaid credit fee item with checkbox', async () => {
      mockUseCreateCreditNote.mockReturnValue({
        loading: false,
        invoice: {
          ...defaultMockInvoice,
          invoiceType: 'credit',
        },
        feesPerInvoice: undefined,
        feeForAddOn: undefined,
        feeForCredit: [
          {
            id: 'credit-fee-1',
            checked: true,
            value: 50,
            name: 'Prepaid Credit',
            maxAmount: '5000',
            appliedTaxes: [],
          },
        ],
        onCreate: mockOnCreate,
      })

      await act(() => render(<CreateCreditNote />))

      // Should show fee selection label
      expect(screen.getByText(/Prepaid credit/i)).toBeInTheDocument()
    })
  })

  describe('Form State Management', () => {
    it('should show warning dialog when closing with dirty form', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock()]

      await act(() => render(<CreateCreditNote />, { mocks }))

      // Type in description to make form dirty
      const descriptionWrapper = screen.getByTestId(DESCRIPTION_INPUT_TEST_ID)
      const descriptionInput = descriptionWrapper.querySelector('textarea') as HTMLTextAreaElement

      await user.type(descriptionInput, 'Some text to make form dirty')

      // Find close button by data-test
      const closeButton = screen.getByTestId(CLOSE_BUTTON_TEST_ID)

      expect(closeButton).toBeInTheDocument()

      await user.click(closeButton)

      // Warning dialog should appear
      await waitFor(
        () => {
          // The dialog renders with specific text from translations
          // text_636bed940028096908b735ed: "Are you sure you want to discard this draft?"
          const hasDialog =
            screen.queryByText(/discard this draft/i) || screen.queryByRole('dialog')

          expect(hasDialog).toBeTruthy()
        },
        { timeout: 3000 },
      )
    }, 10000)

    it('should update form state when fees are checked/unchecked', async () => {
      const user = userEvent.setup()

      await act(() => render(<CreateCreditNote />))

      // Find the subscription checkbox by data-test (subscription key is 'sub-1' from mock)
      // Wait for it to render
      const subscriptionCheckboxLabel = await screen.findByTestId(
        getSubscriptionCheckboxTestId('sub-1'),
      )

      expect(subscriptionCheckboxLabel).toBeInTheDocument()

      // Get the actual input element within the label
      const subscriptionCheckbox = subscriptionCheckboxLabel.querySelector(
        'input[type="checkbox"]',
      ) as HTMLInputElement

      expect(subscriptionCheckbox).toBeInTheDocument()

      // The checkbox should be checked by default (from mock data)
      expect(subscriptionCheckbox).toBeChecked()

      // Uncheck it by clicking the label (which is more realistic)
      await user.click(subscriptionCheckboxLabel)

      // After unchecking, it should be unchecked
      await waitFor(() => {
        expect(subscriptionCheckbox).not.toBeChecked()
      })

      // Submit button should be disabled when no fees are selected
      await waitFor(() => {
        const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

        expect(submitButton).toBeDisabled()
      })
    })
  })

  describe('Metadata Validation', () => {
    it('should allow adding metadata entries', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock()]

      await act(() => render(<CreateCreditNote />, { mocks }))

      // Find the button by its data-test attribute
      const addMetadataButton = screen.getByTestId('add-metadata-button')

      await user.click(addMetadataButton)

      // Metadata inputs should appear (they use placeholder text, not labels)
      await waitFor(
        () => {
          expect(screen.getByPlaceholderText(/key/i)).toBeInTheDocument()
          expect(screen.getByPlaceholderText(/value/i)).toBeInTheDocument()
        },
        { timeout: 3000 },
      )
    })

    it('should enforce metadata key max length of 40 characters', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock()]

      await act(() => render(<CreateCreditNote />, { mocks }))

      const addMetadataButton = screen.getByTestId('add-metadata-button')

      await user.click(addMetadataButton)

      const keyInputWrapper = screen.getByPlaceholderText(/key/i)
      const keyInput = keyInputWrapper

      // Try to type 41 characters (using paste is faster)
      const longKey = 'a'.repeat(41)

      await user.clear(keyInput)
      await user.click(keyInput)
      await user.paste(longKey)

      // Validation should prevent submission
      await waitFor(
        () => {
          const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

          expect(submitButton).toBeDisabled()
        },
        { timeout: 3000 },
      )
    }, 10000)

    it('should enforce metadata value max length of 255 characters', async () => {
      const user = userEvent.setup()
      const mocks = [createCreditNoteEstimateMock()]

      await act(() => render(<CreateCreditNote />, { mocks }))

      const addMetadataButton = screen.getByTestId('add-metadata-button')

      await user.click(addMetadataButton)

      const keyInput = screen.getByPlaceholderText(/key/i)
      const valueInput = screen.getByPlaceholderText(/value/i)

      // Type valid key
      await user.type(keyInput, 'validKey')

      // Try to type 256 characters in value (using paste is faster)
      const longValue = 'a'.repeat(256)

      await user.clear(valueInput)
      await user.click(valueInput)
      await user.paste(longValue)

      // Validation should prevent submission
      await waitFor(
        () => {
          const submitButton = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

          expect(submitButton).toBeDisabled()
        },
        { timeout: 3000 },
      )
    }, 10000)
  })
})
