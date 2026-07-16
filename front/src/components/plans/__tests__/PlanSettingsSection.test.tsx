import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { ChargeModelEnum, CurrencyEnum, PlanInterval } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import { PlanFormType } from '~/hooks/plans/usePlanForm'
import { render } from '~/test-utils'

import {
  PLAN_SETTINGS_REMOVE_DESCRIPTION_TEST_ID,
  PlanSettingsSection,
} from '../PlanSettingsSection'
import { LocalFixedChargeInput, LocalUsageChargeInput, PlanFormInput } from '../types'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/components/taxes/TaxesSelectorSection', () => ({
  TaxesSelectorSection: ({
    onUpdate,
  }: {
    title: string
    description: string
    taxes: unknown[]
    comboboxSelector: string
    onUpdate: (taxes: unknown[]) => void
  }) => (
    <div data-test="taxes-selector-mock">
      <button
        data-test="trigger-tax-update"
        onClick={() => onUpdate([{ id: 'tax-1', code: 'vat', name: 'VAT', rate: 20 }])}
      >
        Update Taxes
      </button>
    </div>
  ),
}))

type TestFormValues = Pick<
  PlanFormInput,
  | 'name'
  | 'code'
  | 'description'
  | 'interval'
  | 'amountCurrency'
  | 'taxes'
  | 'fixedCharges'
  | 'charges'
  | 'billChargesMonthly'
  | 'billFixedChargesMonthly'
>

const DEFAULT_INITIAL_VALUES: TestFormValues = {
  name: '',
  code: '',
  description: '',
  interval: PlanInterval.Monthly,
  amountCurrency: CurrencyEnum.Usd,
  taxes: [],
  fixedCharges: [],
  charges: [],
  billChargesMonthly: false,
  billFixedChargesMonthly: false,
}

const createMockFixedCharge = (): LocalFixedChargeInput =>
  ({
    id: 'fixed-charge-1',
    chargeModel: ChargeModelEnum.Standard,
    invoiceDisplayName: 'Fixed Charge',
    payInAdvance: false,
    prorated: false,
    properties: { amount: '50' },
    addOn: { id: 'addon-1', name: 'Setup Fee', code: 'setup_fee' },
    taxes: [],
  }) as unknown as LocalFixedChargeInput

const createMockUsageCharge = (): LocalUsageChargeInput =>
  ({
    id: 'charge-1',
    chargeModel: ChargeModelEnum.Standard,
    invoiceDisplayName: 'Test Charge',
    payInAdvance: false,
    prorated: false,
    properties: { amount: '10' },
    taxes: [],
  }) as unknown as LocalUsageChargeInput

const PlanSettingsSectionWrapper = (
  props: Partial<Omit<React.ComponentProps<typeof PlanSettingsSection>, 'form'>> & {
    defaultValues?: TestFormValues
  },
) => {
  const { defaultValues, ...rest } = props
  const initialValues = defaultValues ?? DEFAULT_INITIAL_VALUES

  const form = useAppForm({
    defaultValues: initialValues,
  })

  return (
    <form.AppForm>
      <PlanSettingsSection form={form as unknown as PlanFormType} {...rest} />
    </form.AppForm>
  )
}

describe('PlanSettingsSection', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the name and code fields via NameAndCodeGroup', async () => {
        await act(() => render(<PlanSettingsSectionWrapper />))

        expect(screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')).toBeInTheDocument()
        expect(screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')).toBeInTheDocument()
      })

      it('THEN should render the interval selector', async () => {
        await act(() => render(<PlanSettingsSectionWrapper />))

        expect(screen.getByText('text_6661fc17337de3591e29e3d1')).toBeInTheDocument()
      })

      it('THEN should render the currency selector', async () => {
        await act(() => render(<PlanSettingsSectionWrapper />))

        expect(screen.getByText('text_642d5eb2783a2ad10d67032e')).toBeInTheDocument()
      })

      it('THEN should render the taxes section', async () => {
        await act(() => render(<PlanSettingsSectionWrapper />))

        expect(screen.getByTestId('taxes-selector-mock')).toBeInTheDocument()
      })

      it('THEN should show the add description button when no description', async () => {
        await act(() => render(<PlanSettingsSectionWrapper />))

        expect(screen.getByTestId('show-description')).toBeInTheDocument()
      })

      it('THEN should not show the description field when no description', async () => {
        await act(() => render(<PlanSettingsSectionWrapper />))

        expect(
          screen.queryByPlaceholderText('text_6661fc17337de3591e29e3c9'),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN defaultValues has a description', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should show the description field', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                description: 'Existing description',
              }}
            />,
          ),
        )

        const descInput = screen.getByPlaceholderText('text_6661fc17337de3591e29e3c9')

        expect(descInput).toBeInTheDocument()
        expect(descInput).toHaveValue('Existing description')
      })

      it('THEN should not show the add description button', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                description: 'Existing description',
              }}
            />,
          ),
        )

        expect(screen.queryByTestId('show-description')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the add description button is visible', () => {
    describe('WHEN the user clicks it', () => {
      it('THEN should show the description field', async () => {
        const user = userEvent.setup()

        await act(() => render(<PlanSettingsSectionWrapper />))

        await user.click(screen.getByTestId('show-description'))

        expect(screen.getByPlaceholderText('text_6661fc17337de3591e29e3c9')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the description field is visible', () => {
    describe('WHEN the user clicks the trash button to hide it', () => {
      it('THEN should hide the description field', async () => {
        const user = userEvent.setup()

        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                description: 'Some desc',
              }}
            />,
          ),
        )

        await user.click(screen.getByTestId(PLAN_SETTINGS_REMOVE_DESCRIPTION_TEST_ID))

        expect(
          screen.queryByPlaceholderText('text_6661fc17337de3591e29e3c9'),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the taxes section', () => {
    describe('WHEN the user updates taxes', () => {
      it('THEN should trigger the tax update without errors', async () => {
        const user = userEvent.setup()

        await act(() => render(<PlanSettingsSectionWrapper />))

        await user.click(screen.getByTestId('trigger-tax-update'))

        expect(screen.getByTestId('taxes-selector-mock')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component receives disabled props', () => {
    describe('WHEN isInSubscriptionForm is true', () => {
      it('THEN should disable the code field', async () => {
        await act(() => render(<PlanSettingsSectionWrapper isInSubscriptionForm={true} />))

        const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

        expect(codeInput).toBeDisabled()
      })
    })

    describe('WHEN isEdition is true and canBeEdited is false', () => {
      it('THEN should disable the code field', async () => {
        await act(() => render(<PlanSettingsSectionWrapper isEdition={true} canBeEdited={false} />))

        const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

        expect(codeInput).toBeDisabled()
      })
    })

    describe('WHEN isEdition is true and canBeEdited is true', () => {
      it('THEN should not disable the code field', async () => {
        await act(() => render(<PlanSettingsSectionWrapper isEdition={true} canBeEdited={true} />))

        const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

        expect(codeInput).not.toBeDisabled()
      })
    })
  })

  describe('GIVEN the name and code auto-sync behavior', () => {
    describe('WHEN the user types in the name field', () => {
      it('THEN should auto-generate the code', async () => {
        const user = userEvent.setup()

        await act(() => render(<PlanSettingsSectionWrapper />))

        const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
        const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

        await user.type(nameInput, 'My Plan')

        expect(codeInput).toHaveValue('my_plan')
      })
    })
  })

  describe('GIVEN defaultValues with pre-filled values', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should populate all fields with the initial values', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                name: 'Test Plan',
                code: 'test_plan',
                description: 'A test plan',
                interval: PlanInterval.Yearly,
                amountCurrency: CurrencyEnum.Eur,
              }}
            />,
          ),
        )

        expect(screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')).toHaveValue(
          'Test Plan',
        )
        expect(screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')).toHaveValue(
          'test_plan',
        )
        expect(screen.getByPlaceholderText('text_6661fc17337de3591e29e3c9')).toHaveValue(
          'A test plan',
        )
      })
    })
  })

  describe('GIVEN the currency field', () => {
    describe('WHEN subscriptionFormType is edition', () => {
      it('THEN should render the currency field as disabled', async () => {
        const { container } = await act(() =>
          render(
            <PlanSettingsSectionWrapper
              subscriptionFormType={FORM_TYPE_ENUM.edition as keyof typeof FORM_TYPE_ENUM}
            />,
          ),
        )

        const currencyInput = container.querySelector(
          '.MuiAutocomplete-root input',
        ) as HTMLInputElement

        expect(currencyInput).toBeDisabled()
      })
    })
  })

  describe('GIVEN the bill-monthly switches', () => {
    describe('WHEN the plan interval is Monthly', () => {
      it('THEN should not display any bill-monthly switch even with charges', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                interval: PlanInterval.Monthly,
                fixedCharges: [createMockFixedCharge()],
                charges: [createMockUsageCharge()],
              }}
            />,
          ),
        )

        expect(screen.queryByLabelText('billFixedChargesMonthly')).not.toBeInTheDocument()
        expect(screen.queryByLabelText('billChargesMonthly')).not.toBeInTheDocument()
      })
    })

    describe('WHEN the plan interval is Yearly with no charges', () => {
      it('THEN should not display any bill-monthly switch', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                interval: PlanInterval.Yearly,
              }}
            />,
          ),
        )

        expect(screen.queryByLabelText('billFixedChargesMonthly')).not.toBeInTheDocument()
        expect(screen.queryByLabelText('billChargesMonthly')).not.toBeInTheDocument()
      })
    })

    describe('WHEN the plan interval is Yearly with fixed charges only', () => {
      it('THEN should display only the billFixedChargesMonthly switch', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                interval: PlanInterval.Yearly,
                fixedCharges: [createMockFixedCharge()],
              }}
            />,
          ),
        )

        expect(screen.getByLabelText('billFixedChargesMonthly')).toBeInTheDocument()
        expect(screen.queryByLabelText('billChargesMonthly')).not.toBeInTheDocument()
      })
    })

    describe('WHEN the plan interval is Yearly with usage charges only', () => {
      it('THEN should display only the billChargesMonthly switch', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                interval: PlanInterval.Yearly,
                charges: [createMockUsageCharge()],
              }}
            />,
          ),
        )

        expect(screen.getByLabelText('billChargesMonthly')).toBeInTheDocument()
        expect(screen.queryByLabelText('billFixedChargesMonthly')).not.toBeInTheDocument()
      })
    })

    describe('WHEN the plan interval is Semiannual with both charge types', () => {
      it('THEN should display both bill-monthly switches', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                interval: PlanInterval.Semiannual,
                fixedCharges: [createMockFixedCharge()],
                charges: [createMockUsageCharge()],
              }}
            />,
          ),
        )

        expect(screen.getByLabelText('billFixedChargesMonthly')).toBeInTheDocument()
        expect(screen.getByLabelText('billChargesMonthly')).toBeInTheDocument()
      })
    })

    describe('WHEN isInSubscriptionForm is true with annual interval and charges', () => {
      it('THEN should render the switches as disabled', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              isInSubscriptionForm
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                interval: PlanInterval.Yearly,
                fixedCharges: [createMockFixedCharge()],
                charges: [createMockUsageCharge()],
              }}
            />,
          ),
        )

        expect(screen.getByLabelText('billFixedChargesMonthly')).toBeDisabled()
        expect(screen.getByLabelText('billChargesMonthly')).toBeDisabled()
      })
    })

    describe('WHEN isEdition is true and canBeEdited is false', () => {
      it('THEN should render the switches as disabled', async () => {
        await act(() =>
          render(
            <PlanSettingsSectionWrapper
              isEdition
              canBeEdited={false}
              defaultValues={{
                ...DEFAULT_INITIAL_VALUES,
                interval: PlanInterval.Yearly,
                fixedCharges: [createMockFixedCharge()],
                charges: [createMockUsageCharge()],
              }}
            />,
          ),
        )

        expect(screen.getByLabelText('billFixedChargesMonthly')).toBeDisabled()
        expect(screen.getByLabelText('billChargesMonthly')).toBeDisabled()
      })
    })
  })
})
