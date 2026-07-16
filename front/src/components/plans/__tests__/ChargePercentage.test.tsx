import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { ChargePercentage } from '../ChargePercentage'
import {
  CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID,
  CHARGE_PERCENTAGE_ADD_FREE_UNITS_TEST_ID,
  CHARGE_PERCENTAGE_ADD_MAX_CTA_TEST_ID,
  CHARGE_PERCENTAGE_ADD_MIN_CTA_TEST_ID,
  CHARGE_PERCENTAGE_ADD_MIN_MAX_TEST_ID,
  CHARGE_PERCENTAGE_REMOVE_FIXED_FEE_TEST_ID,
} from '../chargeTestIds'

// --- Mocks ---

const mockSetFieldValue = jest.fn()

const createMockStore = (values: Record<string, unknown>) => ({
  subscribe: jest.fn((cb: () => void) => {
    cb()
    return () => {}
  }),
  listeners: new Set(),
  state: { values },
})

const createMockForm = (propertyValues: Record<string, unknown>) => {
  const store = createMockStore({ properties: propertyValues })

  return {
    setFieldValue: mockSetFieldValue,
    store,
    AppField: ({
      children,
      name,
    }: {
      children: (field: unknown) => React.ReactNode
      name: string
    }) => {
      const fieldApi = {
        state: { meta: { errors: [] } },
        TextInputField: (props: Record<string, unknown>) => (
          <input
            data-test={props['data-test'] as string}
            placeholder={props.placeholder as string}
            aria-label={props.label as string}
          />
        ),
        AmountInputField: (props: Record<string, unknown>) => (
          <input
            data-test={props['data-test'] as string}
            placeholder={props.placeholder as string}
            aria-label={props.label as string}
          />
        ),
      }

      return <div data-field-name={name}>{children(fieldApi)}</div>
    },
  }
}

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => `translated_${key}`,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (c: string) => c,
  intlFormatNumber: (value: number) => String(value),
}))

let mockPropertyValues: Record<string, unknown> = { rate: '5' }
let mockForm = createMockForm(mockPropertyValues)

jest.mock('~/contexts/ChargeFormContext', () => ({
  useChargeFormContext: () => ({
    form: mockForm,
    propertyCursor: 'properties',
    currency: 'USD' as CurrencyEnum,
    disabled: false,
    chargePricingUnitShortName: undefined,
  }),
  usePropertyValues: () => mockPropertyValues,
}))

// --- Tests ---

describe('ChargePercentage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockPropertyValues = { rate: '5' }
    mockForm = createMockForm(mockPropertyValues)
  })

  describe('GIVEN the component is rendered with minimal properties', () => {
    describe('WHEN only rate is defined', () => {
      it('THEN should render the rate field', () => {
        render(<ChargePercentage />)

        const rateField = document.querySelector('[data-field-name="properties.rate"]')

        expect(rateField).toBeInTheDocument()
      })

      it('THEN should render the add fixed fee button', () => {
        render(<ChargePercentage />)

        expect(screen.getByTestId(CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the add free units button', () => {
        render(<ChargePercentage />)

        expect(screen.getByTestId(CHARGE_PERCENTAGE_ADD_FREE_UNITS_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the add min/max button', () => {
        render(<ChargePercentage />)

        expect(screen.getByTestId(CHARGE_PERCENTAGE_ADD_MIN_MAX_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the add fixed fee button is available', () => {
    describe('WHEN the user clicks the add fixed fee button', () => {
      it('THEN should call setFieldValue with fixedAmount empty string', async () => {
        const user = userEvent.setup()

        render(<ChargePercentage />)

        await user.click(screen.getByTestId(CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID))

        expect(mockSetFieldValue).toHaveBeenCalledWith('properties', {
          ...mockPropertyValues,
          fixedAmount: '',
        })
      })
    })
  })

  describe('GIVEN the fixed amount field is visible', () => {
    beforeEach(() => {
      mockPropertyValues = { rate: '5', fixedAmount: '10' }
      mockForm = createMockForm(mockPropertyValues)
    })

    describe('WHEN the component renders', () => {
      it('THEN should show the remove fixed fee button', () => {
        render(<ChargePercentage />)

        expect(screen.getByTestId(CHARGE_PERCENTAGE_REMOVE_FIXED_FEE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should disable the add fixed fee button', () => {
        render(<ChargePercentage />)

        const addButton = screen.getByTestId(CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID)

        expect(addButton).toBeDisabled()
      })
    })

    describe('WHEN the user clicks the remove fixed fee button', () => {
      it('THEN should call setFieldValue with fixedAmount undefined', async () => {
        const user = userEvent.setup()

        render(<ChargePercentage />)

        await user.click(screen.getByTestId(CHARGE_PERCENTAGE_REMOVE_FIXED_FEE_TEST_ID))

        expect(mockSetFieldValue).toHaveBeenCalledWith('properties', {
          ...mockPropertyValues,
          fixedAmount: undefined,
        })
      })
    })
  })

  describe('GIVEN the min/max dropdown is available', () => {
    describe('WHEN the user clicks the add min/max dropdown and selects add min', () => {
      it('THEN should call setFieldValue with perTransactionMinAmount', async () => {
        const user = userEvent.setup()

        render(<ChargePercentage />)

        await user.click(screen.getByTestId(CHARGE_PERCENTAGE_ADD_MIN_MAX_TEST_ID))
        await user.click(screen.getByTestId(CHARGE_PERCENTAGE_ADD_MIN_CTA_TEST_ID))

        expect(mockSetFieldValue).toHaveBeenCalledWith('properties', {
          ...mockPropertyValues,
          perTransactionMinAmount: '',
        })
      })
    })

    describe('WHEN the user clicks the add min/max dropdown and selects add max', () => {
      it('THEN should call setFieldValue with perTransactionMaxAmount', async () => {
        const user = userEvent.setup()

        render(<ChargePercentage />)

        await user.click(screen.getByTestId(CHARGE_PERCENTAGE_ADD_MIN_MAX_TEST_ID))
        await user.click(screen.getByTestId(CHARGE_PERCENTAGE_ADD_MAX_CTA_TEST_ID))

        expect(mockSetFieldValue).toHaveBeenCalledWith('properties', {
          ...mockPropertyValues,
          perTransactionMaxAmount: '',
        })
      })
    })
  })

  describe('GIVEN both min and max are already set', () => {
    beforeEach(() => {
      mockPropertyValues = {
        rate: '5',
        perTransactionMinAmount: '1',
        perTransactionMaxAmount: '100',
      }
      mockForm = createMockForm(mockPropertyValues)
    })

    describe('WHEN the component renders', () => {
      it('THEN should disable the min/max dropdown button', () => {
        render(<ChargePercentage />)

        expect(screen.getByTestId(CHARGE_PERCENTAGE_ADD_MIN_MAX_TEST_ID)).toBeDisabled()
      })
    })
  })
})
