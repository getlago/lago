import { screen } from '@testing-library/react'

import { CurrencyEnum, PlanInterval } from '~/generated/graphql'
import { render } from '~/test-utils'

import { MinimumCommitmentInfo } from '../MinimumCommitmentInfo'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const plan = {
  interval: PlanInterval.Monthly,
  amountCurrency: CurrencyEnum.Usd,
  minimumCommitment: {
    amountCents: 5000,
    invoiceDisplayName: 'Min fee',
    taxes: [{ id: 't1', code: 'vat', name: 'VAT', rate: 20 }],
  },
}

describe('MinimumCommitmentInfo', () => {
  it('renders the commitment amount and tax rate', () => {
    render(<MinimumCommitmentInfo plan={plan} currency={CurrencyEnum.Usd} />)
    expect(screen.getByText('$50.00')).toBeInTheDocument()
    expect(screen.getByText(/VAT/)).toBeInTheDocument()
  })
})
