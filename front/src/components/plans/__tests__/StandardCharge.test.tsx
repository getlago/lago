import { screen } from '@testing-library/react'

import { type ChargeForm, useChargeFormContext } from '~/contexts/ChargeFormContext'
import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { StandardCharge } from '../StandardCharge'

const mockAmountInputField = jest.fn()

jest.mock('~/contexts/ChargeFormContext', () => ({
  useChargeFormContext: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const mockedUseChargeFormContext = useChargeFormContext as jest.MockedFunction<
  typeof useChargeFormContext
>

describe('StandardCharge', () => {
  beforeEach(() => {
    mockAmountInputField.mockClear()
    mockAmountInputField.mockImplementation((props: Record<string, unknown>) => (
      <input
        data-test="mock-amount-input"
        disabled={props.disabled as boolean}
        aria-label={props.label as string}
      />
    ))

    mockedUseChargeFormContext.mockReturnValue({
      form: {
        AppField: ({
          children,
        }: {
          name: string
          children: (field: Record<string, unknown>) => JSX.Element
        }) => <>{children({ AmountInputField: mockAmountInputField })}</>,
      } as unknown as ChargeForm,
      propertyCursor: 'properties',
      currency: CurrencyEnum.Eur,
      disabled: false,
      chargePricingUnitShortName: undefined,
    })
  })

  describe('GIVEN a StandardCharge component', () => {
    describe('WHEN it is rendered', () => {
      it('THEN should render the amount input field', () => {
        render(<StandardCharge />)

        const input = screen.getByTestId('mock-amount-input') as HTMLInputElement

        expect(input).toBeInTheDocument()
      })

      it('THEN should pass the currency to the amount input field', () => {
        render(<StandardCharge />)

        expect(mockAmountInputField).toHaveBeenCalledWith(
          expect.objectContaining({ currency: CurrencyEnum.Eur }),
          expect.anything(),
        )
      })
    })

    describe('WHEN disabled is false', () => {
      it('THEN should render the input as enabled', () => {
        render(<StandardCharge />)

        const input = screen.getByTestId('mock-amount-input') as HTMLInputElement

        expect(input.disabled).toBe(false)
      })
    })

    describe('WHEN disabled is true', () => {
      it('THEN should render the input as disabled', () => {
        mockedUseChargeFormContext.mockReturnValue({
          form: {
            AppField: ({
              children,
            }: {
              name: string
              children: (field: Record<string, unknown>) => JSX.Element
            }) => <>{children({ AmountInputField: mockAmountInputField })}</>,
          } as unknown as ChargeForm,
          propertyCursor: 'properties',
          currency: CurrencyEnum.Usd,
          disabled: true,
          chargePricingUnitShortName: undefined,
        })

        render(<StandardCharge />)

        const input = screen.getByTestId('mock-amount-input') as HTMLInputElement

        expect(input.disabled).toBe(true)
      })
    })

    describe('WHEN chargePricingUnitShortName is provided', () => {
      it('THEN should pass the unit short name to the amount input field', () => {
        mockedUseChargeFormContext.mockReturnValue({
          form: {
            AppField: ({
              children,
            }: {
              name: string
              children: (field: Record<string, unknown>) => JSX.Element
            }) => <>{children({ AmountInputField: mockAmountInputField })}</>,
          } as unknown as ChargeForm,
          propertyCursor: 'properties',
          currency: CurrencyEnum.Eur,
          disabled: false,
          chargePricingUnitShortName: 'credits',
        })

        render(<StandardCharge />)

        expect(mockAmountInputField).toHaveBeenCalled()
      })
    })
  })
})
