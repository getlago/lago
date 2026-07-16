import { OrderTypeEnum } from '~/generated/graphql'

import { getQuoteTypeDescriptionTranslationKey } from '../getQuoteTypeDescriptionTranslationKey'

describe('getQuoteTypeDescriptionTranslationKey', () => {
  it.each([
    { orderType: OrderTypeEnum.OneOff, description: 'one-off' },
    { orderType: OrderTypeEnum.SubscriptionAmendment, description: 'subscription amendment' },
    { orderType: OrderTypeEnum.SubscriptionCreation, description: 'subscription creation' },
  ])('GIVEN a $description order type, THEN should return a string', ({ orderType }) => {
    const result = getQuoteTypeDescriptionTranslationKey(orderType)

    expect(typeof result).toBe('string')
    expect(result.length).toBeGreaterThan(0)
  })

  it('GIVEN different order types, THEN should return different keys for each type', () => {
    const oneOffKey = getQuoteTypeDescriptionTranslationKey(OrderTypeEnum.OneOff)
    const amendmentKey = getQuoteTypeDescriptionTranslationKey(OrderTypeEnum.SubscriptionAmendment)
    const creationKey = getQuoteTypeDescriptionTranslationKey(OrderTypeEnum.SubscriptionCreation)

    expect(oneOffKey).not.toBe(amendmentKey)
    expect(oneOffKey).not.toBe(creationKey)
    expect(amendmentKey).not.toBe(creationKey)
  })

  it('GIVEN an unknown order type, THEN should return an empty string', () => {
    const result = getQuoteTypeDescriptionTranslationKey('unknown' as OrderTypeEnum)

    expect(result).toBe('')
  })
})
