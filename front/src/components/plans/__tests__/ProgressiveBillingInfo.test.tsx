import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { ProgressiveBillingInfo } from '../ProgressiveBillingInfo'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const plan = {
  amountCurrency: CurrencyEnum.Usd,
  usageThresholds: [
    { id: 'u1', amountCents: 10000, recurring: false, thresholdDisplayName: 'First' },
    { id: 'u2', amountCents: 20000, recurring: true, thresholdDisplayName: 'Recurring' },
  ],
}

describe('ProgressiveBillingInfo', () => {
  it('renders non-recurring and recurring threshold amounts', () => {
    render(<ProgressiveBillingInfo plan={plan} currency={CurrencyEnum.Usd} />)
    expect(screen.getByText('$100.00')).toBeInTheDocument()
    expect(screen.getByText('$200.00')).toBeInTheDocument()
  })
})
