import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { SubscriptionFeeInfo } from '../SubscriptionFeeInfo'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const basePlan = {
  __typename: 'Plan' as const,
  id: 'plan_1',
  amountCents: '1000',
  amountCurrency: CurrencyEnum.Usd,
  payInAdvance: false,
  trialPeriod: 14,
  taxes: [],
}

describe('SubscriptionFeeInfo', () => {
  it('renders the amount cell + the pay-in-advance / trial / taxes grid', () => {
    render(<SubscriptionFeeInfo plan={basePlan} />)

    expect(screen.getByText('text_624453d52e945301380e49b6')).toBeInTheDocument()
    expect(screen.getByText('text_646e2d0cc536351b62ba6f8c')).toBeInTheDocument()
    expect(screen.getByText('14')).toBeInTheDocument()
  })

  it('shows "Pay in advance" copy when payInAdvance=true', () => {
    render(<SubscriptionFeeInfo plan={{ ...basePlan, payInAdvance: true }} />)

    expect(screen.getByText('text_646e2d0cc536351b62ba6faa')).toBeInTheDocument()
  })

  it('renders a "-" placeholder when no taxes are attached', () => {
    render(<SubscriptionFeeInfo plan={basePlan} />)

    expect(screen.getByText('-')).toBeInTheDocument()
  })

  it('lists each tax as "Name (rate%)" when taxes are present', () => {
    render(
      <SubscriptionFeeInfo
        plan={{
          ...basePlan,
          taxes: [{ id: 't1', name: 'VAT', rate: 20 }],
        }}
      />,
    )

    expect(screen.getByText(/VAT/)).toBeInTheDocument()
  })
})
