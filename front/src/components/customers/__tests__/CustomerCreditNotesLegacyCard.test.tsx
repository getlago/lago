import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  CustomerCreditNotesLegacyCard,
  LEGACY_CARD_CONTAINER,
} from '../CustomerCreditNotesLegacyCard'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const buildBalances = (
  overrides: Array<{
    currency: CurrencyEnum
    billingEntityId: string
    amountCents: string
    creditsAvailableCount: number
  }>,
) => overrides

describe('CustomerCreditNotesLegacyCard', () => {
  describe('GIVEN balances with multiple currencies', () => {
    const balances = buildBalances([
      {
        currency: CurrencyEnum.Eur,
        billingEntityId: 'be-1',
        amountCents: '50000',
        creditsAvailableCount: 3,
      },
      {
        currency: CurrencyEnum.Usd,
        billingEntityId: 'be-1',
        amountCents: '12000',
        creditsAvailableCount: 1,
      },
    ])

    describe('WHEN userCurrency matches one of the balances', () => {
      it('THEN should display the formatted amount for the matching currency', () => {
        render(
          <CustomerCreditNotesLegacyCard
            creditNotesBalances={balances}
            userCurrency={CurrencyEnum.Eur}
          />,
        )

        const container = screen.getByTestId(LEGACY_CARD_CONTAINER)

        // intlFormatNumber formats 500.00 EUR
        expect(container).toHaveTextContent('500')
      })
    })

    describe('WHEN userCurrency is not provided', () => {
      it('THEN should default to USD and display the USD amount', () => {
        render(<CustomerCreditNotesLegacyCard creditNotesBalances={balances} />)

        const container = screen.getByTestId(LEGACY_CARD_CONTAINER)

        // USD bucket has 12000 cents = $120.00
        expect(container).toHaveTextContent('120')
      })
    })

    describe('WHEN userCurrency is provided', () => {
      it('THEN should render the invoice count translation key for the selected currency', () => {
        render(
          <CustomerCreditNotesLegacyCard
            creditNotesBalances={balances}
            userCurrency={CurrencyEnum.Eur}
          />,
        )

        const container = screen.getByTestId(LEGACY_CARD_CONTAINER)

        // translate returns the key; the component passes count=3 for EUR bucket
        expect(container).toHaveTextContent('text_63725b30957fd5b26b308ddb')
      })
    })
  })

  describe('GIVEN empty balances', () => {
    describe('WHEN creditNotesBalances is undefined', () => {
      it('THEN should render gracefully with zero amount', () => {
        render(<CustomerCreditNotesLegacyCard />)

        const container = screen.getByTestId(LEGACY_CARD_CONTAINER)

        expect(container).toBeInTheDocument()
        // With no bucket found, amount defaults to 0 -> formatted as $0.00
        expect(container).toHaveTextContent('0')
      })
    })

    describe('WHEN creditNotesBalances is an empty array', () => {
      it('THEN should render gracefully with zero amount', () => {
        render(
          <CustomerCreditNotesLegacyCard
            creditNotesBalances={[]}
            userCurrency={CurrencyEnum.Eur}
          />,
        )

        const container = screen.getByTestId(LEGACY_CARD_CONTAINER)

        expect(container).toBeInTheDocument()
        expect(container).toHaveTextContent('0')
      })
    })
  })
})
