import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { CurrencyEnum } from '~/generated/graphql'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { render } from '~/test-utils'

import {
  BREAKDOWN_ENTITY_CELL,
  BREAKDOWN_REQUEST_PAYMENT_BUTTON,
  CustomerInvoiceBalancesBreakdown,
} from '../CustomerInvoiceBalancesBreakdown'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: jest.fn(() => ({
    organization: { defaultCurrency: 'USD' as const },
    hasFeatureFlag: jest.fn(() => true),
  })),
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

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: jest.fn(() => ({ customerId: 'cust-123' })),
  generatePath: jest.fn((route: string, params: { customerId: string }) =>
    route.replace(':customerId', params.customerId),
  ),
}))

jest.mock('~/core/router', () => ({
  ...jest.requireActual('~/core/router'),
  useNavigate: jest.fn(() => jest.fn()),
  CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE: '/customers/:customerId/request-overdue-payment',
}))

const buildGrossRevenues = (
  items: Array<{
    amountCents: string
    currency: CurrencyEnum
    invoicesCount: string
    billingEntityId?: string | null
  }>,
) =>
  items.map((item) => ({
    ...item,
    month: '2024-01',
    billingEntityId: item.billingEntityId ?? null,
  }))

const buildOverdueBalances = (
  items: Array<{
    amountCents: string
    currency: CurrencyEnum
    lagoInvoiceIds: string[]
    billingEntityId?: string | null
  }>,
) =>
  items.map((item) => ({
    ...item,
    billingEntityId: item.billingEntityId ?? null,
  }))

describe('CustomerInvoiceBalancesBreakdown', () => {
  describe('GIVEN gross revenues and overdue balances with different currencies and billing entities', () => {
    describe('WHEN rendering the breakdown table', () => {
      it('THEN should render rows aggregated by currency and billingEntityId', () => {
        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '2',
            billingEntityId: 'be-1',
          },
          {
            amountCents: '5000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '1',
            billingEntityId: 'be-1',
          },
          {
            amountCents: '20000',
            currency: CurrencyEnum.Eur,
            invoicesCount: '3',
            billingEntityId: 'be-2',
          },
        ])

        const overdueBalances = buildOverdueBalances([
          {
            amountCents: '3000',
            currency: CurrencyEnum.Usd,
            lagoInvoiceIds: ['inv-1'],
            billingEntityId: 'be-1',
          },
          {
            amountCents: '0',
            currency: CurrencyEnum.Eur,
            lagoInvoiceIds: [],
            billingEntityId: 'be-2',
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={overdueBalances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const rows = screen.getAllByTestId(/^table-row-/)

        expect(rows).toHaveLength(2)
      })
    })
  })

  describe('GIVEN a row with overdueAmount equal to 0', () => {
    describe('WHEN the breakdown is rendered', () => {
      it('THEN should disable the request payment button', () => {
        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '1',
            billingEntityId: 'be-1',
          },
        ])

        const overdueBalances = buildOverdueBalances([
          {
            amountCents: '0',
            currency: CurrencyEnum.Usd,
            lagoInvoiceIds: [],
            billingEntityId: 'be-1',
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={overdueBalances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const buttons = screen.getAllByTestId(BREAKDOWN_REQUEST_PAYMENT_BUTTON)

        expect(buttons[0]).toBeDisabled()
      })
    })
  })

  describe('GIVEN a row with overdueAmount greater than 0', () => {
    describe('WHEN the breakdown is rendered', () => {
      it('THEN should enable the request payment button', () => {
        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '1',
            billingEntityId: 'be-1',
          },
        ])

        const overdueBalances = buildOverdueBalances([
          {
            amountCents: '5000',
            currency: CurrencyEnum.Usd,
            lagoInvoiceIds: ['inv-1'],
            billingEntityId: 'be-1',
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={overdueBalances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const buttons = screen.getAllByTestId(BREAKDOWN_REQUEST_PAYMENT_BUTTON)

        expect(buttons[0]).not.toBeDisabled()
      })
    })
  })

  describe('GIVEN a row with a matching billing entity', () => {
    describe('WHEN the entity cell is rendered', () => {
      it('THEN should show the billing entity label', () => {
        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '1',
            billingEntityId: 'be-1',
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={[]}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const entityCells = screen.getAllByTestId(BREAKDOWN_ENTITY_CELL)

        expect(entityCells[0]).toHaveTextContent('Entity One')
      })
    })
  })

  describe('GIVEN a row with null billingEntityId and a customer billing entity', () => {
    describe('WHEN the entity cell is rendered', () => {
      it('THEN should show customer entity label as fallback', () => {
        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '1',
            billingEntityId: null,
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={[]}
            customerBillingEntity={{ id: 'cust-be', code: 'cust-code', name: 'Customer Entity' }}
          />,
        )

        const entityCells = screen.getAllByTestId(BREAKDOWN_ENTITY_CELL)

        expect(entityCells[0]).toHaveTextContent('Customer Entity')
      })
    })
  })

  describe('GIVEN both feature flags are enabled', () => {
    const mockNavigate = jest.fn()

    beforeEach(() => {
      mockNavigate.mockClear()

      jest.mocked(useOrganizationInfos).mockReturnValue({
        hasFeatureFlag: jest.fn(() => true),
        organization: { defaultCurrency: 'USD' as const },
      } as unknown as ReturnType<typeof useOrganizationInfos>)

      // Override navigate mock to capture calls
      const routerMock = jest.requireMock('~/core/router')

      routerMock.useNavigate = jest.fn(() => mockNavigate)
    })

    describe('WHEN rendering rows with different currencies AND different billingEntityIds', () => {
      it('THEN should correctly aggregate and display all rows', () => {
        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '2',
            billingEntityId: 'be-1',
          },
          {
            amountCents: '20000',
            currency: CurrencyEnum.Eur,
            invoicesCount: '3',
            billingEntityId: 'be-2',
          },
          {
            amountCents: '5000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '1',
            billingEntityId: 'be-2',
          },
        ])

        const overdueBalances = buildOverdueBalances([
          {
            amountCents: '3000',
            currency: CurrencyEnum.Usd,
            lagoInvoiceIds: ['inv-1'],
            billingEntityId: 'be-1',
          },
          {
            amountCents: '7000',
            currency: CurrencyEnum.Eur,
            lagoInvoiceIds: ['inv-2', 'inv-3'],
            billingEntityId: 'be-2',
          },
          {
            amountCents: '1000',
            currency: CurrencyEnum.Usd,
            lagoInvoiceIds: ['inv-4'],
            billingEntityId: 'be-2',
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={overdueBalances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const rows = screen.getAllByTestId(/^table-row-/)

        // 3 distinct (currency, billingEntityId) combos: USD|be-1, EUR|be-2, USD|be-2
        expect(rows).toHaveLength(3)
      })
    })

    describe('WHEN clicking the Request payment button on a row with overdue balance', () => {
      it('THEN should navigate with both currency and billingEntityId params', async () => {
        const user = userEvent.setup()

        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '2',
            billingEntityId: 'be-1',
          },
        ])

        const overdueBalances = buildOverdueBalances([
          {
            amountCents: '5000',
            currency: CurrencyEnum.Usd,
            lagoInvoiceIds: ['inv-1'],
            billingEntityId: 'be-1',
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={overdueBalances}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const buttons = screen.getAllByTestId(BREAKDOWN_REQUEST_PAYMENT_BUTTON)

        await user.click(buttons[0])

        expect(mockNavigate).toHaveBeenCalledWith(
          expect.objectContaining({
            search: expect.stringContaining('currency=USD'),
          }),
        )
        expect(mockNavigate).toHaveBeenCalledWith(
          expect.objectContaining({
            search: expect.stringContaining('billingEntityId=be-1'),
          }),
        )
      })
    })

    describe('WHEN rendering entity cells', () => {
      it('THEN should display billing entity labels for each row', () => {
        const grossRevenues = buildGrossRevenues([
          {
            amountCents: '10000',
            currency: CurrencyEnum.Usd,
            invoicesCount: '2',
            billingEntityId: 'be-1',
          },
          {
            amountCents: '20000',
            currency: CurrencyEnum.Eur,
            invoicesCount: '3',
            billingEntityId: 'be-2',
          },
        ])

        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={grossRevenues}
            overdueBalances={[]}
            customerBillingEntity={{ id: 'be-1', code: 'entity-code-1', name: 'Entity One' }}
          />,
        )

        const entityCells = screen.getAllByTestId(BREAKDOWN_ENTITY_CELL)

        expect(entityCells).toHaveLength(2)
      })
    })
  })

  describe('GIVEN isLoading is true', () => {
    describe('WHEN the breakdown is rendered', () => {
      it('THEN should not render data rows', () => {
        render(
          <CustomerInvoiceBalancesBreakdown
            grossRevenues={[]}
            overdueBalances={[]}
            customerBillingEntity={null}
            isLoading
          />,
        )

        expect(screen.queryByTestId(/^table-row-/)).not.toBeInTheDocument()
      })
    })
  })
})
