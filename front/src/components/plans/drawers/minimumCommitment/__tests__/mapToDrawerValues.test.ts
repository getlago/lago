import { CurrencyEnum, TaxForPlanAndChargesInPlanFormFragment } from '~/generated/graphql'

import { mapCommitmentToDrawerValues } from '../mapToDrawerValues'

const tax = (id: string): TaxForPlanAndChargesInPlanFormFragment =>
  ({ id, code: id, name: id, rate: 0 }) as TaxForPlanAndChargesInPlanFormFragment

describe('mapCommitmentToDrawerValues', () => {
  it('returns blank payload when commitment is null', () => {
    expect(mapCommitmentToDrawerValues(null)).toEqual({
      amountCents: '',
      invoiceDisplayName: undefined,
      taxes: [],
    })
  })

  it('returns blank payload when commitment is undefined', () => {
    expect(mapCommitmentToDrawerValues(undefined)).toEqual({
      amountCents: '',
      invoiceDisplayName: undefined,
      taxes: [],
    })
  })

  it('passes amountCents through as string when deserialize is false', () => {
    expect(
      mapCommitmentToDrawerValues({
        amountCents: '12345',
        invoiceDisplayName: 'Display',
        taxes: [],
      }),
    ).toMatchObject({
      amountCents: '12345',
      invoiceDisplayName: 'Display',
    })
  })

  it('deserializes amountCents to major units when deserialize=true', () => {
    expect(
      mapCommitmentToDrawerValues(
        { amountCents: 10000 },
        { deserialize: true, currency: CurrencyEnum.Usd },
      ).amountCents,
    ).toBe('100')
  })

  it('returns empty string for null/undefined/empty amountCents', () => {
    expect(mapCommitmentToDrawerValues({ amountCents: null }).amountCents).toBe('')
    expect(mapCommitmentToDrawerValues({ amountCents: undefined }).amountCents).toBe('')
    expect(mapCommitmentToDrawerValues({ amountCents: '' }).amountCents).toBe('')
  })

  it('stringifies numeric amountCents including 0', () => {
    expect(mapCommitmentToDrawerValues({ amountCents: 0 }).amountCents).toBe('0')
  })

  it('coerces null invoiceDisplayName to undefined', () => {
    expect(
      mapCommitmentToDrawerValues({ invoiceDisplayName: null }).invoiceDisplayName,
    ).toBeUndefined()
  })

  it('copies taxes array (defensive clone)', () => {
    const taxes = [tax('vat')]
    const result = mapCommitmentToDrawerValues({ taxes })

    expect(result.taxes).toEqual(taxes)
    expect(result.taxes).not.toBe(taxes)
  })

  it('defaults taxes to [] when missing', () => {
    expect(mapCommitmentToDrawerValues({}).taxes).toEqual([])
  })
})
