import { OrderTypeEnum } from '~/generated/graphql'

export const getQuoteOrderTypeTranslationKey = (quoteType: OrderTypeEnum): string => {
  switch (quoteType) {
    case OrderTypeEnum.OneOff:
      return 'text_1775747115932ib2to4erkoo'
    case OrderTypeEnum.SubscriptionAmendment:
      return 'text_17757471159329jnt7pyy6vr'
    case OrderTypeEnum.SubscriptionCreation:
      return 'text_1775747115932u8ttc3l11w1'
    default:
      return ''
  }
}
