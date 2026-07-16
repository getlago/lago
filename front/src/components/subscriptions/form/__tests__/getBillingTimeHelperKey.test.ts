import { BillingTimeEnum, PlanInterval } from '~/generated/graphql'

import { getBillingTimeHelperKey } from '../getBillingTimeHelperKey'

const SUB_AT_MID_MONTH = '2026-05-15T12:00:00.000'
const SUB_AT_DAY_29 = '2026-05-29T12:00:00.000'
const SUB_AT_DAY_30 = '2026-05-30T12:00:00.000'
const SUB_AT_DAY_31 = '2026-05-31T12:00:00.000'

describe('getBillingTimeHelperKey', () => {
  describe('GIVEN no plan interval', () => {
    it('THEN should return undefined', () => {
      const result = getBillingTimeHelperKey(BillingTimeEnum.Calendar, SUB_AT_MID_MONTH, undefined)

      expect(result).toBeUndefined()
    })
  })

  describe('GIVEN plan interval Monthly', () => {
    describe('WHEN billingTime is Calendar', () => {
      it('THEN should return calendar billing key', () => {
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Calendar,
          SUB_AT_MID_MONTH,
          PlanInterval.Monthly,
        )

        expect(result).toEqual({ key: 'text_62ea7cd44cd4b14bb9ac1d7e' })
      })
    })

    describe('WHEN billingTime is Anniversary and current day ≤ 28', () => {
      it('THEN should return key with day variable', () => {
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Anniversary,
          SUB_AT_MID_MONTH,
          PlanInterval.Monthly,
        )

        expect(result).toEqual({
          key: 'text_62ea7cd44cd4b14bb9ac1d82',
          variables: { day: 15 },
        })
      })
    })

    describe('WHEN billingTime is Anniversary and current day = 29', () => {
      it('THEN should return key for day 29', () => {
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Anniversary,
          SUB_AT_DAY_29,
          PlanInterval.Monthly,
        )

        expect(result).toEqual({ key: 'text_62ea7cd44cd4b14bb9ac1d86' })
      })
    })

    describe('WHEN billingTime is Anniversary and current day = 30', () => {
      it('THEN should return key for day 30', () => {
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Anniversary,
          SUB_AT_DAY_30,
          PlanInterval.Monthly,
        )

        expect(result).toEqual({ key: 'text_62ea7cd44cd4b14bb9ac1d8a' })
      })
    })

    describe('WHEN billingTime is Anniversary and current day ≥ 31', () => {
      it('THEN should return key for end-of-month', () => {
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Anniversary,
          SUB_AT_DAY_31,
          PlanInterval.Monthly,
        )

        expect(result).toEqual({ key: 'text_62ea7cd44cd4b14bb9ac1d8e' })
      })
    })
  })

  describe('GIVEN plan interval Yearly', () => {
    describe('WHEN billingTime is Calendar', () => {
      it('THEN should return calendar yearly key', () => {
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Calendar,
          SUB_AT_MID_MONTH,
          PlanInterval.Yearly,
        )

        expect(result).toEqual({ key: 'text_62ea7cd44cd4b14bb9ac1d92' })
      })
    })

    describe('WHEN billingTime is Anniversary on Feb 29 of the current year', () => {
      it('THEN should return Feb-29 key when the current year is a leap year', () => {
        const currentYear = new Date().getFullYear()
        const isLeapYear =
          (currentYear % 4 === 0 && currentYear % 100 !== 0) || currentYear % 400 === 0

        if (!isLeapYear) {
          return // helper only matches Feb-29 against the current year
        }

        const isoDate = `${currentYear}-02-29T12:00:00.000`
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Anniversary,
          isoDate,
          PlanInterval.Yearly,
        )

        expect(result).toEqual({ key: 'text_62ea7cd44cd4b14bb9ac1d9a' })
      })
    })

    describe('WHEN billingTime is Anniversary on non-Feb-29', () => {
      it('THEN should return key with date variable', () => {
        const result = getBillingTimeHelperKey(
          BillingTimeEnum.Anniversary,
          SUB_AT_MID_MONTH,
          PlanInterval.Yearly,
        )

        expect(result?.key).toBe('text_62ea7cd44cd4b14bb9ac1d96')
        expect(result?.variables).toHaveProperty('date')
      })
    })
  })

  describe('GIVEN plan interval Quarterly', () => {
    it('WHEN Calendar THEN returns calendar quarterly key', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Calendar,
        SUB_AT_MID_MONTH,
        PlanInterval.Quarterly,
      )

      expect(result).toEqual({ key: 'text_64d6357b00dea100ad1cba34' })
    })

    it('WHEN Anniversary day ≤ 28 THEN returns key with day variable', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Anniversary,
        SUB_AT_MID_MONTH,
        PlanInterval.Quarterly,
      )

      expect(result).toEqual({
        key: 'text_64d6357b00dea100ad1cba36',
        variables: { day: 15 },
      })
    })

    it('WHEN Anniversary day = 29 THEN returns day-29 key', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Anniversary,
        SUB_AT_DAY_29,
        PlanInterval.Quarterly,
      )

      expect(result).toEqual({ key: 'text_64d63ec2f6bd3f41a6e353ac' })
    })

    it('WHEN Anniversary day = 30 THEN returns day-30 key', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Anniversary,
        SUB_AT_DAY_30,
        PlanInterval.Quarterly,
      )

      expect(result).toEqual({ key: 'text_64d63ec2f6bd3f41a6e353b0' })
    })

    it('WHEN Anniversary day ≥ 31 THEN returns end-of-month key', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Anniversary,
        SUB_AT_DAY_31,
        PlanInterval.Quarterly,
      )

      expect(result).toEqual({ key: 'text_64d63ec2f6bd3f41a6e353b4' })
    })
  })

  describe('GIVEN plan interval Semiannual', () => {
    it('WHEN Calendar THEN returns calendar semiannual key', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Calendar,
        SUB_AT_MID_MONTH,
        PlanInterval.Semiannual,
      )

      expect(result).toEqual({ key: 'text_1757502242292q05inkc09vq' })
    })

    it('WHEN Anniversary THEN returns key with date variable', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Anniversary,
        SUB_AT_MID_MONTH,
        PlanInterval.Semiannual,
      )

      expect(result?.key).toBe('text_1757504174992y39ailqcch0')
      expect(result?.variables).toHaveProperty('date')
    })
  })

  describe('GIVEN plan interval Weekly', () => {
    it('WHEN Calendar THEN returns calendar weekly key', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Calendar,
        SUB_AT_MID_MONTH,
        PlanInterval.Weekly,
      )

      expect(result).toEqual({ key: 'text_62ea7cd44cd4b14bb9ac1d9e' })
    })

    it('WHEN Anniversary THEN returns key with weekday variable', () => {
      const result = getBillingTimeHelperKey(
        BillingTimeEnum.Anniversary,
        SUB_AT_MID_MONTH,
        PlanInterval.Weekly,
      )

      expect(result?.key).toBe('text_62ea7cd44cd4b14bb9ac1da2')
      expect(result?.variables).toHaveProperty('day')
    })
  })
})
