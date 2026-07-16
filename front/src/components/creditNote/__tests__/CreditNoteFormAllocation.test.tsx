import { render, screen } from '@testing-library/react'

import { createMockFormikProps } from '~/components/creditNote/__tests__/formikProps.factory'
import { CurrencyEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import {
  CREDIT_AMOUNT_INPUT_TEST_ID,
  CreditNoteFormAllocation,
  OFFSET_AMOUNT_INPUT_TEST_ID,
  REFUND_AMOUNT_INPUT_TEST_ID,
} from '../CreditNoteFormAllocation'
import { CreditNoteForm, CreditTypeEnum, PayBackErrorEnum } from '../types'

const defaultProps = {
  formikProps: createMockFormikProps<CreditNoteForm>({
    values: {
      payBack: [
        { type: CreditTypeEnum.credit, value: 0 },
        { type: CreditTypeEnum.refund, value: 0 },
        { type: CreditTypeEnum.offset, value: 0 },
      ],
    },
  }),
  currency: CurrencyEnum.Usd,
  maxCreditableAmount: 100,
  maxRefundableAmount: 100,
  maxOffsettableAmount: 50,
  totalTaxIncluded: 120,
  estimationLoading: false,
}

const renderComponent = (props = {}) => {
  return render(<CreditNoteFormAllocation {...defaultProps} {...props} />, {
    wrapper: AllTheProviders,
  })
}

describe('CreditNoteFormAllocation', () => {
  describe('GIVEN all payBack types are present', () => {
    it('THEN should render all three allocation inputs', () => {
      renderComponent()

      expect(screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(OFFSET_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('GIVEN only credit type in payBack', () => {
    it('THEN should render only credit input', () => {
      const formikProps = createMockFormikProps<CreditNoteForm>({
        values: {
          payBack: [{ type: CreditTypeEnum.credit, value: 0 }],
        },
      })

      renderComponent({ formikProps })

      expect(screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
      expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
      expect(screen.queryByTestId(OFFSET_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('GIVEN credit and refund types in payBack', () => {
    it('THEN should render credit and refund inputs only', () => {
      const formikProps = createMockFormikProps<CreditNoteForm>({
        values: {
          payBack: [
            { type: CreditTypeEnum.credit, value: 0 },
            { type: CreditTypeEnum.refund, value: 0 },
          ],
        },
      })

      renderComponent({ formikProps })

      expect(screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
      expect(screen.queryByTestId(OFFSET_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('GIVEN credit and offset types in payBack', () => {
    it('THEN should render credit and offset inputs only', () => {
      const formikProps = createMockFormikProps<CreditNoteForm>({
        values: {
          payBack: [
            { type: CreditTypeEnum.credit, value: 0 },
            { type: CreditTypeEnum.offset, value: 0 },
          ],
        },
      })

      renderComponent({ formikProps })

      expect(screen.getByTestId(CREDIT_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
      expect(screen.queryByTestId(REFUND_AMOUNT_INPUT_TEST_ID)).not.toBeInTheDocument()
      expect(screen.getByTestId(OFFSET_AMOUNT_INPUT_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('GIVEN allocation summary', () => {
    it('WHEN values are provided THEN should display total, allocated and remaining amounts', () => {
      const formikProps = createMockFormikProps<CreditNoteForm>({
        values: {
          payBack: [
            { type: CreditTypeEnum.credit, value: 50 },
            { type: CreditTypeEnum.refund, value: 30 },
          ],
        },
      })

      renderComponent({ formikProps, totalTaxIncluded: 120 })

      // Total: $120, Allocated: $80 (50+30), Remaining: $40
      expect(screen.getByText('$120.00')).toBeInTheDocument()
      expect(screen.getByText('$80.00')).toBeInTheDocument()
      expect(screen.getByText('$40.00')).toBeInTheDocument()
    })

    it('WHEN offset has value THEN should include it in allocation calculation', () => {
      const formikProps = createMockFormikProps<CreditNoteForm>({
        values: {
          payBack: [
            { type: CreditTypeEnum.credit, value: 30 },
            { type: CreditTypeEnum.refund, value: 20 },
            { type: CreditTypeEnum.offset, value: 10 },
          ],
        },
      })

      renderComponent({ formikProps, totalTaxIncluded: 100 })

      // Total: $100, Allocated: $60 (30+20+10), Remaining: $40
      expect(screen.getByText('$100.00')).toBeInTheDocument()
      expect(screen.getByText('$60.00')).toBeInTheDocument()
      expect(screen.getByText('$40.00')).toBeInTheDocument()
    })
  })

  describe('GIVEN error alert', () => {
    it('WHEN payBackErrors exists AND at least one field is touched THEN should show danger alert', () => {
      const formikProps = createMockFormikProps<CreditNoteForm>({
        values: {
          payBack: [
            { type: CreditTypeEnum.credit, value: 0 },
            { type: CreditTypeEnum.refund, value: 0 },
          ],
        },
        errors: {
          payBackErrors: PayBackErrorEnum.maxTotalInvoice,
        } as Record<string, unknown>,
        touched: {
          payBack: [{ value: true }, { value: false }],
        } as Record<string, unknown>,
      })

      renderComponent({ formikProps })

      expect(screen.getByTestId('alert-type-danger')).toBeInTheDocument()
    })

    it('WHEN payBackErrors exists BUT no field is touched THEN should not show alert', () => {
      const formikProps = createMockFormikProps<CreditNoteForm>({
        values: {
          payBack: [
            { type: CreditTypeEnum.credit, value: 0 },
            { type: CreditTypeEnum.refund, value: 0 },
          ],
        },
        errors: {
          payBackErrors: PayBackErrorEnum.maxTotalInvoice,
        } as Record<string, unknown>,
        touched: {},
      })

      renderComponent({ formikProps })

      expect(screen.queryByTestId('alert-type-danger')).not.toBeInTheDocument()
    })

    it('WHEN no errors THEN should not show alert', () => {
      renderComponent()

      expect(screen.queryByTestId('alert-type-danger')).not.toBeInTheDocument()
    })
  })
})
