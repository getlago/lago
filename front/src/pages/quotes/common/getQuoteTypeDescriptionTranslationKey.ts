import { OrderTypeEnum } from '~/generated/graphql'

export const getQuoteTypeDescriptionTranslationKey = (quoteType: OrderTypeEnum): string => {
  switch (quoteType) {
    case OrderTypeEnum.OneOff:
      return 'text_17763310589550mvdhle1851'
    case OrderTypeEnum.SubscriptionAmendment:
      return 'text_17763310589568ebezrjk3tm'
    case OrderTypeEnum.SubscriptionCreation:
      return 'text_177633105895631pas804kd6'
    default:
      return ''
  }
}
