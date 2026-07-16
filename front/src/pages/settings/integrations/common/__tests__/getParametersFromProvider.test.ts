import { IntegrationTypeEnum } from '~/generated/graphql'

import { getParametersFromProvider } from '../getParametersFromProvider'

// Mock the extractOptionValue function
jest.mock('~/pages/settings/integrations/XeroIntegrationMapItemDrawer/extractOptionValue', () => ({
  extractOptionValue: jest.fn(),
}))

const mockExtractOptionValue = jest.requireMock(
  '~/pages/settings/integrations/XeroIntegrationMapItemDrawer/extractOptionValue',
).extractOptionValue

describe('getParametersFromProvider', () => {
  afterEach(() => {
    jest.clearAllMocks()
  })

  describe('Input validation', () => {
    it('should return failure when inputValues is null', () => {
      const result = getParametersFromProvider(null, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })

    it('should return failure when inputValues is undefined', () => {
      const result = getParametersFromProvider(undefined, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })

    it('should return failure when inputValues is not an object', () => {
      const result = getParametersFromProvider('not an object', IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })

    it('should return failure when inputValues is a primitive', () => {
      const result = getParametersFromProvider(123, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })
  })

  describe('Anrok provider', () => {
    it('should return success with parameters when valid input is provided', () => {
      const inputValues = {
        externalId: 'anrok-123',
        externalName: 'Anrok Item',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: 'anrok-123',
          externalName: 'Anrok Item',
        },
      })
    })

    it('should handle undefined externalId and externalName', () => {
      const inputValues = {
        externalId: undefined,
        externalName: undefined,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
        },
      })
    })

    it('should convert non-string values to strings', () => {
      const inputValues = {
        externalId: 123,
        externalName: true,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: '123',
          externalName: 'true',
        },
      })
    })

    it('should return failure when externalId is missing', () => {
      const inputValues = {
        externalName: 'Anrok Item',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })

    it('should return failure when externalName is missing', () => {
      const inputValues = {
        externalId: 'anrok-123',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })

    it('should handle falsy values correctly', () => {
      const inputValues = {
        externalId: '',
        externalName: 0,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: undefined, // empty string becomes undefined
          externalName: '0', // number 0 becomes string "0"
        },
      })
    })
  })

  describe('Avalara provider', () => {
    it('should return success with parameters when valid input is provided', () => {
      const inputValues = {
        externalId: 'avalara-456',
        externalName: 'Avalara Item',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Avalara)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: 'avalara-456',
          externalName: 'Avalara Item',
        },
      })
    })

    it('should handle undefined values', () => {
      const inputValues = {
        externalId: undefined,
        externalName: undefined,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Avalara)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
        },
      })
    })

    it('should return failure when required fields are missing', () => {
      const inputValues = {
        externalId: 'avalara-456',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Avalara)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })
  })

  describe('Netsuite provider', () => {
    it('should return success with all parameters when full input is provided', () => {
      const inputValues = {
        externalId: 'netsuite-789',
        externalName: 'Netsuite Item',
        externalAccountCode: 'NS-CODE-123',
        taxCode: 'TAX001',
        taxNexus: 'US-CA',
        taxType: 'Sales',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: 'netsuite-789',
          externalName: 'Netsuite Item',
          externalAccountCode: 'NS-CODE-123',
          taxCode: 'TAX001',
          taxNexus: 'US-CA',
          taxType: 'Sales',
        },
      })
    })

    it('should return success with basic parameters when tax fields are missing', () => {
      const inputValues = {
        externalId: 'netsuite-789',
        externalName: 'Netsuite Item',
        externalAccountCode: 'NS-CODE-123',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: 'netsuite-789',
          externalName: 'Netsuite Item',
          externalAccountCode: 'NS-CODE-123',
          taxCode: undefined,
          taxNexus: undefined,
          taxType: undefined,
        },
      })
    })

    it('should return success with tax parameters when basic fields are missing but tax fields are present', () => {
      const inputValues = {
        taxCode: 'TAX001',
        taxNexus: 'US-CA',
        taxType: 'Sales',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: '',
          externalName: '',
          externalAccountCode: '',
          taxCode: 'TAX001',
          taxNexus: 'US-CA',
          taxType: 'Sales',
        },
      })
    })

    it('should handle undefined values correctly', () => {
      const inputValues = {
        externalId: undefined,
        externalName: undefined,
        externalAccountCode: undefined,
        taxCode: undefined,
        taxNexus: undefined,
        taxType: undefined,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: '',
          externalName: '',
          externalAccountCode: '',
          taxCode: undefined,
          taxNexus: undefined,
          taxType: undefined,
        },
      })
    })

    it('should handle falsy values for basic fields', () => {
      const inputValues = {
        externalId: '',
        externalName: 0,
        externalAccountCode: false,
        taxCode: 'TAX001',
        taxNexus: 'US-CA',
        taxType: 'Sales',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: '', // empty string becomes empty string for basic fields
          externalName: '0', // number 0 becomes string "0"
          externalAccountCode: 'false', // boolean false becomes string "false"
          taxCode: 'TAX001',
          taxNexus: 'US-CA',
          taxType: 'Sales',
        },
      })
    })

    it('should handle falsy values for tax fields', () => {
      const inputValues = {
        externalId: 'netsuite-789',
        externalName: 'Netsuite Item',
        externalAccountCode: 'NS-CODE-123',
        taxCode: '',
        taxNexus: 0,
        taxType: false,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: 'netsuite-789',
          externalName: 'Netsuite Item',
          externalAccountCode: 'NS-CODE-123',
          taxCode: undefined, // empty string becomes undefined for tax fields
          taxNexus: '0', // number 0 becomes string "0"
          taxType: 'false', // boolean false becomes string "false"
        },
      })
    })

    it('should return failure when neither basic nor tax parameters are complete', () => {
      const inputValues = {
        externalId: 'netsuite-789',
        taxCode: 'TAX001',
        // Missing required combinations
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })
  })

  describe('Xero provider', () => {
    it('should return success with parameters when valid selectedElementValue is provided', () => {
      const inputValues = {
        selectedElementValue: 'id123:::code456:::Item Name',
      }

      mockExtractOptionValue.mockReturnValue({
        externalId: 'id123',
        externalAccountCode: 'code456',
        externalName: 'Item Name',
      })

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: 'id123',
          externalAccountCode: 'code456',
          externalName: 'Item Name',
        },
      })
      expect(mockExtractOptionValue).toHaveBeenCalledWith('id123:::code456:::Item Name')
    })

    it('should handle extractOptionValue returning undefined values', () => {
      const inputValues = {
        selectedElementValue: 'invalid-format',
      }

      mockExtractOptionValue.mockReturnValue({
        externalId: undefined,
        externalAccountCode: undefined,
        externalName: undefined,
      })

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: undefined,
          externalAccountCode: undefined,
          externalName: undefined,
        },
      })
    })

    it('should return failure when selectedElementValue is missing', () => {
      const inputValues = {
        otherField: 'value',
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
      expect(mockExtractOptionValue).not.toHaveBeenCalled()
    })

    it('should return failure when selectedElementValue is not a string', () => {
      const inputValues = {
        selectedElementValue: 123,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
      expect(mockExtractOptionValue).not.toHaveBeenCalled()
    })

    it('should return failure when selectedElementValue is null', () => {
      const inputValues = {
        selectedElementValue: null,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
      expect(mockExtractOptionValue).not.toHaveBeenCalled()
    })

    it('should return failure when selectedElementValue is undefined', () => {
      const inputValues = {
        selectedElementValue: undefined,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
      expect(mockExtractOptionValue).not.toHaveBeenCalled()
    })

    it('should handle empty string selectedElementValue', () => {
      const inputValues = {
        selectedElementValue: '',
      }

      mockExtractOptionValue.mockReturnValue({
        externalId: undefined,
        externalAccountCode: undefined,
        externalName: undefined,
      })

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: undefined,
          externalAccountCode: undefined,
          externalName: undefined,
        },
      })
      expect(mockExtractOptionValue).toHaveBeenCalledWith('')
    })
  })

  describe('Edge cases', () => {
    it('should handle all supported providers correctly', () => {
      // Test that all supported providers are handled correctly
      const inputValues = {
        externalId: 'some-id',
        externalName: 'some-name',
        externalAccountCode: 'some-code',
        selectedElementValue: 'id:::code:::name',
      }

      const anrokResult = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(anrokResult.success).toBe(true)

      const avalaraResult = getParametersFromProvider(inputValues, IntegrationTypeEnum.Avalara)

      expect(avalaraResult.success).toBe(true)

      const netsuiteResult = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(netsuiteResult.success).toBe(true)

      mockExtractOptionValue.mockReturnValue({
        externalId: 'id',
        externalAccountCode: 'code',
        externalName: 'name',
      })

      const xeroResult = getParametersFromProvider(inputValues, IntegrationTypeEnum.Xero)

      expect(xeroResult.success).toBe(true)
    })
  })

  describe('Edge cases and type handling', () => {
    it('should handle boolean values correctly for Anrok', () => {
      const inputValues = {
        externalId: true,
        externalName: false,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Anrok)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: 'true',
          externalName: 'false',
        },
      })
    })

    it('should handle number values correctly for Netsuite', () => {
      const inputValues = {
        externalId: 123,
        externalName: 456,
        externalAccountCode: 789,
        taxCode: 0, // falsy number
        taxNexus: 999,
        taxType: -1,
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Netsuite)

      expect(result).toEqual({
        success: true,
        parameters: {
          externalId: '123',
          externalName: '456',
          externalAccountCode: '789',
          taxCode: '0',
          taxNexus: '999',
          taxType: '-1',
        },
      })
    })

    it('should handle array values by converting to string for Avalara', () => {
      const inputValues = {
        externalId: ['array', 'value'],
        externalName: { object: 'value' },
      }

      const result = getParametersFromProvider(inputValues, IntegrationTypeEnum.Avalara)

      expect(result).toEqual({
        success: false,
        parameters: undefined,
      })
    })
  })
})
