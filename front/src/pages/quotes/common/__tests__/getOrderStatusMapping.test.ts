import { StatusType } from '~/components/designSystem/Status'
import { OrderStatusEnum } from '~/generated/graphql'

import { getOrderStatusMapping } from '../getOrderStatusMapping'

describe('getOrderStatusMapping', () => {
  const mockTranslate = jest.fn((key: string) => key)

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a created status', () => {
    it('THEN should return warning type', () => {
      const result = getOrderStatusMapping(OrderStatusEnum.Created, mockTranslate)

      expect(result.type).toBe(StatusType.warning)
    })

    it('THEN should call translate for the label', () => {
      getOrderStatusMapping(OrderStatusEnum.Created, mockTranslate)

      expect(mockTranslate).toHaveBeenCalledTimes(1)
    })
  })

  describe('GIVEN an executed status', () => {
    it('THEN should return success type', () => {
      const result = getOrderStatusMapping(OrderStatusEnum.Executed, mockTranslate)

      expect(result.type).toBe(StatusType.success)
    })

    it('THEN should call translate for the label', () => {
      getOrderStatusMapping(OrderStatusEnum.Executed, mockTranslate)

      expect(mockTranslate).toHaveBeenCalledTimes(1)
    })
  })
})
