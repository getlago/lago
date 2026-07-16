import { screen } from '@testing-library/react'

import { CurrencyEnum, FixedChargeChargeModelEnum, PlanInterval } from '~/generated/graphql'
import { render } from '~/test-utils'

import { FixedChargeInfo } from '../FixedChargeInfo'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (k: string) => k }),
}))

const baseCharge = {
  id: 'fc_1',
  invoiceDisplayName: 'Onboarding fee',
  chargeModel: FixedChargeChargeModelEnum.Standard,
  units: '1',
  payInAdvance: true,
  prorated: false,
  properties: { amount: '49.99' },
  addOn: { id: 'addon_1', name: 'Onboarding', code: 'onboarding' },
  taxes: [],
}

describe('FixedChargeInfo', () => {
  it('renders charge model + interval + units', () => {
    render(
      <FixedChargeInfo
        fixedCharge={baseCharge}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        billFixedChargesMonthly={false}
        planTaxes={[]}
      />,
    )

    expect(screen.getByText('text_65201b8216455901fe273dd5')).toBeInTheDocument()
    expect(screen.getByText('text_65201b8216455901fe273dc1')).toBeInTheDocument()
    expect(screen.getByText('text_65771fa3f4ab9a00720726ce')).toBeInTheDocument()
    expect(screen.getByText('1')).toBeInTheDocument()
  })

  it('renders payInAdvance + taxes options when prorated is false', () => {
    render(
      <FixedChargeInfo
        fixedCharge={{ ...baseCharge, payInAdvance: false }}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )

    expect(screen.getByText('text_646e2d0cc536351b62ba6f8c')).toBeInTheDocument()
    expect(screen.getByText('text_65251f4cd55aeb004e5aa5ef')).toBeInTheDocument()
    expect(screen.getByText('-')).toBeInTheDocument()
  })

  it('falls back to planTaxes when fixedCharge has none', () => {
    render(
      <FixedChargeInfo
        fixedCharge={{ ...baseCharge, taxes: [] }}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[{ id: 'tax_1', name: 'VAT', rate: 20 }]}
      />,
    )

    expect(screen.getByText(/VAT/)).toBeInTheDocument()
  })

  it('uses fixedCharge.taxes when present, ignoring plan taxes', () => {
    render(
      <FixedChargeInfo
        fixedCharge={{
          ...baseCharge,
          taxes: [{ id: 'tax_2', name: 'GST', rate: 10 }],
        }}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[{ id: 'tax_1', name: 'VAT', rate: 20 }]}
      />,
    )

    expect(screen.getByText(/GST/)).toBeInTheDocument()
    expect(screen.queryByText(/VAT/)).not.toBeInTheDocument()
  })
})
