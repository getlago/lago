import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { LocalPricingUnitType, LocalUsageChargeInput } from '../../types'
import {
  CustomPricingUnitSelector,
  PRICING_UNIT_COMBOBOX_TEST_ID,
  PRICING_UNIT_CONVERSION_RATE_TEST_ID,
} from '../CustomPricingUnitSelector'

// --- Mocks ---

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (currency: string) => currency,
}))

jest.mock('~/hooks/plans/useCustomPricingUnits', () => ({
  useCustomPricingUnits: () => ({
    hasAnyPricingUnitConfigured: true,
    pricingUnits: [
      { id: '1', name: 'Credits', code: 'credits', shortName: 'CR' },
      { id: '2', name: 'Tokens', code: 'tokens', shortName: 'TK' },
    ],
  }),
}))

// --- Helpers ---

const defaultProps = {
  currency: CurrencyEnum.Usd,
  isInSubscriptionForm: false,
  disabled: false,
  handleUpdate: jest.fn(),
}

const buildLocalCharge = (
  overrides?: Partial<LocalUsageChargeInput['appliedPricingUnit']>,
): LocalUsageChargeInput =>
  ({
    appliedPricingUnit: overrides
      ? {
          code: 'credits',
          shortName: 'CR',
          type: LocalPricingUnitType.Custom,
          conversionRate: '1.5',
          ...overrides,
        }
      : undefined,
  }) as unknown as LocalUsageChargeInput

// --- Tests ---

describe('CustomPricingUnitSelector', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN it mounts', () => {
      it('THEN should render the pricing unit combobox', () => {
        render(<CustomPricingUnitSelector {...defaultProps} localCharge={buildLocalCharge()} />)

        const combobox = screen.getByTestId(PRICING_UNIT_COMBOBOX_TEST_ID)

        expect(combobox).toBeInTheDocument()
      })
    })

    describe('WHEN disabled is true', () => {
      it('THEN should render the combobox as disabled', () => {
        render(
          <CustomPricingUnitSelector
            {...defaultProps}
            disabled={true}
            localCharge={buildLocalCharge()}
          />,
        )

        const combobox = screen.getByTestId(PRICING_UNIT_COMBOBOX_TEST_ID)
        const input = combobox.querySelector('input') as HTMLInputElement

        expect(input.disabled).toBe(true)
      })
    })

    describe('WHEN isInSubscriptionForm is true', () => {
      it('THEN should render the combobox as disabled', () => {
        render(
          <CustomPricingUnitSelector
            {...defaultProps}
            isInSubscriptionForm={true}
            localCharge={buildLocalCharge()}
          />,
        )

        const combobox = screen.getByTestId(PRICING_UNIT_COMBOBOX_TEST_ID)
        const input = combobox.querySelector('input') as HTMLInputElement

        expect(input.disabled).toBe(true)
      })
    })
  })

  describe('GIVEN the conversion rate section', () => {
    describe('WHEN the applied pricing unit type is custom', () => {
      it('THEN should show the conversion rate section', () => {
        render(
          <CustomPricingUnitSelector
            {...defaultProps}
            localCharge={buildLocalCharge({ type: LocalPricingUnitType.Custom })}
          />,
        )

        const conversionRate = screen.getByTestId(PRICING_UNIT_CONVERSION_RATE_TEST_ID)

        expect(conversionRate).toBeInTheDocument()
      })
    })

    describe('WHEN the applied pricing unit type is fiat', () => {
      it('THEN should not show the conversion rate section', () => {
        render(
          <CustomPricingUnitSelector
            {...defaultProps}
            localCharge={buildLocalCharge({ type: LocalPricingUnitType.Fiat })}
          />,
        )

        const conversionRate = screen.queryByTestId(PRICING_UNIT_CONVERSION_RATE_TEST_ID)

        expect(conversionRate).not.toBeInTheDocument()
      })
    })

    describe('WHEN no pricing unit is applied', () => {
      it('THEN should not show the conversion rate section', () => {
        const localCharge = { appliedPricingUnit: undefined } as unknown as LocalUsageChargeInput

        render(<CustomPricingUnitSelector {...defaultProps} localCharge={localCharge} />)

        const conversionRate = screen.queryByTestId(PRICING_UNIT_CONVERSION_RATE_TEST_ID)

        expect(conversionRate).not.toBeInTheDocument()
      })
    })
  })
})
