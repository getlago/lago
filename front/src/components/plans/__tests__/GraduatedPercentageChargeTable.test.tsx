import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { GRADUATED_PERCENTAGE_CHARGE_TABLE_ADD_TIER_TEST_ID } from '../chargeTestIds'
import { GraduatedPercentageChargeTable } from '../GraduatedPercentageChargeTable'

// --- Mocks ---

const mockAddRange = jest.fn()
const mockDeleteRange = jest.fn()
const mockHandleUpdate = jest.fn()

const mockForm = {
  store: {
    getState: () => ({ values: {} }),
  },
  setFieldValue: jest.fn(),
  AppField: ({ children }: { children: (field: Record<string, unknown>) => React.ReactNode }) =>
    children({
      TextInputField: (props: Record<string, unknown>) => <input data-test={props['data-test']} />,
      AmountInputField: (props: Record<string, unknown>) => (
        <input data-test={props['data-test']} />
      ),
    }),
}

jest.mock('~/contexts/ChargeFormContext', () => ({
  useChargeFormContext: jest.fn(() => ({
    form: mockForm,
    propertyCursor: 'properties',
    currency: 'USD',
    disabled: false,
    chargePricingUnitShortName: undefined,
  })),
  usePropertyValues: jest.fn(),
}))

jest.mock('~/hooks/plans/useGraduatedPercentageChargeForm', () => ({
  useGraduatedPercentageChargeForm: jest.fn(() => ({
    addRange: mockAddRange,
    deleteRange: mockDeleteRange,
    handleUpdate: mockHandleUpdate,
    tableDatas: [
      {
        fromValue: '0',
        toValue: '1',
        rate: '5',
        flatAmount: '10',
        disabledDelete: true,
      },
      {
        fromValue: '2',
        toValue: null,
        rate: '3',
        flatAmount: '20',
        disabledDelete: false,
      },
    ],
    infosCalculation: [
      { units: 1, rate: 5, flatAmount: 10 },
      { units: 1, rate: 3, flatAmount: 20 },
    ],
  })),
}))

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((store, selector) => {
    if (typeof store === 'object' && store !== null && 'getState' in store) {
      return selector(store.getState())
    }
    return undefined
  }),
  createFormHookContexts: jest.fn(() => ({
    fieldContext: {},
    useFieldContext: jest.fn(),
    formContext: {},
    useFormContext: jest.fn(),
  })),
}))

jest.mock('~/components/form/FieldErrorTooltip', () => ({
  FieldErrorTooltip: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (currency: string) => (currency === 'USD' ? '$' : currency),
  intlFormatNumber: (value: number, opts?: { style?: string }) => {
    if (opts?.style === 'percent') return `${value * 100}%`
    return String(value)
  },
}))

// --- Tests ---

describe('GraduatedPercentageChargeTable', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered with default tiers', () => {
    describe('WHEN two tiers are provided', () => {
      it('THEN should render both tier rows', () => {
        render(<GraduatedPercentageChargeTable />)

        expect(screen.getByTestId('row-0')).toBeInTheDocument()
        expect(screen.getByTestId('row-1')).toBeInTheDocument()
      })

      it('THEN should display the from values for each tier', () => {
        render(<GraduatedPercentageChargeTable />)

        expect(screen.getByText('0')).toBeInTheDocument()
        expect(screen.getByText('2')).toBeInTheDocument()
      })

      it('THEN should display infinity symbol for the last tier to value', () => {
        render(<GraduatedPercentageChargeTable />)

        expect(screen.getByText('\u221E')).toBeInTheDocument()
      })

      it('THEN should render the add tier button', () => {
        render(<GraduatedPercentageChargeTable />)

        expect(
          screen.getByTestId(GRADUATED_PERCENTAGE_CHARGE_TABLE_ADD_TIER_TEST_ID),
        ).toBeInTheDocument()
      })

      it('THEN should render the info alert', () => {
        render(<GraduatedPercentageChargeTable />)

        expect(screen.getByTestId('alert-type-info')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user interacts with the table', () => {
    describe('WHEN the add tier button is clicked', () => {
      it('THEN should call addRange', async () => {
        const user = userEvent.setup()

        render(<GraduatedPercentageChargeTable />)

        await user.click(screen.getByTestId(GRADUATED_PERCENTAGE_CHARGE_TABLE_ADD_TIER_TEST_ID))

        expect(mockAddRange).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN the component is disabled', () => {
    describe('WHEN disabled is true', () => {
      it('THEN should render the add tier button as disabled', () => {
        const { useChargeFormContext } = jest.requireMock('~/contexts/ChargeFormContext')

        useChargeFormContext.mockReturnValue({
          form: mockForm,
          propertyCursor: 'properties',
          currency: 'USD',
          disabled: true,
          chargePricingUnitShortName: undefined,
        })

        render(<GraduatedPercentageChargeTable />)

        const addButton = screen.getByTestId(GRADUATED_PERCENTAGE_CHARGE_TABLE_ADD_TIER_TEST_ID)

        expect(addButton).toBeDisabled()
      })
    })
  })
})
