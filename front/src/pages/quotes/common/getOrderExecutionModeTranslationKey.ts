import { OrderExecutionModeEnum } from '~/generated/graphql'

export const getOrderExecutionModeTranslationKey = (
  executionMode?: OrderExecutionModeEnum | null,
): string => {
  switch (executionMode) {
    case OrderExecutionModeEnum.ExecuteInLago:
      return 'text_1782392058759vsncvwa3829'
    case OrderExecutionModeEnum.OrderOnly:
      return 'text_1782392058759l2hdxjsbklc'
    default:
      return ''
  }
}
