import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { ThresholdsTable } from '../ThresholdsTable'

// Mock hooks
jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('ThresholdsTable', () => {
  const defaultThresholds = [
    {
      id: 'threshold-1',
      amountCents: '10000',
      thresholdDisplayName: 'First threshold',
    },
    {
      id: 'threshold-2',
      amountCents: '25000',
      thresholdDisplayName: 'Second threshold',
    },
  ]

  it('renders the table with thresholds', () => {
    render(<ThresholdsTable thresholds={defaultThresholds} currency={CurrencyEnum.Usd} />)

    // Check header translations are rendered
    expect(screen.getByText('text_1724179887723eh12a0kqbdw')).toBeInTheDocument()
    expect(screen.getByText('text_17241798877234jhvoho4ci9')).toBeInTheDocument()

    // Check first threshold label
    expect(screen.getByText('text_1724179887723hi673zmbvdj')).toBeInTheDocument()

    // Check additional threshold label
    expect(screen.getByText('text_1724179887723917j8ezkd9v')).toBeInTheDocument()

    // Check threshold display names are shown
    expect(screen.getByText('First threshold')).toBeInTheDocument()
    expect(screen.getByText('Second threshold')).toBeInTheDocument()
  })

  it('renders formatted amounts with correct currency', () => {
    render(<ThresholdsTable thresholds={defaultThresholds} currency={CurrencyEnum.Usd} />)

    // Check amounts are formatted (10000 cents = $100.00, 25000 cents = $250.00)
    expect(screen.getByText('$100.00')).toBeInTheDocument()
    expect(screen.getByText('$250.00')).toBeInTheDocument()
  })

  it('renders amounts with EUR currency', () => {
    render(<ThresholdsTable thresholds={defaultThresholds} currency={CurrencyEnum.Eur} />)

    // Check amounts are formatted with EUR
    expect(screen.getByText('€100.00')).toBeInTheDocument()
    expect(screen.getByText('€250.00')).toBeInTheDocument()
  })

  it('displays all thresholds passed to it', () => {
    const threeThresholds = [
      ...defaultThresholds,
      {
        id: 'threshold-3',
        amountCents: '50000',
        thresholdDisplayName: 'Third threshold',
      },
    ]

    render(<ThresholdsTable thresholds={threeThresholds} currency={CurrencyEnum.Usd} />)

    // All thresholds should be displayed
    expect(screen.getByText('First threshold')).toBeInTheDocument()
    expect(screen.getByText('Second threshold')).toBeInTheDocument()
    expect(screen.getByText('Third threshold')).toBeInTheDocument()
  })

  it('handles empty thresholds array', () => {
    render(<ThresholdsTable thresholds={[]} currency={CurrencyEnum.Usd} />)

    // Headers should still be rendered
    expect(screen.getByText('text_1724179887723eh12a0kqbdw')).toBeInTheDocument()
    expect(screen.getByText('text_17241798877234jhvoho4ci9')).toBeInTheDocument()
  })

  it('handles threshold without display name', () => {
    const thresholdsWithoutName = [
      {
        id: 'threshold-1',
        amountCents: '10000',
        thresholdDisplayName: null,
      },
    ]

    render(<ThresholdsTable thresholds={thresholdsWithoutName} currency={CurrencyEnum.Usd} />)

    // Amount should still be shown
    expect(screen.getByText('$100.00')).toBeInTheDocument()

    // Placeholder translation should be displayed
    expect(screen.getByText('text_177015377629790y0xa6o8g5')).toBeInTheDocument()
  })

  it('renders single threshold with first threshold label', () => {
    const singleThreshold = [
      {
        id: 'threshold-1',
        amountCents: '10000',
        thresholdDisplayName: 'Only threshold',
      },
    ]

    render(<ThresholdsTable thresholds={singleThreshold} currency={CurrencyEnum.Usd} />)

    // Should show first threshold label, not additional
    expect(screen.getByText('text_1724179887723hi673zmbvdj')).toBeInTheDocument()
    expect(screen.queryByText('text_1724179887723917j8ezkd9v')).not.toBeInTheDocument()
  })
})
