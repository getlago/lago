import { LocalPricingUnitType } from '~/components/plans/types'
import { chargeSchema } from '~/formValidation/chargeSchema'
import { ChargeModelEnum } from '~/generated/graphql'

describe('chargeSchema', () => {
  describe('valid appliedPricingUnit', () => {
    it('should be valid when appliedPricingUnit is not provided', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeTruthy()
    })

    it('should be valid when appliedPricingUnit is null', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: null,
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeTruthy()
    })

    it('should be valid with Fiat pricing unit', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Fiat,
            code: 'USD',
            shortName: '$',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeTruthy()
    })

    it('should be valid with Custom pricing unit with valid conversionRate', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Custom,
            code: 'TOKENS',
            shortName: 'TKN',
            conversionRate: '1.5',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeTruthy()
    })

    it('should be valid with Custom pricing unit with conversionRate as "1"', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Custom,
            code: 'POINTS',
            shortName: 'PTS',
            conversionRate: '1',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeTruthy()
    })
  })

  describe('invalid appliedPricingUnit', () => {
    it('should be invalid when type is missing', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            code: 'USD',
            shortName: '$',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })

    it('should be invalid when code is missing', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Fiat,
            shortName: '$',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })

    it('should be invalid when shortName is missing', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Fiat,
            code: 'USD',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })

    it('should be invalid when Custom type is missing conversionRate', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Custom,
            code: 'TOKENS',
            shortName: 'TKN',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })

    it('should be invalid when Custom type has empty conversionRate', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Custom,
            code: 'TOKENS',
            shortName: 'TKN',
            conversionRate: '',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })

    it('should be invalid when Custom type has conversionRate of "0"', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Custom,
            code: 'TOKENS',
            shortName: 'TKN',
            conversionRate: '0',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })

    it('should be invalid when Custom type has negative conversionRate', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Custom,
            code: 'TOKENS',
            shortName: 'TKN',
            conversionRate: '-1',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })

    it('should be invalid when Custom type has invalid conversionRate', () => {
      const values = [
        {
          chargeModel: ChargeModelEnum.Standard,
          appliedPricingUnit: {
            type: LocalPricingUnitType.Custom,
            code: 'TOKENS',
            shortName: 'TKN',
            conversionRate: 'invalid',
          },
          properties: {
            amount: '10',
          },
        },
      ]
      const result = chargeSchema.isValidSync(values)

      expect(result).toBeFalsy()
    })
  })
})
