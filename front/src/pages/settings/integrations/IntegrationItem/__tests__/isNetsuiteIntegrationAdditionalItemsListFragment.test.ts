import { CurrencyEnum, MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import { ItemMapping } from '~/pages/settings/integrations/common'

import { isNetsuiteIntegrationAdditionalItemsListFragment } from '../isNetsuiteIntegrationAdditionalItemsListFragment'
import type { IntegrationItemData } from '../types'

describe('isNetsuiteIntegrationAdditionalItemsListFragment', () => {
  const createMockItem = (overrides = {}): IntegrationItemData => ({
    id: 'item-1',
    icon: 'processing',
    label: 'Test Item',
    description: 'Test Description',
    mappingType: MappableTypeEnum.AddOn,
    integrationMappings: null,
    ...overrides,
  })

  const createMockCurrenciesItem = (overrides = {}): IntegrationItemData => ({
    id: 'currencies-item',
    icon: 'processing',
    label: 'Currencies',
    description: 'Currency mappings',
    mappingType: MappingTypeEnum.Currencies,
    integrationMappings: null,
    ...overrides,
  })

  const createMockItemMapping = (overrides = {}): ItemMapping =>
    ({
      __typename: 'CollectionMapping',
      id: 'mapping-1',
      mappingType: MappingTypeEnum.Currencies,
      currencies: [
        {
          __typename: 'CurrencyMappingItem',
          currencyCode: CurrencyEnum.Usd,
          currencyExternalCode: 'USD_EXTERNAL',
        },
        {
          __typename: 'CurrencyMappingItem',
          currencyCode: CurrencyEnum.Eur,
          currencyExternalCode: 'EUR_EXTERNAL',
        },
      ],
      ...overrides,
    }) as ItemMapping

  describe('when all conditions are met', () => {
    it('should return true for currencies mapping type with valid itemMapping containing currencies', () => {
      const item = createMockCurrenciesItem()
      const itemMapping = createMockItemMapping()

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(true)
    })

    it('should return true even when currencies array is empty', () => {
      const item = createMockCurrenciesItem()
      const itemMapping = createMockItemMapping({ currencies: [] })

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(true)
    })

    it('should return true when currencies is undefined but property exists', () => {
      const item = createMockCurrenciesItem()
      const itemMapping = createMockItemMapping({ currencies: undefined })

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(true)
    })
  })

  describe('when mapping type is not currencies', () => {
    it('should return false for AddOn mapping type', () => {
      const item = createMockItem({ mappingType: MappableTypeEnum.AddOn })
      const itemMapping = createMockItemMapping()

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(false)
    })

    it('should return false for BillableMetric mapping type', () => {
      const item = createMockItem({ mappingType: MappableTypeEnum.BillableMetric })
      const itemMapping = createMockItemMapping()

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(false)
    })

    it('should return false for other MappingTypeEnum values', () => {
      const item = createMockItem({ mappingType: MappingTypeEnum.Account })
      const itemMapping = createMockItemMapping()

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(false)
    })
  })

  describe('when itemMapping is invalid', () => {
    it('should return false when itemMapping is undefined', () => {
      const item = createMockCurrenciesItem()

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, undefined)

      expect(result).toBe(false)
    })

    it('should return false when itemMapping does not have currencies property', () => {
      const item = createMockCurrenciesItem()
      const itemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.Account,
        // No currencies property - this is a different type of mapping
      } as ItemMapping

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(false)
    })
  })

  describe('edge cases', () => {
    it('should return false when item mapping type is currencies but itemMapping is falsy', () => {
      const item = createMockCurrenciesItem()

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, undefined)

      expect(result).toBe(false)
    })

    it('should return false when item mapping type is currencies but itemMapping is wrong type', () => {
      const item = createMockCurrenciesItem()
      const itemMapping = {
        __typename: 'CollectionMapping',
        id: 'mapping-1',
        mappingType: MappingTypeEnum.Account,
      } as ItemMapping

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(false)
    })

    it('should return false when both conditions fail', () => {
      const item = createMockItem({ mappingType: MappableTypeEnum.AddOn })

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, undefined)

      expect(result).toBe(false)
    })

    it('should handle complex itemMapping objects correctly', () => {
      const item = createMockCurrenciesItem()
      const itemMapping = createMockItemMapping({
        additionalProperty: 'should not affect result',
        nestedObject: { prop: 'value' },
        currencies: [
          { lagoCurrency: 'USD', externalCurrency: 'USD_EXT' },
          { lagoCurrency: 'EUR', externalCurrency: 'EUR_EXT' },
          { lagoCurrency: 'GBP', externalCurrency: 'GBP_EXT' },
        ],
      })

      const result = isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)

      expect(result).toBe(true)
    })
  })

  describe('type guard functionality', () => {
    it('should narrow the type correctly when returning true', () => {
      const item = createMockCurrenciesItem()
      const itemMapping = createMockItemMapping()

      if (isNetsuiteIntegrationAdditionalItemsListFragment(item, itemMapping)) {
        // TypeScript should infer that itemMapping has currencies property
        expect(itemMapping.currencies).toBeDefined()
        expect(Array.isArray(itemMapping.currencies)).toBe(true)
      } else {
        fail('Type guard should have returned true')
      }
    })

    it('should work correctly in conditional logic', () => {
      const item = createMockCurrenciesItem()
      const validMapping = createMockItemMapping()
      const invalidMapping = {
        __typename: 'CollectionMapping',
        id: 'test',
        mappingType: MappingTypeEnum.Account,
      } as ItemMapping

      // Valid case
      let result = false

      if (isNetsuiteIntegrationAdditionalItemsListFragment(item, validMapping)) {
        result = true
      }
      expect(result).toBe(true)

      // Invalid case
      result = false
      if (isNetsuiteIntegrationAdditionalItemsListFragment(item, invalidMapping)) {
        result = true
      }
      expect(result).toBe(false)
    })
  })
})
