import { CurrencyEnum, MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import { ItemMapping } from '~/pages/settings/integrations/common'
import { IntegrationItemData } from '~/pages/settings/integrations/IntegrationItem'

import { findItemMapping } from '../findItemMapping'
import { isNetsuiteIntegrationAdditionalItemsListFragment } from '../isNetsuiteIntegrationAdditionalItemsListFragment'

// Mock the isNetsuiteIntegrationAdditionalItemsListFragment function
jest.mock('../isNetsuiteIntegrationAdditionalItemsListFragment', () => ({
  isNetsuiteIntegrationAdditionalItemsListFragment: jest.fn(),
}))

const mockIsNetsuiteIntegrationAdditionalItemsListFragment =
  isNetsuiteIntegrationAdditionalItemsListFragment as jest.MockedFunction<
    typeof isNetsuiteIntegrationAdditionalItemsListFragment
  >

describe('findItemMapping', () => {
  const mockBillingEntityId = 'billing-entity-123'

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('when item has no integration mappings', () => {
    it('returns undefined when integrationMappings is null', () => {
      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: null,
      }

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })

    it('returns undefined when integrationMappings is undefined', () => {
      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: undefined,
      }

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })

    it('returns undefined when integrationMappings is empty array', () => {
      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: [],
      }

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })
  })

  describe('when item is NetSuite additional items with currencies', () => {
    it('returns the currency mapping when isNetsuiteIntegrationAdditionalItemsListFragment returns true', () => {
      const currencyMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'currency-mapping-1',
        mappingType: MappingTypeEnum.Currencies,
        currencies: [
          {
            __typename: 'CurrencyMappingItem',
            currencyCode: CurrencyEnum.Usd,
            currencyExternalCode: 'USD_EXT',
          },
        ],
      }

      const otherMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'other-mapping-1',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'coin-dollar',
        label: 'Currency Mapping',
        description: 'Currency mapping description',
        mappingType: MappingTypeEnum.Currencies,
        integrationMappings: [currencyMapping, otherMapping],
      }

      // Mock to return true for currency mapping, false for others
      mockIsNetsuiteIntegrationAdditionalItemsListFragment
        .mockReturnValueOnce(true) // first mapping (currency)
        .mockReturnValueOnce(false) // second mapping (other)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBe(currencyMapping)
      expect(mockIsNetsuiteIntegrationAdditionalItemsListFragment).toHaveBeenCalledTimes(1)
      expect(mockIsNetsuiteIntegrationAdditionalItemsListFragment).toHaveBeenCalledWith(
        item,
        currencyMapping,
      )
    })

    it('returns undefined when no currency mapping matches', () => {
      const nonCurrencyMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'other-mapping-1',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'coin-dollar',
        label: 'Currency Mapping',
        description: 'Currency mapping description',
        mappingType: MappingTypeEnum.Currencies,
        integrationMappings: [nonCurrencyMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
      expect(mockIsNetsuiteIntegrationAdditionalItemsListFragment).toHaveBeenCalledWith(
        item,
        nonCurrencyMapping,
      )
    })
  })

  describe('when mapping has mappingType property', () => {
    it('returns matching mapping when mappingType and billingEntityId match', () => {
      const matchingMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        billingEntityId: mockBillingEntityId,
      }

      const nonMatchingMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-2',
        mappingType: MappingTypeEnum.Currencies,
        externalId: 'ext-456',
        externalName: 'Other External Name',
        externalAccountCode: 'ACC-456',
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: [nonMatchingMapping, matchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBe(matchingMapping)
    })

    it('returns undefined when mappingType matches but billingEntityId does not', () => {
      const nonMatchingMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        billingEntityId: 'different-billing-entity',
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: [nonMatchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })

    it('returns undefined when billingEntityId matches but mappingType does not', () => {
      const nonMatchingMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.Currencies,
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: [nonMatchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })

    it('handles null billingEntityId correctly', () => {
      const matchingMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        billingEntityId: null,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: [matchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, null)

      expect(result).toBe(matchingMapping)
    })
  })

  describe('when mapping has mappableType property', () => {
    it('returns matching mapping when mappableType and billingEntityId match', () => {
      const matchingMapping: ItemMapping = {
        __typename: 'Mapping',
        id: 'mapping-1',
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        mappableType: MappableTypeEnum.AddOn,
        billingEntityId: mockBillingEntityId,
      }

      const nonMatchingMapping: ItemMapping = {
        __typename: 'Mapping',
        id: 'mapping-2',
        externalId: 'ext-456',
        externalName: 'Other External Name',
        externalAccountCode: 'ACC-456',
        mappableType: MappableTypeEnum.BillableMetric,
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappableTypeEnum.AddOn,
        integrationMappings: [nonMatchingMapping, matchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBe(matchingMapping)
    })

    it('returns undefined when mappableType matches but billingEntityId does not', () => {
      const nonMatchingMapping: ItemMapping = {
        __typename: 'Mapping',
        id: 'mapping-1',
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        mappableType: MappableTypeEnum.AddOn,
        billingEntityId: 'different-billing-entity',
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappableTypeEnum.AddOn,
        integrationMappings: [nonMatchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })

    it('returns undefined when billingEntityId matches but mappableType does not', () => {
      const nonMatchingMapping: ItemMapping = {
        __typename: 'Mapping',
        id: 'mapping-1',
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        mappableType: MappableTypeEnum.BillableMetric,
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappableTypeEnum.AddOn,
        integrationMappings: [nonMatchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })

    it('handles null billingEntityId correctly with mappableType', () => {
      const matchingMapping: ItemMapping = {
        __typename: 'Mapping',
        id: 'mapping-1',
        externalId: 'ext-123',
        externalName: 'External Name',
        externalAccountCode: 'ACC-123',
        mappableType: MappableTypeEnum.AddOn,
        billingEntityId: null,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappableTypeEnum.AddOn,
        integrationMappings: [matchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, null)

      expect(result).toBe(matchingMapping)
    })
  })

  describe('when mapping has neither mappingType nor mappableType property', () => {
    it('returns undefined for mappings without required properties', () => {
      // Create a mapping that doesn't have mappingType or mappableType
      const invalidMapping = {
        __typename: 'SomeOtherType' as const,
        id: 'mapping-1',
        externalId: 'ext-123',
        externalName: 'External Name',
        billingEntityId: mockBillingEntityId,
      } as unknown as ItemMapping

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: [invalidMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBeUndefined()
    })
  })

  describe('edge cases and complex scenarios', () => {
    it('finds the first matching mapping when multiple mappings match', () => {
      const firstMatchingMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'First External Name',
        externalAccountCode: 'ACC-123',
        billingEntityId: mockBillingEntityId,
      }

      const secondMatchingMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-2',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-456',
        externalName: 'Second External Name',
        externalAccountCode: 'ACC-456',
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappingTypeEnum.FallbackItem,
        integrationMappings: [firstMatchingMapping, secondMatchingMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBe(firstMatchingMapping)
    })

    it('handles mixed mapping types correctly', () => {
      const collectionMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'Collection Mapping',
        externalAccountCode: 'ACC-123',
        billingEntityId: 'different-billing-entity',
      }

      const itemMapping: ItemMapping = {
        __typename: 'Mapping',
        id: 'mapping-2',
        externalId: 'ext-456',
        externalName: 'Item Mapping',
        externalAccountCode: 'ACC-456',
        mappableType: MappableTypeEnum.AddOn,
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'box',
        label: 'Test Item',
        description: 'Test Description',
        mappingType: MappableTypeEnum.AddOn,
        integrationMappings: [collectionMapping, itemMapping],
      }

      mockIsNetsuiteIntegrationAdditionalItemsListFragment.mockReturnValue(false)

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBe(itemMapping)
    })

    it('handles NetSuite currency mapping with complex scenario', () => {
      const currencyMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'currency-mapping',
        mappingType: MappingTypeEnum.Currencies,
        currencies: [
          {
            __typename: 'CurrencyMappingItem',
            currencyCode: CurrencyEnum.Eur,
            currencyExternalCode: 'EUR_EXT',
          },
          {
            __typename: 'CurrencyMappingItem',
            currencyCode: CurrencyEnum.Usd,
            currencyExternalCode: 'USD_EXT',
          },
        ],
      }

      const regularMapping: ItemMapping = {
        __typename: 'CollectionMapping',
        id: 'regular-mapping',
        mappingType: MappingTypeEnum.FallbackItem,
        externalId: 'ext-123',
        externalName: 'Regular Mapping',
        externalAccountCode: 'ACC-123',
        billingEntityId: mockBillingEntityId,
      }

      const item: IntegrationItemData = {
        id: 'test-item',
        icon: 'coin-dollar',
        label: 'Currency Mapping',
        description: 'Currency mapping description',
        mappingType: MappingTypeEnum.Currencies,
        integrationMappings: [regularMapping, currencyMapping],
      }

      // Mock to return false for regular mapping, true for currency mapping
      mockIsNetsuiteIntegrationAdditionalItemsListFragment
        .mockReturnValueOnce(false) // regular mapping
        .mockReturnValueOnce(true) // currency mapping

      const result = findItemMapping(item, mockBillingEntityId)

      expect(result).toBe(currencyMapping)
      expect(mockIsNetsuiteIntegrationAdditionalItemsListFragment).toHaveBeenCalledTimes(2)
    })
  })
})
