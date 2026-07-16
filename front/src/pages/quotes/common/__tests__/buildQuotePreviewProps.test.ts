import { CurrencyEnum } from '~/generated/graphql'

import { buildQuotePreviewProps, type QuotePdfHeaderData } from '../buildQuotePreviewProps'

jest.mock('~/core/serializers/serializeQuoteBillingItems', () => ({
  buildPreviewEntities: jest.fn(() => ({ 'addon-1': { entityId: 'addon-1' } })),
}))

const { buildPreviewEntities } = jest.requireMock('~/core/serializers/serializeQuoteBillingItems')

describe('buildQuotePreviewProps', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('builds entities from billingItems and extracts locale + currency', () => {
    const version = { content: '<p>Hi</p>', billingItems: { addons: [] }, mentionVariables: {} }
    const customer = {
      currency: CurrencyEnum.Eur,
      billingConfiguration: { documentLocale: 'fr' },
    }

    const result = buildQuotePreviewProps({ version, customer })

    expect(buildPreviewEntities).toHaveBeenCalledWith({ addons: [] })
    expect(result).toEqual({
      content: '<p>Hi</p>',
      entities: { 'addon-1': { entityId: 'addon-1' } },
      customerLocale: 'fr',
      customerCurrency: CurrencyEnum.Eur,
      mentionValues: {},
      images: {},
    })
  })

  it('returns an empty-safe bundle when version and customer are null', () => {
    const result = buildQuotePreviewProps({ version: null, customer: null })

    expect(buildPreviewEntities).not.toHaveBeenCalled()
    expect(result).toEqual({
      content: '',
      entities: {},
      customerLocale: 'en',
      customerCurrency: undefined,
      mentionValues: {},
      images: {},
    })
  })

  it('defaults locale to en and currency to undefined when missing on customer', () => {
    const version = { content: '<p>x</p>', billingItems: null, mentionVariables: {} }
    const customer = { currency: null, billingConfiguration: null }

    const result = buildQuotePreviewProps({ version, customer })

    expect(result.customerLocale).toBe('en')
    expect(result.customerCurrency).toBeUndefined()
    expect(result.entities).toEqual({})
  })

  it('passes through structured header data when provided', () => {
    const version = { content: '<p>Hi</p>', billingItems: { addons: [] }, mentionVariables: {} }
    const customer = {
      currency: CurrencyEnum.Eur,
      billingConfiguration: { documentLocale: 'fr' },
    }
    const header: QuotePdfHeaderData = {
      documentNumber: 'OF-2026-0012',
      rows: ['Order form number OF-2026-0012'],
    }

    const result = buildQuotePreviewProps({ version, customer, images: {}, header })

    expect(result.header).toEqual(header)
  })

  it('leaves header undefined when not provided', () => {
    const result = buildQuotePreviewProps({ version: null, customer: null })

    expect(result.header).toBeUndefined()
  })

  it('surfaces populated mentionVariables from the version payload', () => {
    const version = {
      content: '<p>Hello</p>',
      billingItems: null,
      mentionVariables: { customer_name: 'Keenan Feldspar', organization_logo: null },
    }

    const result = buildQuotePreviewProps({ version, customer: null })

    expect(result.mentionValues).toEqual({
      customer_name: 'Keenan Feldspar',
      organization_logo: null,
    })
  })

  it('falls back to {} when mentionVariables is absent (null version)', () => {
    const result = buildQuotePreviewProps({ version: null, customer: null })

    expect(result.mentionValues).toEqual({})
  })

  it('passes through the images map when provided', () => {
    const images = { 'blob-1': 'https://example.com/signed-url' }

    const result = buildQuotePreviewProps({ version: null, customer: null, images })

    expect(result.images).toEqual(images)
  })

  it('defaults images to {} when not provided', () => {
    const result = buildQuotePreviewProps({ version: null, customer: null })

    expect(result.images).toEqual({})
  })
})
