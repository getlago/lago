import { ComboBox } from '~/components/form'
import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { createMockPaymentMethod } from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { PaymentMethodList, usePaymentMethodsList } from '~/hooks/customer/usePaymentMethodsList'
import { render } from '~/test-utils'

import { PaymentMethodComboBox } from '../PaymentMethodComboBox'

jest.mock('~/components/form', () => ({
  ...jest.requireActual('~/components/form'),
  ComboBox: jest.fn(() => null),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

jest.mock('~/hooks/customer/usePaymentMethodsList', () => ({
  usePaymentMethodsList: jest.fn(() => ({
    data: [],
    loading: false,
    error: false,
    refetch: jest.fn(),
  })),
}))

const mockUsePaymentMethodsList = jest.mocked(usePaymentMethodsList)

const mockComboBox = jest.mocked(ComboBox)
const mockSetSelectedPaymentMethod = jest.fn()

const paymentMethod1 = createMockPaymentMethod({
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

const paymentMethod2 = createMockPaymentMethod({
  id: 'pm_002',
  isDefault: false,
  details: {
    __typename: 'PaymentMethodDetails',
    brand: 'mastercard',
    last4: '8888',
    type: 'card',
    expirationMonth: '06',
    expirationYear: '2026',
  },
})

type PrepareType = {
  paymentMethodsList?: PaymentMethodList
  externalCustomerId?: string
  selectedPaymentMethod?: {
    paymentMethodId: string
    paymentMethodType: PaymentMethodTypeEnum
  } | null
  disabled?: boolean
}

function prepare({
  paymentMethodsList,
  externalCustomerId,
  selectedPaymentMethod,
  disabled = false,
}: PrepareType = {}) {
  return render(
    <PaymentMethodComboBox
      paymentMethodsList={paymentMethodsList}
      externalCustomerId={externalCustomerId}
      selectedPaymentMethod={selectedPaymentMethod}
      setSelectedPaymentMethod={mockSetSelectedPaymentMethod}
      disabled={disabled}
    />,
  )
}

describe('PaymentMethodComboBox', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('WHEN paymentMethodsList prop is provided', () => {
    it('THEN uses the provided list and skips fetching', () => {
      prepare({
        paymentMethodsList: [paymentMethod1, paymentMethod2],
        externalCustomerId: 'customer_123',
      })

      // Hook should be called with skip: true to prevent the fetch
      expect(mockUsePaymentMethodsList).toHaveBeenCalledWith({
        externalCustomerId: 'customer_123',
        withDeleted: false,
        skip: true,
      })

      // ComboBox should receive options from the provided list
      const comboboxCall = mockComboBox.mock.calls[0]
      const data = comboboxCall[0]?.data

      expect(data).toHaveLength(2)
    })

    describe('AND onChange is called with a valid payment method id', () => {
      it('THEN calls setSelectedPaymentMethod with correct paymentMethodId and paymentMethodType', () => {
        prepare({ paymentMethodsList: [paymentMethod1, paymentMethod2] })

        // Get the onChange function that was passed to ComboBox
        const comboboxCall = mockComboBox.mock.calls[0]
        const onChange = comboboxCall[0]?.onChange

        expect(onChange).toBeDefined()

        // Simulate selecting pm_001
        onChange?.('pm_001')

        expect(mockSetSelectedPaymentMethod).toHaveBeenCalledWith({
          paymentMethodId: 'pm_001',
          paymentMethodType: PaymentMethodTypeEnum.Provider,
        })
      })

      it('THEN calls setSelectedPaymentMethod with correct values for different payment method', () => {
        prepare({ paymentMethodsList: [paymentMethod1, paymentMethod2] })

        const comboboxCall = mockComboBox.mock.calls[0]
        const onChange = comboboxCall[0]?.onChange

        expect(onChange).toBeDefined()

        // Simulate selecting pm_002
        onChange?.('pm_002')

        expect(mockSetSelectedPaymentMethod).toHaveBeenCalledWith({
          paymentMethodId: 'pm_002',
          paymentMethodType: PaymentMethodTypeEnum.Provider,
        })
      })
    })
  })

  describe('WHEN paymentMethodsList prop is not provided', () => {
    it('THEN uses externalCustomerId to fetch payment methods via hook', () => {
      mockUsePaymentMethodsList.mockReturnValue({
        data: [paymentMethod1, paymentMethod2],
        loading: false,
        error: false,
        refetch: jest.fn(),
      })

      prepare({ externalCustomerId: 'customer_123' })

      expect(mockUsePaymentMethodsList).toHaveBeenCalledWith({
        externalCustomerId: 'customer_123',
        withDeleted: false,
        skip: false,
      })

      // ComboBox should receive options from the fetched list
      const comboboxCall = mockComboBox.mock.calls[0]
      const data = comboboxCall[0]?.data

      expect(data).toHaveLength(2)
    })

    it('THEN handles empty fetched list gracefully', () => {
      mockUsePaymentMethodsList.mockReturnValue({
        data: [],
        loading: false,
        error: false,
        refetch: jest.fn(),
      })

      prepare({ externalCustomerId: 'customer_123' })

      const comboboxCall = mockComboBox.mock.calls[0]
      const data = comboboxCall[0]?.data

      expect(data).toHaveLength(0)
    })

    it('THEN handles undefined externalCustomerId by passing it directly to the hook', () => {
      mockUsePaymentMethodsList.mockReturnValue({
        data: [],
        loading: false,
        error: false,
        refetch: jest.fn(),
      })

      prepare({ externalCustomerId: undefined })

      expect(mockUsePaymentMethodsList).toHaveBeenCalledWith({
        externalCustomerId: undefined,
        withDeleted: false,
        skip: false,
      })

      const comboboxCall = mockComboBox.mock.calls[0]
      const data = comboboxCall[0]?.data

      expect(data).toHaveLength(0)
    })
  })

  describe('WHEN paymentMethodsList prop is empty array', () => {
    it('THEN falls back to fetched list from hook', () => {
      mockUsePaymentMethodsList.mockReturnValue({
        data: [paymentMethod1],
        loading: false,
        error: false,
        refetch: jest.fn(),
      })

      prepare({ paymentMethodsList: [], externalCustomerId: 'customer_123' })

      // ComboBox should receive options from the fetched list
      const comboboxCall = mockComboBox.mock.calls[0]
      const data = comboboxCall[0]?.data

      expect(data).toHaveLength(1)
    })
  })

  describe('selectedValue behavior', () => {
    describe('WHEN selectedPaymentMethod.paymentMethodId exists in the options list', () => {
      it('THEN passes the paymentMethodId as value to ComboBox', () => {
        prepare({
          paymentMethodsList: [paymentMethod1, paymentMethod2],
          selectedPaymentMethod: {
            paymentMethodId: 'pm_001',
            paymentMethodType: PaymentMethodTypeEnum.Provider,
          },
        })

        const comboboxCall = mockComboBox.mock.calls[0]
        const value = comboboxCall[0]?.value

        expect(value).toBe('pm_001')
      })
    })

    describe('WHEN selectedPaymentMethod.paymentMethodId does NOT exist in the options list', () => {
      it('THEN passes undefined as value to ComboBox', () => {
        prepare({
          paymentMethodsList: [paymentMethod1, paymentMethod2],
          selectedPaymentMethod: {
            paymentMethodId: 'pm_nonexistent',
            paymentMethodType: PaymentMethodTypeEnum.Provider,
          },
        })

        const comboboxCall = mockComboBox.mock.calls[0]
        const value = comboboxCall[0]?.value

        expect(value).toBeUndefined()
      })
    })

    describe('WHEN selectedPaymentMethod is null', () => {
      it('THEN passes undefined as value to ComboBox', () => {
        prepare({
          paymentMethodsList: [paymentMethod1, paymentMethod2],
          selectedPaymentMethod: null,
        })

        const comboboxCall = mockComboBox.mock.calls[0]
        const value = comboboxCall[0]?.value

        expect(value).toBeUndefined()
      })
    })

    describe('WHEN selectedPaymentMethod is undefined', () => {
      it('THEN passes undefined as value to ComboBox', () => {
        prepare({
          paymentMethodsList: [paymentMethod1, paymentMethod2],
          selectedPaymentMethod: undefined,
        })

        const comboboxCall = mockComboBox.mock.calls[0]
        const value = comboboxCall[0]?.value

        expect(value).toBeUndefined()
      })
    })

    describe('WHEN options list is empty', () => {
      it('THEN passes undefined as value even if paymentMethodId is provided', () => {
        mockUsePaymentMethodsList.mockReturnValue({
          data: [],
          loading: false,
          error: false,
          refetch: jest.fn(),
        })

        prepare({
          paymentMethodsList: [],
          selectedPaymentMethod: {
            paymentMethodId: 'pm_001',
            paymentMethodType: PaymentMethodTypeEnum.Provider,
          },
        })

        const comboboxCall = mockComboBox.mock.calls[0]
        const value = comboboxCall[0]?.value

        expect(value).toBeUndefined()
      })
    })
  })
})
