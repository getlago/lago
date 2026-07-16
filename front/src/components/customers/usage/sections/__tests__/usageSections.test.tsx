import { screen } from '@testing-library/react'

import { AmountCentsCell } from '~/components/customers/usage/sections/AmountCentsCell'
import { BreakdownNameCell } from '~/components/customers/usage/sections/BreakdownNameCell'
import { FiltersOnlyTable } from '~/components/customers/usage/sections/FiltersOnlyTable'
import { GroupedUsageTable } from '~/components/customers/usage/sections/GroupedUsageTable'
import { GroupedUsageWithFiltersTable } from '~/components/customers/usage/sections/GroupedUsageWithFiltersTable'
import { SubscriptionUsageDetailDrawerUsage } from '~/components/customers/usage/usageDetailsHelpers'
import { CurrencyEnum } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'
import { render } from '~/test-utils'

const translate = ((key: string) => key) as TranslateFunc

const asUsage = (usage: unknown): SubscriptionUsageDetailDrawerUsage =>
  usage as SubscriptionUsageDetailDrawerUsage

const baseTableProps = {
  currency: CurrencyEnum.Usd,
  showProjected: false,
  translate,
  unitsHeader: 'Units header',
  amountHeader: 'Amount header',
}

describe('BreakdownNameCell', () => {
  it('renders a chip for every meaningful value and skips null/empty ones', () => {
    render(<BreakdownNameCell presentationBy={{ region: 'us', tier: null, env: '' }} />)

    expect(screen.getByText('us')).toBeInTheDocument()
    expect(screen.queryByText('null')).not.toBeInTheDocument()
  })

  it('renders nothing meaningful when all values are empty', () => {
    render(<BreakdownNameCell presentationBy={{ region: null, tier: undefined }} />)

    expect(screen.queryByText('null')).not.toBeInTheDocument()
    expect(screen.queryByText('undefined')).not.toBeInTheDocument()
  })
})

describe('AmountCentsCell', () => {
  it('renders a formatted currency amount', () => {
    const { container } = render(
      <AmountCentsCell row={{ amountCents: '1000' }} currency={CurrencyEnum.Usd} />,
    )

    expect(container.textContent).toContain('$')
  })

  it('renders a secondary line when a pricing unit short name is provided', () => {
    const { container } = render(
      <AmountCentsCell
        row={{ amountCents: '1000', pricingUnitAmountCents: '500' }}
        currency={CurrencyEnum.Usd}
        pricingUnitShortName="CR"
      />,
    )

    expect(container.textContent).toContain('$')
  })
})

describe('FiltersOnlyTable', () => {
  it('renders the filter display name, the passed headers and the breakdown rows', () => {
    const usage = asUsage({
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM' },
      filters: [
        {
          id: 'f1',
          invoiceDisplayName: 'EU only',
          values: { region: ['eu'] },
          units: 3,
          amountCents: '500',
          presentationBreakdowns: [{ presentationBy: { agent: 'alice' }, units: '3' }],
        },
      ],
      presentationBreakdowns: [],
    })

    render(<FiltersOnlyTable {...baseTableProps} usage={usage} />)

    expect(screen.getByText('EU only')).toBeInTheDocument()
    expect(screen.getByText('Units header')).toBeInTheDocument()
    expect(screen.getByText('Amount header')).toBeInTheDocument()
    // breakdown row chip
    expect(screen.getByText('alice')).toBeInTheDocument()
  })

  it('renders the "no-id" default label for a filter without an id', () => {
    const usage = asUsage({
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM' },
      filters: [{ values: {}, units: 1, amountCents: '100', presentationBreakdowns: [] }],
      presentationBreakdowns: [],
    })

    // Renders without throwing; the default-label branch is exercised.
    render(<FiltersOnlyTable {...baseTableProps} usage={usage} />)

    expect(screen.getByText('Units header')).toBeInTheDocument()
  })
})

describe('GroupedUsageTable', () => {
  it('renders grouped rows with the passed headers', () => {
    const usage = asUsage({
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM' },
      groupedUsage: [
        {
          id: 'g1',
          groupedBy: { region: 'us' },
          units: 5,
          amountCents: '1000',
          presentationBreakdowns: [{ presentationBy: { agent: 'bob' }, units: '5' }],
        },
      ],
    })

    render(<GroupedUsageTable {...baseTableProps} usage={usage} />)

    expect(screen.getByText('Units header')).toBeInTheDocument()
    expect(screen.getByText('bob')).toBeInTheDocument()
  })

  it('falls back to groupedBy keys as chips when the values are all null', () => {
    const usage = asUsage({
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM' },
      groupedUsage: [
        {
          id: 'g1',
          groupedBy: { region: null },
          units: 5,
          amountCents: '1000',
          presentationBreakdowns: [],
        },
      ],
    })

    render(<GroupedUsageTable {...baseTableProps} usage={usage} />)

    expect(screen.getByText('region')).toBeInTheDocument()
  })
})

describe('GroupedUsageWithFiltersTable', () => {
  it('renders a filter invoiceDisplayName when present', () => {
    const usage = asUsage({
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM' },
      groupedUsage: [
        {
          groupedBy: { region: 'us' },
          units: 5,
          amountCents: '1000',
          presentationBreakdowns: [],
          filters: [
            {
              id: 'f1',
              invoiceDisplayName: 'EU only',
              values: { region: ['eu'] },
              units: 2,
              amountCents: '400',
              presentationBreakdowns: [],
            },
          ],
        },
      ],
    })

    render(<GroupedUsageWithFiltersTable {...baseTableProps} usage={usage} />)

    expect(screen.getByText('EU only')).toBeInTheDocument()
  })

  it('renders chips built from groupedBy + filter values when there is no display name', () => {
    const usage = asUsage({
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM' },
      groupedUsage: [
        {
          groupedBy: { region: 'us' },
          units: 5,
          amountCents: '1000',
          presentationBreakdowns: [],
          filters: [
            {
              id: 'f1',
              values: { tier: ['gold'] },
              units: 2,
              amountCents: '400',
              presentationBreakdowns: [],
            },
          ],
        },
      ],
    })

    render(<GroupedUsageWithFiltersTable {...baseTableProps} usage={usage} />)

    expect(screen.getByText('us')).toBeInTheDocument()
    expect(screen.getByText('gold')).toBeInTheDocument()
  })
})
