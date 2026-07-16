import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import {
  BillingEntityForIntegrationMapping,
  DEFAULT_MAPPING_KEY,
} from '~/pages/settings/integrations/common'
import { IntegrationItemData } from '~/pages/settings/integrations/IntegrationItem'

import { findItemMapping } from '../findItemMapping'
import { generateItemMappingForAllBillingEntities } from '../generateItemMappingForAllBillingEntities'
import { isNetsuiteIntegrationAdditionalItemsListFragment } from '../isNetsuiteIntegrationAdditionalItemsListFragment'

// Mock the helper functions
jest.mock('../findItemMapping')
jest.mock('../isNetsuiteIntegrationAdditionalItemsListFragment')

const mockFindItemMapping = findItemMapping as jest.MockedFunction<typeof findItemMapping>
const mockIsNetsuiteIntegrationAdditionalItemsListFragment =
  isNetsuiteIntegrationAdditionalItemsListFragment as jest.MockedFunction<
    typeof isNetsuiteIntegrationAdditionalItemsListFragment
  >

describe('generateItemMappingForAllBillingEntities', () => {
  const mockBillingEntities: Array<BillingEntityForIntegrationMapping> = [
    {
      id: 'entity1',
      key: 'entity1-key',
      name: 'Entity 1',
    },
    {
      id: null,
      key: DEFAULT_MAPPING_KEY,
      name: 'Default Entity',
    },
  ]

  beforeEach(() => {
    jest.clearAllMocks()
    mockFindItemMapping.mockReturnValue(undefined)
    mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)
  })

  describe('when no existing mapping is found', () => {
    it('should create default currency mapping for currencies type', () => {
      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Currency Item',
        description: 'Currency description',
        mappingType: MappingTypeEnum.Currencies,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: null,
          currencies: [],
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: null,
          currencies: [],
        },
      })
    })

    it('should create default tax mapping for tax type', () => {
      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Tax Item',
        description: 'Tax description',
        mappingType: MappingTypeEnum.Tax,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: null,
          itemExternalId: null,
          itemExternalName: undefined,
          itemExternalCode: undefined,
          taxCode: null,
          taxNexus: null,
          taxType: null,
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: null,
          itemExternalId: null,
          itemExternalName: undefined,
          itemExternalCode: undefined,
          taxCode: null,
          taxNexus: null,
          taxType: null,
        },
      })
    })

    it('should create default mappable mapping for AddOn type', () => {
      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'AddOn Item',
        description: 'AddOn description',
        mappingType: MappableTypeEnum.AddOn,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: null,
          itemExternalId: null,
          itemExternalName: undefined,
          itemExternalCode: undefined,
          lagoMappableId: 'item1',
          lagoMappableName: 'AddOn Item',
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: null,
          itemExternalId: null,
          itemExternalName: undefined,
          itemExternalCode: undefined,
          lagoMappableId: 'item1',
          lagoMappableName: 'AddOn Item',
        },
      })
    })

    it('should create default non-tax mapping for other types', () => {
      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Account Item',
        description: 'Account description',
        mappingType: MappingTypeEnum.Account,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: null,
          itemExternalId: null,
          itemExternalName: undefined,
          itemExternalCode: undefined,
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: null,
          itemExternalId: null,
          itemExternalName: undefined,
          itemExternalCode: undefined,
        },
      })
    })
  })

  describe('when existing mapping is found', () => {
    it('should handle Netsuite additional items list fragment (currency mapping)', () => {
      const mockItemMapping = {
        id: 'mapping1',
        mappingType: MappingTypeEnum.Currencies,
        currencies: [{ currencyCode: 'USD', currencyExternalCode: 'ext-usd' }],
      }

      mockFindItemMapping.mockReturnValue(mockItemMapping) // For testing purposes)
      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(true)

      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Currency Item',
        description: 'Currency description',
        mappingType: MappingTypeEnum.Currencies,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: 'mapping1',
          currencies: [{ currencyCode: 'USD', currencyExternalCode: 'ext-usd' }],
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: 'mapping1',
          currencies: [{ currencyCode: 'USD', currencyExternalCode: 'ext-usd' }],
        },
      })
    })

    it('should handle tax mapping with existing data', () => {
      const mockItemMapping = {
        id: 'mapping1',
        externalId: 'ext-123',
        externalName: 'External Tax Item',
        externalAccountCode: 'TAX-001',
        taxCode: 'TAX_CODE',
        taxNexus: 'TAX_NEXUS',
        taxType: 'TAX_TYPE',
        mappingType: MappingTypeEnum.Tax,
      }

      mockFindItemMapping.mockReturnValue(mockItemMapping) // For testing purposes)

      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Tax Item',
        description: 'Tax description',
        mappingType: MappingTypeEnum.Tax,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: 'mapping1',
          itemExternalId: 'ext-123',
          itemExternalName: 'External Tax Item',
          itemExternalCode: 'TAX-001',
          taxCode: 'TAX_CODE',
          taxNexus: 'TAX_NEXUS',
          taxType: 'TAX_TYPE',
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: 'mapping1',
          itemExternalId: 'ext-123',
          itemExternalName: 'External Tax Item',
          itemExternalCode: 'TAX-001',
          taxCode: 'TAX_CODE',
          taxNexus: 'TAX_NEXUS',
          taxType: 'TAX_TYPE',
        },
      })
    })

    it('should handle mappable types with existing data', () => {
      const mockItemMapping = {
        id: 'mapping1',
        externalId: 'ext-123',
        externalName: 'External AddOn',
        externalAccountCode: 'ADD-001',
        mappingType: MappingTypeEnum.FallbackItem,
      }

      mockFindItemMapping.mockReturnValue(mockItemMapping) // For testing purposes)

      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'AddOn Item',
        description: 'AddOn description',
        mappingType: MappableTypeEnum.AddOn,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: 'mapping1',
          itemExternalId: 'ext-123',
          itemExternalName: 'External AddOn',
          itemExternalCode: 'ADD-001',
          lagoMappableId: 'item1',
          lagoMappableName: 'AddOn Item',
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: 'mapping1',
          itemExternalId: 'ext-123',
          itemExternalName: 'External AddOn',
          itemExternalCode: 'ADD-001',
          lagoMappableId: 'item1',
          lagoMappableName: 'AddOn Item',
        },
      })
    })

    it('should handle non-tax mapping with existing data', () => {
      const mockItemMapping = {
        id: 'mapping1',
        externalId: 'ext-789',
        externalName: 'External Account',
        externalAccountCode: 'ACC-003',
        mappingType: MappingTypeEnum.FallbackItem,
      }

      mockFindItemMapping.mockReturnValue(mockItemMapping) // For testing purposes)

      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Account Item',
        description: 'Account description',
        mappingType: MappingTypeEnum.Account,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(result).toEqual({
        entity1: {
          itemId: 'mapping1',
          itemExternalId: 'ext-789',
          itemExternalName: 'External Account',
          itemExternalCode: 'ACC-003',
        },
        [DEFAULT_MAPPING_KEY]: {
          itemId: 'mapping1',
          itemExternalId: 'ext-789',
          itemExternalName: 'External Account',
          itemExternalCode: 'ACC-003',
        },
      })
    })
  })

  describe('edge cases', () => {
    it('should handle empty billing entities array', () => {
      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Account Item',
        description: 'Account description',
        mappingType: MappingTypeEnum.Account,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, [])

      expect(result).toEqual({})
    })

    it('should use billing entity id or DEFAULT_MAPPING_KEY as the key', () => {
      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Account Item',
        description: 'Account description',
        mappingType: MappingTypeEnum.Account,
        integrationMappings: [],
      }

      const result = generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(Object.keys(result)).toEqual(['entity1', DEFAULT_MAPPING_KEY])
    })

    it('should call findItemMapping with correct parameters', () => {
      const item: IntegrationItemData = {
        id: 'item1',
        icon: 'coin-dollar',
        label: 'Account Item',
        description: 'Account description',
        mappingType: MappingTypeEnum.Account,
        integrationMappings: [],
      }

      generateItemMappingForAllBillingEntities(item, mockBillingEntities)

      expect(mockFindItemMapping).toHaveBeenCalledTimes(2)
      expect(mockFindItemMapping).toHaveBeenNthCalledWith(1, item, 'entity1')
      expect(mockFindItemMapping).toHaveBeenNthCalledWith(2, item, null)
    })
  })
})
