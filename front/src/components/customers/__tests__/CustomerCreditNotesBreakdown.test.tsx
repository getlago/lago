import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  CREDIT_NOTES_BREAKDOWN_ENTITY_CELL,
  CustomerCreditNotesBreakdown,
} from '../CustomerCreditNotesBreakdown'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useBillingEntitiesOptions', () => ({
  useBillingEntitiesOptions: () => ({
    options: [
      {
        id: 'be-1',
        value: 'entity-code-1',
        label: 'Entity One',
        name: 'Entity One',
        isDefault: true,
      },
      {
        id: 'be-2',
        value: 'entity-code-2',
        label: 'Entity Two',
        name: 'Entity Two',
        isDefault: false,
      },
    ],
    isLoading: false,
    defaultEntityCode: 'entity-code-1',
    hasMultipleEntities: true,
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

describe('CustomerCreditNotesBreakdown', () => {
  describe('GIVEN a list of credit note balances', () => {
    describe('WHEN balances mix non-zero and fully-consumed entries', () => {
      it('THEN should render a row for every bucket, including fully consumed ones', async () => {
        const balances = buildBalances([
          {
            currency: CurrencyEnum.Eur,
            billingEntityId: 'be-1',
            amountCents: '50000',
            creditsAvailableCount: 3,
          },
          {
            currency: CurrencyEnum.Usd,
            billingEntityId: 'be-2',
            amountCents: '0',
            creditsAvailableCount: 0,
          },
          {
            currency: CurrencyEnum.Gbp,
            billingEntityId: 'be-1',
            amountCents: '12000',
            creditsAvailableCount: 1,
          },
        ])

        render(
          <CustomerCreditNotesBreakdown
            creditNotesBalances={balances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const rows = screen.getAllByTestId(/^table-row-/)

        expect(rows).toHaveLength(3)
      })
    })

    describe('WHEN all balances are zero', () => {
      it('THEN should still render a row per bucket (kept for UX coherence with the CN list)', () => {
        const balances = buildBalances([
          {
            currency: CurrencyEnum.Eur,
            billingEntityId: 'be-1',
            amountCents: '0',
            creditsAvailableCount: 0,
          },
          {
            currency: CurrencyEnum.Usd,
            billingEntityId: 'be-2',
            amountCents: '0',
            creditsAvailableCount: 0,
          },
        ])

        render(
          <CustomerCreditNotesBreakdown
            creditNotesBalances={balances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const rows = screen.getAllByTestId(/^table-row-/)

        expect(rows).toHaveLength(2)
      })
    })

    describe('WHEN balances have non-zero amounts', () => {
      it.each([
        { currency: CurrencyEnum.Eur, amountCents: '50000', expectedCurrency: 'EUR' },
        { currency: CurrencyEnum.Gbp, amountCents: '12000', expectedCurrency: 'GBP' },
      ])(
        'THEN should display $expectedCurrency currency chip and formatted amount',
        ({ currency, amountCents, expectedCurrency }) => {
          const balances = buildBalances([
            { currency, billingEntityId: 'be-1', amountCents, creditsAvailableCount: 2 },
          ])

          render(
            <CustomerCreditNotesBreakdown
              creditNotesBalances={balances}
              customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
            />,
          )

          expect(screen.getByText(expectedCurrency)).toBeInTheDocument()
        },
      )
    })

    describe('WHEN a row has a billing entity id matching the options', () => {
      it('THEN should show the billing entity label', () => {
        const balances = buildBalances([
          {
            currency: CurrencyEnum.Eur,
            billingEntityId: 'be-1',
            amountCents: '10000',
            creditsAvailableCount: 1,
          },
        ])

        render(
          <CustomerCreditNotesBreakdown
            creditNotesBalances={balances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const entityCells = screen.getAllByTestId(CREDIT_NOTES_BREAKDOWN_ENTITY_CELL)

        expect(entityCells).toHaveLength(1)
        expect(entityCells[0]).toHaveTextContent('Entity One')
      })
    })

    describe('WHEN a row billing entity id is null and customer entity is provided', () => {
      it('THEN should show customer entity label as fallback', () => {
        const balances = buildBalances([
          {
            currency: CurrencyEnum.Eur,
            billingEntityId: '',
            amountCents: '10000',
            creditsAvailableCount: 1,
          },
        ])

        render(
          <CustomerCreditNotesBreakdown
            creditNotesBalances={balances}
            customerBillingEntity={{ id: 'cust-be', code: 'cust-code', name: 'Customer Entity' }}
          />,
        )

        const entityCells = screen.getAllByTestId(CREDIT_NOTES_BREAKDOWN_ENTITY_CELL)

        expect(entityCells[0]).toHaveTextContent('Customer Entity')
      })
    })
  })
})
