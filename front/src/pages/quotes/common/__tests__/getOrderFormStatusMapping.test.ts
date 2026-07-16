import { StatusType } from '~/components/designSystem/Status'
import { OrderFormStatusEnum } from '~/generated/graphql'

import { getOrderFormStatusMapping } from '../getOrderFormStatusMapping'

describe('getOrderFormStatusMapping', () => {
  const mockTranslate = jest.fn((key: string) => key)

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a generated status', () => {
    it('THEN should return warning type', () => {
      const result = getOrderFormStatusMapping(OrderFormStatusEnum.Generated, mockTranslate)

      expect(result.type).toBe(StatusType.warning)
    })

    it('THEN should call translate for the label', () => {
      getOrderFormStatusMapping(OrderFormStatusEnum.Generated, mockTranslate)

      expect(mockTranslate).toHaveBeenCalledTimes(1)
    })
  })

  describe('GIVEN a signed status', () => {
    it('THEN should return success type', () => {
      const result = getOrderFormStatusMapping(OrderFormStatusEnum.Signed, mockTranslate)

      expect(result.type).toBe(StatusType.success)
    })

    it('THEN should call translate for the label', () => {
      getOrderFormStatusMapping(OrderFormStatusEnum.Signed, mockTranslate)

      expect(mockTranslate).toHaveBeenCalledTimes(1)
    })
  })

  describe('GIVEN a voided status', () => {
    it('THEN should return disabled type', () => {
      const result = getOrderFormStatusMapping(OrderFormStatusEnum.Voided, mockTranslate)

      expect(result.type).toBe(StatusType.disabled)
    })

    it('THEN should call translate for the label', () => {
      getOrderFormStatusMapping(OrderFormStatusEnum.Voided, mockTranslate)

      expect(mockTranslate).toHaveBeenCalledTimes(1)
    })
  })

  describe('GIVEN an expired status', () => {
    it('THEN should return disabled type', () => {
      const result = getOrderFormStatusMapping(OrderFormStatusEnum.Expired, mockTranslate)

      expect(result.type).toBe(StatusType.disabled)
    })

    it('THEN should call translate for the label', () => {
      getOrderFormStatusMapping(OrderFormStatusEnum.Expired, mockTranslate)

      expect(mockTranslate).toHaveBeenCalledTimes(1)
    })
  })
})
