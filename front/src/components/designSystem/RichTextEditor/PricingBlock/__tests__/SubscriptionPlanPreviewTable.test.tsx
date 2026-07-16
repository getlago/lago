import { screen } from '@testing-library/react'

import type { PlanPreviewData } from '~/core/serializers/buildPlanPreviewData'
import { CurrencyEnum, PlanInterval } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID,
  SubscriptionPlanPreviewTable,
} from '../SubscriptionPlanPreviewTable'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockTranslate = (key: string) => key

const data: PlanPreviewData = {
  rows: [
    {
      kind: 'main',
      rowType: 'subscriptionFee',
      name: undefined,
      interval: PlanInterval.Monthly,
      timing: 'beginningOfPeriod',
      units: { type: 'count', value: 1 },
      // display units (dollars): $130.50 — must NOT be passed through deserializeAmount
      price: { type: 'displayAmount', amount: '130.50' },
    },
    {
      kind: 'main',
      rowType: 'usageCharge',
      name: 'API calls',
      interval: PlanInterval.Monthly,
      timing: 'endOfPeriod',
      units: { type: 'usageBased' },
      price: { type: 'variesWithUsage' },
    },
    {
      kind: 'detail',
      label: { type: 'tierRange', from: 1, to: 10 },
      qualifier: { type: 'perUnit' },
      value: { type: 'displayAmount', amount: '0.10' },
    },
  ],
}

const defaultProps = {
  data,
  translate: mockTranslate,
  currency: CurrencyEnum.Usd,
}

describe('SubscriptionPlanPreviewTable', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered with plan data', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the table container with correct data-test id', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        expect(screen.getByTestId(SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the preview table with correct testid', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        expect(screen.getByTestId('preview-table-subscription-plan-preview')).toBeInTheDocument()
      })

      it('THEN should render 4 header columns', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        const table = screen.getByTestId('preview-table-subscription-plan-preview')
        const headerCells = table.querySelectorAll('th')

        expect(headerCells).toHaveLength(4)
      })

      it('THEN should render the correct number of rows matching fixture', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        const rows = screen.getAllByTestId(/^preview-table-subscription-plan-preview-row-/)

        expect(rows).toHaveLength(data.rows.length)
      })

      it('THEN should display the usage charge name', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        expect(screen.getByText('API calls')).toBeInTheDocument()
      })

      it('THEN should render the subscription fee as display-unit dollars (not 100x smaller)', () => {
        // The subscription fee fixture is { type: 'displayAmount', amount: '130.50' }.
        // If deserializeAmount were applied it would render ~$1.31 — this assertion
        // would fail, catching any regression that reintroduces the 100× bug.
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        expect(screen.getByText(/130\.50/)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple rows', () => {
    describe('WHEN rendered with 3 rows (2 main + 1 detail)', () => {
      it('THEN should render 3 table rows total', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        const rows = screen.getAllByTestId(/^preview-table-subscription-plan-preview-row-/)

        expect(rows).toHaveLength(3)
      })
    })
  })

  describe('GIVEN a row with an explicit name', () => {
    describe('WHEN the usage charge has a name', () => {
      it('THEN should display the charge name text', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        expect(screen.getByText('API calls')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the footer is rendered', () => {
    describe('WHEN the table renders', () => {
      it('THEN the outer container and preview table are both present', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} />)

        expect(screen.getByTestId(SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId('preview-table-subscription-plan-preview')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a locale is provided', () => {
    describe('WHEN locale is set', () => {
      it('THEN should render the table without errors', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} locale={'fr' as never} />)

        expect(screen.getByTestId(SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN different currency values', () => {
    describe('WHEN EUR currency is used', () => {
      it('THEN should render the table without errors', () => {
        render(<SubscriptionPlanPreviewTable {...defaultProps} currency={CurrencyEnum.Eur} />)

        expect(screen.getByTestId(SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a charge with detail rows', () => {
    describe('WHEN a main row is followed by a detail row', () => {
      const grouped: PlanPreviewData = {
        rows: [
          {
            kind: 'main',
            rowType: 'usageCharge',
            name: 'API calls',
            interval: PlanInterval.Monthly,
            timing: 'endOfPeriod',
            units: { type: 'usageBased' },
            price: { type: 'variesWithUsage' },
          },
          {
            kind: 'detail',
            label: { type: 'tierRange', from: 1, to: 10 },
            qualifier: { type: 'perUnit' },
            value: { type: 'displayAmount', amount: '0.10' },
          },
          {
            kind: 'main',
            rowType: 'subscriptionFee',
            name: undefined,
            interval: PlanInterval.Monthly,
            timing: 'beginningOfPeriod',
            units: { type: 'count', value: 1 },
            price: { type: 'displayAmount', amount: '130.50' },
          },
        ],
      }

      it('THEN the main row before a detail row has no bottom divider', () => {
        render(
          <SubscriptionPlanPreviewTable
            data={grouped}
            translate={mockTranslate}
            currency={CurrencyEnum.Usd}
          />,
        )

        const cell = screen
          .getByTestId('preview-table-subscription-plan-preview-row-0')
          .querySelector('td')

        // grouped with the detail row below → no bottom divider rendered
        expect(cell?.style.borderBottomWidth).toBe('')
      })

      it('THEN the detail row that ends the group keeps its bottom divider', () => {
        render(
          <SubscriptionPlanPreviewTable
            data={grouped}
            translate={mockTranslate}
            currency={CurrencyEnum.Usd}
          />,
        )

        const cell = screen
          .getByTestId('preview-table-subscription-plan-preview-row-1')
          .querySelector('td')

        // group ends here (next row is a main row) → grey-300 divider rendered
        expect(cell?.style.borderBottomWidth).toBe('1px')
        expect(cell?.style.borderBottom).toContain('rgb(217, 222, 231)')
      })

      it('THEN the final row keeps its bottom divider', () => {
        render(
          <SubscriptionPlanPreviewTable
            data={grouped}
            translate={mockTranslate}
            currency={CurrencyEnum.Usd}
          />,
        )

        const cell = screen
          .getByTestId('preview-table-subscription-plan-preview-row-2')
          .querySelector('td')

        expect(cell?.style.borderBottomWidth).toBe('1px')
      })
    })
  })

  describe('GIVEN flat-fee tier rows', () => {
    // Resolving translate so we can assert the rendered, interpolated label.
    // Keys are the generated ids for the three flat-fee variants.
    const FLAT_FEE_TEMPLATES: Record<string, string> = {
      text_17822898603051pryf16s23k: 'Flat fee for first {{to}} units',
      text_1782289860305xi20ikioh8l: 'Flat fee for {{from}} to {{to}} units',
      text_1782289860305wlllob2k8n0: 'Flat fee for {{from}} units and above',
    }
    const resolveTranslate = ((key: string, vars?: Record<string, unknown>) => {
      const template = FLAT_FEE_TEMPLATES[key] ?? key

      return vars
        ? Object.entries(vars).reduce(
            (acc, [k, v]) => acc.replaceAll(`{{${k}}}`, String(v)),
            template,
          )
        : template
    }) as unknown as typeof mockTranslate

    const flatFeeRow = (from: number, to?: number): PlanPreviewData['rows'][number] => ({
      kind: 'detail',
      label: { type: 'flatFeeForTier', from, to },
      qualifier: { type: 'flatFee' },
      value: { type: 'displayAmount', amount: '10.00' },
    })

    const flatFeeData: PlanPreviewData = {
      rows: [flatFeeRow(0, 10), flatFeeRow(11, 100), flatFeeRow(101)],
    }

    it('THEN the first tier (from 0) renders the "first N units" variant', () => {
      render(
        <SubscriptionPlanPreviewTable
          data={flatFeeData}
          translate={resolveTranslate}
          currency={CurrencyEnum.Usd}
        />,
      )

      expect(screen.getByText('Flat fee for first 10 units')).toBeInTheDocument()
    })

    it('THEN a bounded middle tier renders the "X to Y units" variant', () => {
      render(
        <SubscriptionPlanPreviewTable
          data={flatFeeData}
          translate={resolveTranslate}
          currency={CurrencyEnum.Usd}
        />,
      )

      expect(screen.getByText('Flat fee for 11 to 100 units')).toBeInTheDocument()
    })

    it('THEN the open-ended top tier renders the "N units and above" variant', () => {
      render(
        <SubscriptionPlanPreviewTable
          data={flatFeeData}
          translate={resolveTranslate}
          currency={CurrencyEnum.Usd}
        />,
      )

      expect(screen.getByText('Flat fee for 101 units and above')).toBeInTheDocument()
    })
  })
})
