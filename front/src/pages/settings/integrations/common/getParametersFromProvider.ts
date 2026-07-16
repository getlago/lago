import { IntegrationTypeEnum } from '~/generated/graphql'
import { extractOptionValue } from '~/pages/settings/integrations/XeroIntegrationMapItemDrawer/extractOptionValue'

import {
  AvalaraAndAnrokParameters,
  MappableIntegrationProvider,
  NetsuiteParameters,
  XeroParameters,
} from './types'

const safeStringConversion = (value: unknown): string | undefined => {
  if (value === undefined || value === null || value === '') {
    return undefined
  }
  if (typeof value === 'object') {
    return undefined // Don't convert objects/arrays to strings
  }
  return `${value}`
}

const safeStringConversionOrEmpty = (value: unknown): string => {
  if (value === undefined || value === null || value === '') {
    return ''
  }
  if (typeof value === 'object') {
    return '' // Don't convert objects/arrays to strings
  }
  return `${value}`
}

export const getParametersFromProvider = <FormValues>(
  inputValues: FormValues,
  provider: MappableIntegrationProvider,
):
  | { success: false; parameters: undefined }
  | {
      success: true
      parameters: AvalaraAndAnrokParameters
    }
  | {
      success: true
      parameters: NetsuiteParameters
    }
  | {
      success: true
      parameters: XeroParameters
    } => {
  if (!inputValues || typeof inputValues !== 'object') {
    return {
      success: false,
      parameters: undefined,
    }
  }

  switch (provider) {
    case IntegrationTypeEnum.Anrok: {
      if (!('externalId' in inputValues) || !('externalName' in inputValues)) {
        return {
          success: false,
          parameters: undefined,
        }
      }

      // Check if any field is an object (array or object), return failure
      if (
        typeof inputValues.externalId === 'object' ||
        typeof inputValues.externalName === 'object'
      ) {
        return {
          success: false,
          parameters: undefined,
        }
      }

      return {
        success: true,
        parameters: {
          externalId: safeStringConversion(inputValues.externalId),
          externalName: safeStringConversion(inputValues.externalName),
        },
      }
    }

    case IntegrationTypeEnum.Avalara: {
      if (!('externalId' in inputValues) || !('externalName' in inputValues)) {
        return {
          success: false,
          parameters: undefined,
        }
      }

      // Check if any field is an object (array or object), return failure
      if (
        typeof inputValues.externalId === 'object' ||
        typeof inputValues.externalName === 'object'
      ) {
        return {
          success: false,
          parameters: undefined,
        }
      }

      return {
        success: true,
        parameters: {
          externalId: safeStringConversion(inputValues.externalId),
          externalName: safeStringConversion(inputValues.externalName),
        },
      }
    }

    case IntegrationTypeEnum.Netsuite: {
      if (
        (!('taxCode' in inputValues) ||
          !('taxNexus' in inputValues) ||
          !('taxType' in inputValues)) &&
        (!('externalId' in inputValues) ||
          !('externalName' in inputValues) ||
          !('externalAccountCode' in inputValues))
      ) {
        return {
          success: false,
          parameters: undefined,
        }
      }

      /*
       * Netsuite Integration Parameters. externalId, externalName and externalAccountCode are always required
       * taxCode, taxNexus and taxType are only required in Tax Mapping context
       */
      return {
        success: true,
        parameters: {
          externalId:
            'externalId' in inputValues ? safeStringConversionOrEmpty(inputValues.externalId) : '',
          externalName:
            'externalName' in inputValues
              ? safeStringConversionOrEmpty(inputValues.externalName)
              : '',
          externalAccountCode:
            'externalAccountCode' in inputValues
              ? safeStringConversionOrEmpty(inputValues.externalAccountCode)
              : '',
          taxCode: 'taxCode' in inputValues ? safeStringConversion(inputValues.taxCode) : undefined,
          taxNexus:
            'taxNexus' in inputValues ? safeStringConversion(inputValues.taxNexus) : undefined,
          taxType: 'taxType' in inputValues ? safeStringConversion(inputValues.taxType) : undefined,
        },
      }
    }

    case IntegrationTypeEnum.Xero: {
      if (!('selectedElementValue' in inputValues)) {
        return {
          success: false,
          parameters: undefined,
        }
      }

      // Have to split to let ts know it exist in the object
      if (typeof inputValues.selectedElementValue !== 'string') {
        return {
          success: false,
          parameters: undefined,
        }
      }

      const { externalAccountCode, externalId, externalName } = extractOptionValue(
        inputValues.selectedElementValue,
      )

      return {
        success: true,
        parameters: {
          externalAccountCode,
          externalId,
          externalName,
        },
      }
    }

    // Shouldn't work if it's an unknown provider
    default:
      return {
        success: false,
        parameters: undefined,
      }
  }
}
