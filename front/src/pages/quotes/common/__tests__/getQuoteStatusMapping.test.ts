import { StatusType } from '~/components/designSystem/Status'
import { StatusEnum } from '~/generated/graphql'

import { getQuoteStatusMapping } from '../getQuoteStatusMapping'

describe('getQuoteStatusMapping', () => {
  const mockTranslate = jest.fn((key: string) => key)

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a draft status', () => {
    it('THEN should return outline type with draft label', () => {
      const result = getQuoteStatusMapping(StatusEnum.Draft, mockTranslate)

      expect(result).toEqual({ type: StatusType.outline, label: 'draft' })
    })

    it('THEN should not call translate', () => {
      getQuoteStatusMapping(StatusEnum.Draft, mockTranslate)

      expect(mockTranslate).not.toHaveBeenCalled()
    })
  })

  describe('GIVEN an approved status', () => {
    it('THEN should return success type', () => {
      const result = getQuoteStatusMapping(StatusEnum.Approved, mockTranslate)

      expect(result.type).toBe(StatusType.success)
    })

    it('THEN should call translate for the label', () => {
      getQuoteStatusMapping(StatusEnum.Approved, mockTranslate)

      expect(mockTranslate).toHaveBeenCalledTimes(1)
    })
  })

  describe('GIVEN a voided status', () => {
    it('THEN should return disabled type with voided label', () => {
      const result = getQuoteStatusMapping(StatusEnum.Voided, mockTranslate)

      expect(result).toEqual({ type: StatusType.disabled, label: 'voided' })
    })

    it('THEN should not call translate', () => {
      getQuoteStatusMapping(StatusEnum.Voided, mockTranslate)

      expect(mockTranslate).not.toHaveBeenCalled()
    })
  })
})
