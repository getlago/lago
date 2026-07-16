import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { PaymentMethodsDocument } from '~/generated/graphql'
import {
  createMockPaymentMethod,
  createMockPaymentMethodsQueryResponse,
} from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { render } from '~/test-utils'

import {
  EDIT_PAYMENT_METHOD_BUTTON_TEST_ID,
  PaymentMethodSelection,
} from '../PaymentMethodSelection'
import { SelectedPaymentMethod } from '../types'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

const EXTERNAL_CUSTOMER_ID = 'customer_ext_123'

const defaultPaymentMethod = createMockPaymentMethod({
  id: 'pm_001',
  isDefault: true,
  details: {
    __typename: 'PaymentMethodDetails',
    brand: 'visa',
    last4: '4242',
    type: 'card',
    expirationMonth: '12',
    expirationYear: '2025',
  },
})

type PrepareType = {
  selectedPaymentMethod?: SelectedPaymentMethod
  title?: string
  description?: string
  viewType?: ViewTypeEnum
  className?: string
  disabled?: boolean
  loading?: boolean
  error?: boolean
  paymentMethods?: ReturnType<typeof createMockPaymentMethod>[]
}

const mockSetSelectedPaymentMethod = jest.fn()

async function prepare({
  selectedPaymentMethod,
  viewType = ViewTypeEnum.Subscription,
  className,
  disabled = false,
  loading = false,
  error = false,
  paymentMethods = [defaultPaymentMethod],
}: PrepareType = {}) {
  const mocks = [
    {
      request: {
        query: PaymentMethodsDocument,
        variables: {
          externalCustomerId: EXTERNAL_CUSTOMER_ID,
          withDeleted: false,
        },
      },
      result: error
        ? {
            errors: [{ message: 'Network error' }],
          }
        : {
            data: createMockPaymentMethodsQueryResponse(paymentMethods),
            delay: loading ? 100 : 0,
          },
    },
  ]

  const result = await act(() =>
    render(
      <PaymentMethodSelection
        externalCustomerId={EXTERNAL_CUSTOMER_ID}
        selectedPaymentMethod={selectedPaymentMethod}
        setSelectedPaymentMethod={mockSetSelectedPaymentMethod}
        viewType={viewType}
        className={className}
        disabled={disabled}
      />,
      { mocks },
    ),
  )

  return result
}

describe('PaymentMethodSelection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('WHEN rendering with basic props', () => {
    it('THEN renders edit button with correct text', async () => {
      await prepare()

      const editButton = screen.getByTestId(EDIT_PAYMENT_METHOD_BUTTON_TEST_ID)

      expect(editButton).toBeInTheDocument()
    })
  })

  describe('WHEN payment methods query has error', () => {
    it('THEN disables the edit button', async () => {
      await prepare({ error: true })

      await waitFor(() => {
        const editButton = screen.getByTestId(EDIT_PAYMENT_METHOD_BUTTON_TEST_ID)

        expect(editButton).toBeDisabled()
      })
    })
  })

  describe('WHEN disabled prop is true', () => {
    it('THEN disables the edit button', async () => {
      await prepare({ disabled: true })

      const editButton = screen.getByTestId(EDIT_PAYMENT_METHOD_BUTTON_TEST_ID)

      expect(editButton).toBeDisabled()
    })
  })

  describe('WHEN clicking edit button', () => {
    it('THEN opens EditPaymentMethodDialog', async () => {
      await prepare()

      const editButton = screen.getByTestId(EDIT_PAYMENT_METHOD_BUTTON_TEST_ID)

      await userEvent.click(editButton)

      await waitFor(() => {
        expect(screen.getByTestId('dialog-title')).toBeInTheDocument()
      })
    })
  })
})
