import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { RecurringThresholdsTable } from '../RecurringThresholdsTable'

// Mock hooks
jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('RecurringThresholdsTable', () => {
  const defaultThresholds = [
    {
      id: 'threshold-1',
      amountCents: '50000',
      recurring: true,
      thresholdDisplayName: 'Recurring threshold',
    },
  ]

  it('renders the recurring threshold', () => {
    render(<RecurringThresholdsTable thresholds={defaultThresholds} currency={CurrencyEnum.Usd} />)

    // Check recurring label is rendered
    expect(screen.getByText('text_17241798877230y851fdxzqu')).toBeInTheDocument()

    // Check recurring threshold display name
    expect(screen.getByText('Recurring threshold')).toBeInTheDocument()
  })

  it('renders formatted amount with correct currency', () => {
    render(<RecurringThresholdsTable thresholds={defaultThresholds} currency={CurrencyEnum.Usd} />)

    // Check amount is formatted (50000 cents = $500.00)
    expect(screen.getByText('$500.00')).toBeInTheDocument()
  })

  it('renders amount with EUR currency', () => {
    render(<RecurringThresholdsTable thresholds={defaultThresholds} currency={CurrencyEnum.Eur} />)

    // Check amount is formatted with EUR
    expect(screen.getByText('€500.00')).toBeInTheDocument()
  })

  it('displays all thresholds passed to it', () => {
    const multipleThresholds = [
      {
        id: 'threshold-1',
        amountCents: '50000',
        recurring: true,
        thresholdDisplayName: 'First recurring',
      },
      {
        id: 'threshold-2',
        amountCents: '100000',
        recurring: true,
        thresholdDisplayName: 'Second recurring',
      },
    ]

    render(<RecurringThresholdsTable thresholds={multipleThresholds} currency={CurrencyEnum.Usd} />)

    // All thresholds should be displayed
    expect(screen.getByText('First recurring')).toBeInTheDocument()
    expect(screen.getByText('Second recurring')).toBeInTheDocument()
  })

  it('handles threshold without display name', () => {
    const thresholdWithoutName = [
      {
        id: 'threshold-1',
        amountCents: '50000',
        recurring: true,
        thresholdDisplayName: null,
      },
    ]

    render(
      <RecurringThresholdsTable thresholds={thresholdWithoutName} currency={CurrencyEnum.Usd} />,
    )

    // Amount should still be shown
    expect(screen.getByText('$500.00')).toBeInTheDocument()

    // Placeholder translation should be displayed
    expect(screen.getByText('text_177015377629790y0xa6o8g5')).toBeInTheDocument()
  })

  it('accepts custom name prop without error', () => {
    // This test verifies the component accepts the name prop without throwing
    expect(() => {
      render(
        <RecurringThresholdsTable
          thresholds={defaultThresholds}
          currency={CurrencyEnum.Usd}
          name="custom-table-name"
        />,
      )
    }).not.toThrow()

    // Verify the table still renders correctly
    expect(screen.getByText('Recurring threshold')).toBeInTheDocument()
  })

  it('handles empty thresholds array', () => {
    render(<RecurringThresholdsTable thresholds={[]} currency={CurrencyEnum.Usd} />)

    // Table should render without errors (no rows)
    expect(screen.queryByText('text_17241798877230y851fdxzqu')).not.toBeInTheDocument()
  })

  it('renders recurring label for each threshold row', () => {
    const twoThresholds = [
      {
        id: 'threshold-1',
        amountCents: '50000',
        recurring: true,
        thresholdDisplayName: 'First',
      },
      {
        id: 'threshold-2',
        amountCents: '100000',
        recurring: true,
        thresholdDisplayName: 'Second',
      },
    ]

    render(<RecurringThresholdsTable thresholds={twoThresholds} currency={CurrencyEnum.Usd} />)

    // Each row should have the recurring label
    const recurringLabels = screen.getAllByText('text_17241798877230y851fdxzqu')

    expect(recurringLabels).toHaveLength(2)
  })
})
