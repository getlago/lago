import { OrderExecutionModeEnum } from '~/generated/graphql'

import { getOrderExecutionModeTranslationKey } from '../getOrderExecutionModeTranslationKey'

describe('getOrderExecutionModeTranslationKey', () => {
  it('GIVEN execute_in_lago THEN returns a non-empty key', () => {
    expect(getOrderExecutionModeTranslationKey(OrderExecutionModeEnum.ExecuteInLago)).not.toBe('')
  })

  it('GIVEN order_only THEN returns a non-empty key', () => {
    expect(getOrderExecutionModeTranslationKey(OrderExecutionModeEnum.OrderOnly)).not.toBe('')
  })

  it('GIVEN execute_in_lago and order_only THEN returns distinct keys', () => {
    expect(getOrderExecutionModeTranslationKey(OrderExecutionModeEnum.ExecuteInLago)).not.toBe(
      getOrderExecutionModeTranslationKey(OrderExecutionModeEnum.OrderOnly),
    )
  })

  it('GIVEN null THEN returns an empty string', () => {
    expect(getOrderExecutionModeTranslationKey(null)).toBe('')
  })

  it('GIVEN undefined THEN returns an empty string', () => {
    expect(getOrderExecutionModeTranslationKey(undefined)).toBe('')
  })
})
