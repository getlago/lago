import { OrderTypeEnum } from '~/generated/graphql'

import { getQuoteOrderTypeTranslationKey } from '../getQuoteOrderTypeTranslationKey'

describe('getQuoteOrderTypeTranslationKey', () => {
  it.each([
    { orderType: OrderTypeEnum.OneOff, description: 'one-off' },
    { orderType: OrderTypeEnum.SubscriptionAmendment, description: 'subscription amendment' },
    { orderType: OrderTypeEnum.SubscriptionCreation, description: 'subscription creation' },
  ])('GIVEN a $description order type, THEN should return a string', ({ orderType }) => {
    const result = getQuoteOrderTypeTranslationKey(orderType)

    expect(typeof result).toBe('string')
    expect(result.length).toBeGreaterThan(0)
  })

  it('GIVEN different order types, THEN should return different keys for one-off and amendment', () => {
    const oneOffKey = getQuoteOrderTypeTranslationKey(OrderTypeEnum.OneOff)
    const amendmentKey = getQuoteOrderTypeTranslationKey(OrderTypeEnum.SubscriptionAmendment)

    expect(oneOffKey).not.toBe(amendmentKey)
  })

  it('GIVEN subscription creation, THEN should return the default key', () => {
    const creationKey = getQuoteOrderTypeTranslationKey(OrderTypeEnum.SubscriptionCreation)
    const oneOffKey = getQuoteOrderTypeTranslationKey(OrderTypeEnum.OneOff)
    const amendmentKey = getQuoteOrderTypeTranslationKey(OrderTypeEnum.SubscriptionAmendment)

    expect(creationKey).not.toBe(oneOffKey)
    expect(creationKey).not.toBe(amendmentKey)
  })
})
