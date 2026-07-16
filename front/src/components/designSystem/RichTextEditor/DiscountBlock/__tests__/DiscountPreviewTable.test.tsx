import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import type { TranslateFunc } from '~/hooks/core/useInternationalization'
import { render } from '~/test-utils'

import { EntityData } from '../../common/RichTextEditorContext'
import { DISCOUNT_PREVIEW_TABLE_TEST_ID, DiscountPreviewTable } from '../DiscountPreviewTable'

const BILLING_PERIODS_KEY = 'text_17830875698228lpz4i09jop'

const translate = ((key: string, data?: Record<string, unknown>) => {
  const map: Record<string, string> = {
    text_1782889379261hdcd0jhzdm6: 'Discount',
    text_1783090333139dnllq2q6ege: 'Discount value',
    text_632d68358f1fedc68eed3e80: 'Duration',
    text_632d68358f1fedc68eed3ea3: 'Once',
    text_63c83a3476e46bc6ab9d85d6: 'Forever',
    [BILLING_PERIODS_KEY]: `${data?.count} billing periods`,
  }

  return map[key] ?? key
}) as unknown as TranslateFunc

const base: EntityData = {
  entityId: 'c1',
  entityType: 'coupon',
  name: 'Summer Deal',
  code: 'summer',
}

const renderTable = (entity: EntityData) =>
  render(<DiscountPreviewTable entity={entity} translate={translate} currency={CurrencyEnum.Usd} />)

describe('DiscountPreviewTable', () => {
  it('renders the coupon name', () => {
    renderTable({ ...base })
    expect(screen.getByTestId(DISCOUNT_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
    expect(screen.getByText('Summer Deal')).toBeInTheDocument()
  })

  it('renders a fixed-amount value with currency formatting', () => {
    renderTable({
      ...base,
      couponType: 'fixed_amount' as EntityData['couponType'],
      amountCents: '1000',
      amountCurrency: 'USD' as EntityData['amountCurrency'],
      percentageRate: null,
      frequency: 'once' as EntityData['frequency'],
      frequencyDuration: null,
    })
    expect(screen.getByText('$10.00')).toBeInTheDocument()
    expect(screen.getByText('Once')).toBeInTheDocument()
  })

  it('renders a percentage value and forever duration', () => {
    renderTable({
      ...base,
      couponType: 'percentage' as EntityData['couponType'],
      percentageRate: 15,
      frequency: 'forever' as EntityData['frequency'],
      frequencyDuration: null,
    })
    expect(screen.getByText('15%')).toBeInTheDocument()
    expect(screen.getByText('Forever')).toBeInTheDocument()
  })

  it('renders recurring duration as "{count} billing periods"', () => {
    renderTable({
      ...base,
      couponType: 'percentage' as EntityData['couponType'],
      percentageRate: 20,
      frequency: 'recurring' as EntityData['frequency'],
      frequencyDuration: 12,
    })
    expect(screen.getByText('12 billing periods')).toBeInTheDocument()
  })
})
