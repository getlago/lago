import { screen } from '@testing-library/react'

import {
  type ChargeForm,
  useChargeFormContext,
  usePropertyValues,
} from '~/contexts/ChargeFormContext'
import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  PACKAGE_CHARGE_EMPTY_ALERT_TEST_ID,
  PACKAGE_CHARGE_FILLED_ALERT_TEST_ID,
  PACKAGE_CHARGE_FREE_UNITS_ALERT_TEST_ID,
  PackageCharge,
} from '../PackageCharge'

// --- Mocks ---

const mockAmountInputField = jest.fn()
const mockTextInputField = jest.fn()

jest.mock('~/contexts/ChargeFormContext', () => ({
  useChargeFormContext: jest.fn(),
  usePropertyValues: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (currency: string) => currency,
  intlFormatNumber: (value: number) => String(value),
}))

const mockedUseChargeFormContext = useChargeFormContext as jest.MockedFunction<
  typeof useChargeFormContext
>
const mockedUsePropertyValues = usePropertyValues as jest.MockedFunction<typeof usePropertyValues>

// --- Helpers ---

const setupDefaultMocks = (overrides?: {
  disabled?: boolean
  amount?: string
  packageSize?: string
  freeUnits?: string
  chargePricingUnitShortName?: string
}) => {
  mockAmountInputField.mockImplementation((props: Record<string, unknown>) => (
    <input data-test="mock-amount-input" name="amount" disabled={props.disabled as boolean} />
  ))

  mockTextInputField.mockImplementation((props: Record<string, unknown>) => (
    <input
      data-test="mock-text-input"
      name={props.label as string | undefined}
      disabled={props.disabled as boolean}
    />
  ))

  mockedUseChargeFormContext.mockReturnValue({
    form: {
      AppField: ({
        children,
      }: {
        name: string
        children: (field: Record<string, unknown>) => JSX.Element
      }) => (
        <>
          {children({
            AmountInputField: mockAmountInputField,
            TextInputField: mockTextInputField,
          })}
        </>
      ),
    } as unknown as ChargeForm,
    propertyCursor: 'properties',
    currency: CurrencyEnum.Usd,
    disabled: overrides?.disabled ?? false,
    chargePricingUnitShortName: overrides?.chargePricingUnitShortName,
  })

  mockedUsePropertyValues.mockReturnValue({
    amount: overrides?.amount ?? '',
    packageSize: overrides?.packageSize ?? '',
    freeUnits: overrides?.freeUnits ?? '',
  })
}

// --- Tests ---

describe('PackageCharge', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN it mounts with default values', () => {
      it('THEN should render the amount input field', () => {
        render(<PackageCharge />)

        const amountInput = screen.getByTestId('mock-amount-input')

        expect(amountInput).toBeInTheDocument()
      })

      it('THEN should render three form fields (amount, packageSize, freeUnits)', () => {
        render(<PackageCharge />)

        const inputs = screen.getAllByTestId('mock-text-input')

        // packageSize + freeUnits = 2 text inputs, plus 1 amount input
        expect(inputs).toHaveLength(2)
        expect(screen.getByTestId('mock-amount-input')).toBeInTheDocument()
      })

      it('THEN should render the info alert', () => {
        render(<PackageCharge />)

        const alert = screen.getByTestId(PACKAGE_CHARGE_EMPTY_ALERT_TEST_ID)

        expect(alert).toBeInTheDocument()
      })
    })

    describe('WHEN disabled is true', () => {
      it('THEN should pass disabled to the amount input field', () => {
        setupDefaultMocks({ disabled: true })

        render(<PackageCharge />)

        expect(mockAmountInputField).toHaveBeenCalledWith(
          expect.objectContaining({ disabled: true }),
          expect.anything(),
        )
      })

      it('THEN should pass disabled to the text input fields', () => {
        setupDefaultMocks({ disabled: true })

        render(<PackageCharge />)

        expect(mockTextInputField).toHaveBeenCalledWith(
          expect.objectContaining({ disabled: true }),
          expect.anything(),
        )
      })
    })
  })

  describe('GIVEN the alert content', () => {
    describe('WHEN packageSize is empty', () => {
      it('THEN should show the empty alert message', () => {
        setupDefaultMocks({ packageSize: '' })

        render(<PackageCharge />)

        const emptyAlert = screen.getByTestId(PACKAGE_CHARGE_EMPTY_ALERT_TEST_ID)

        expect(emptyAlert).toBeInTheDocument()
      })

      it('THEN should not show the filled alert message', () => {
        setupDefaultMocks({ packageSize: '' })

        render(<PackageCharge />)

        const filledAlert = screen.queryByTestId(PACKAGE_CHARGE_FILLED_ALERT_TEST_ID)

        expect(filledAlert).not.toBeInTheDocument()
      })
    })

    describe('WHEN packageSize has a value', () => {
      it('THEN should show the filled alert message', () => {
        setupDefaultMocks({ packageSize: '10' })

        render(<PackageCharge />)

        const filledAlert = screen.getByTestId(PACKAGE_CHARGE_FILLED_ALERT_TEST_ID)

        expect(filledAlert).toBeInTheDocument()
      })

      it('THEN should not show the empty alert message', () => {
        setupDefaultMocks({ packageSize: '10' })

        render(<PackageCharge />)

        const emptyAlert = screen.queryByTestId(PACKAGE_CHARGE_EMPTY_ALERT_TEST_ID)

        expect(emptyAlert).not.toBeInTheDocument()
      })
    })

    describe('WHEN packageSize has a value and freeUnits is set', () => {
      it('THEN should show the free units alert section', () => {
        setupDefaultMocks({ packageSize: '10', freeUnits: '5' })

        render(<PackageCharge />)

        const freeUnitsAlert = screen.getByTestId(PACKAGE_CHARGE_FREE_UNITS_ALERT_TEST_ID)

        expect(freeUnitsAlert).toBeInTheDocument()
      })
    })

    describe('WHEN packageSize has a value but freeUnits is empty', () => {
      it('THEN should not show the free units alert section', () => {
        setupDefaultMocks({ packageSize: '10', freeUnits: '' })

        render(<PackageCharge />)

        const freeUnitsAlert = screen.queryByTestId(PACKAGE_CHARGE_FREE_UNITS_ALERT_TEST_ID)

        expect(freeUnitsAlert).not.toBeInTheDocument()
      })
    })

    describe('WHEN packageSize has a value and freeUnits is zero string', () => {
      it('THEN should show the free units alert section because string "0" is truthy', () => {
        setupDefaultMocks({ packageSize: '10', freeUnits: '0' })

        render(<PackageCharge />)

        const freeUnitsAlert = screen.getByTestId(PACKAGE_CHARGE_FREE_UNITS_ALERT_TEST_ID)

        expect(freeUnitsAlert).toBeInTheDocument()
      })
    })
  })
})
