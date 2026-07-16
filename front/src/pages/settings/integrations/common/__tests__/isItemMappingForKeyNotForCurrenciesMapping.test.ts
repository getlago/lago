import { CurrencyEnum, MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import {
  ItemMappingForCurrenciesMapping,
  ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common/types'

import { isItemMappingForKeyForCurrenciesMapping } from '../isItemMappingForKeyForCurrenciesMapping'
import { isItemMappingForKeyNotForCurrenciesMapping } from '../isItemMappingForKeyNotForCurrenciesMapping'

describe('isItemMappingForKeyNotForCurrenciesMapping', () => {
  const createMockItem = (mappingType: MappingTypeEnum | MappableTypeEnum) => ({
    id: 'test-item-id',
    icon: 'bank' as const,
    label: 'Test Item',
    description: 'Test description',
    mappingType,
    integrationMappings: [],
  })

  const createMockItemMapping = (
    defaultValue: ItemMappingForCurrenciesMapping | Record<string, unknown> | null = null,
  ): ItemMappingPerBillingEntity => {
    if (defaultValue === null) {
      return {} as ItemMappingPerBillingEntity
    }
    return {
      default: defaultValue,
    } as ItemMappingPerBillingEntity
  }

  const validCurrenciesMapping: ItemMappingForCurrenciesMapping = {
    itemId: 'test-item-id',
    currencies: [
      {
        currencyCode: CurrencyEnum.Usd,
        currencyExternalCode: 'USD_EXTERNAL',
      },
    ],
  }

  const validTaxMapping = {
    itemId: 'test-item-id',
    itemExternalId: 'ext-123',
    itemExternalName: 'External Tax Item',
    itemExternalCode: 'TAX-001',
    taxCode: 'TAX_CODE',
    taxNexus: 'TAX_NEXUS',
    taxType: 'TAX_TYPE',
  }

  const validMappableMapping = {
    itemId: 'test-item-id',
    itemExternalId: 'ext-123',
    itemExternalName: 'External AddOn',
    itemExternalCode: 'ADD-001',
    lagoMappableId: 'item1',
    lagoMappableName: 'AddOn Item',
  }

  const validNonTaxMapping = {
    itemId: 'test-item-id',
    itemExternalId: 'ext-789',
    itemExternalName: 'External Account',
    itemExternalCode: 'ACC-003',
  }

  describe('when item mappingType is Currencies', () => {
    const item = createMockItem(MappingTypeEnum.Currencies)

    it('returns false when itemMapping has valid default currencies mapping', () => {
      const itemMapping = createMockItemMapping(validCurrenciesMapping)

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns false when itemMapping has valid default with empty currencies array', () => {
      const itemMapping = createMockItemMapping({
        itemId: 'test-item-id',
        currencies: [],
      })

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns true when itemMapping is null', () => {
      const itemMapping = null as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when itemMapping is undefined', () => {
      const itemMapping = undefined as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when itemMapping does not have default property', () => {
      const itemMapping = {
        someOtherProperty: 'value',
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when itemMapping.default is null', () => {
      const itemMapping = createMockItemMapping(null)

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when itemMapping.default is not an object', () => {
      const itemMapping = {
        default: 'not-an-object',
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when itemMapping.default does not have currencies property', () => {
      const itemMapping = createMockItemMapping({
        itemId: 'test-item-id',
        someOtherProperty: 'value',
      })

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns false when itemMapping.default has currencies property even if null', () => {
      const itemMapping = createMockItemMapping({
        itemId: 'test-item-id',
        currencies: null as unknown as ItemMappingForCurrenciesMapping['currencies'],
      })

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })
  })

  describe('when item mappingType is not Currencies', () => {
    const nonCurrencyMappingTypes = [
      MappingTypeEnum.Account,
      MappingTypeEnum.Coupon,
      MappingTypeEnum.CreditNote,
      MappingTypeEnum.FallbackItem,
      MappingTypeEnum.MinimumCommitment,
      MappingTypeEnum.PrepaidCredit,
      MappingTypeEnum.SubscriptionFee,
      MappingTypeEnum.Tax,
    ]

    nonCurrencyMappingTypes.forEach((mappingType) => {
      it(`returns true when mappingType is ${mappingType} even with valid currencies mapping`, () => {
        const item = createMockItem(mappingType)
        const itemMapping = createMockItemMapping(validCurrenciesMapping)

        const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

        expect(result).toBe(true)
      })
    })

    it('returns true when mappingType is Tax with valid tax mapping', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = createMockItemMapping(validTaxMapping)

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when mappingType is Account with valid non-tax mapping', () => {
      const item = createMockItem(MappingTypeEnum.Account)
      const itemMapping = createMockItemMapping(validNonTaxMapping)

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })
  })

  describe('when item mappingType is MappableType', () => {
    it('returns true when mappingType is AddOn with valid mappable mapping', () => {
      const item = createMockItem(MappableTypeEnum.AddOn)
      const itemMapping = createMockItemMapping(validMappableMapping)

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when mappingType is BillableMetric with valid mappable mapping', () => {
      const item = createMockItem(MappableTypeEnum.BillableMetric)
      const itemMapping = createMockItemMapping(validMappableMapping)

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when mappingType is AddOn even with currencies mapping (should be excluded)', () => {
      const item = createMockItem(MappableTypeEnum.AddOn)
      const itemMapping = createMockItemMapping(validCurrenciesMapping)

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })
  })

  describe('type narrowing', () => {
    it('narrows the type correctly when returning true for non-currency mapping', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = createMockItemMapping(validTaxMapping)

      if (isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')) {
        // TypeScript should now know that itemMapping.default is NOT ItemMappingForCurrenciesMapping
        expect(itemMapping.default).toBeDefined()
        expect('currencies' in itemMapping.default).toBe(false)
        expect('taxCode' in itemMapping.default).toBe(true)
      } else {
        fail('Expected type guard to return true')
      }
    })

    it('narrows the type correctly when returning true for mappable mapping', () => {
      const item = createMockItem(MappableTypeEnum.AddOn)
      const itemMapping = createMockItemMapping(validMappableMapping)

      if (isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')) {
        // TypeScript should now know that itemMapping.default is NOT ItemMappingForCurrenciesMapping
        expect(itemMapping.default).toBeDefined()
        expect('currencies' in itemMapping.default).toBe(false)
        expect('lagoMappableId' in itemMapping.default).toBe(true)
      } else {
        fail('Expected type guard to return true')
      }
    })

    it('does not narrow type when returning false for currency mapping', () => {
      const item = createMockItem(MappingTypeEnum.Currencies)
      const itemMapping = createMockItemMapping(validCurrenciesMapping)

      if (!isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')) {
        // When the function returns false, we know it IS a currency mapping
        expect(itemMapping.default).toBeDefined()
        expect('currencies' in itemMapping.default).toBe(true)
      } else {
        fail('Expected type guard to return false for currency mapping')
      }
    })
  })

  describe('edge cases', () => {
    it('handles empty object as itemMapping', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = {} as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('handles itemMapping with default as empty object', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = {
        default: {},
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('handles itemMapping with default as array (should return true)', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = {
        default: [],
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('handles complex itemMapping with multiple properties for non-currency type', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = {
        default: validTaxMapping,
        someOtherEntity: {
          itemId: 'other-id',
          itemExternalId: 'ext-456',
          taxCode: 'OTHER_TAX',
        },
        anotherEntity: {
          itemId: 'another-id',
          itemExternalId: 'ext-789',
          taxCode: 'ANOTHER_TAX',
        },
      } as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
      if (result) {
        expect('taxCode' in itemMapping.default).toBe(true)
        expect('currencies' in itemMapping.default).toBe(false)
      }
    })

    it('handles complex itemMapping with multiple properties for currency type', () => {
      const item = createMockItem(MappingTypeEnum.Currencies)
      const itemMapping = {
        default: validCurrenciesMapping,
        someOtherEntity: {
          itemId: 'other-id',
          currencies: [],
        },
        anotherEntity: {
          itemId: 'another-id',
          currencies: [
            {
              currencyCode: CurrencyEnum.Eur,
              currencyExternalCode: 'EUR_EXTERNAL',
            },
          ],
        },
      } as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
      if (!result) {
        expect('currencies' in itemMapping.default).toBe(true)
        expect(
          Array.isArray((itemMapping.default as ItemMappingForCurrenciesMapping).currencies),
        ).toBe(true)
      }
    })

    it('handles different keys (not just default)', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = {
        customKey: validTaxMapping,
        default: validCurrenciesMapping, // Different type for default
      } as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'customKey')

      expect(result).toBe(true)
    })

    it('handles non-existent key', () => {
      const item = createMockItem(MappingTypeEnum.Tax)
      const itemMapping = {
        default: validTaxMapping,
      } as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, 'nonExistentKey')

      expect(result).toBe(true)
    })
  })

  describe('consistency with isItemMappingForKeyForCurrenciesMapping', () => {
    it('always returns the opposite of isItemMappingForKeyForCurrenciesMapping', () => {
      const testCases = [
        {
          item: createMockItem(MappingTypeEnum.Currencies),
          itemMapping: createMockItemMapping(validCurrenciesMapping),
          key: 'default',
        },
        {
          item: createMockItem(MappingTypeEnum.Tax),
          itemMapping: createMockItemMapping(validTaxMapping),
          key: 'default',
        },
        {
          item: createMockItem(MappableTypeEnum.AddOn),
          itemMapping: createMockItemMapping(validMappableMapping),
          key: 'default',
        },
        {
          item: createMockItem(MappingTypeEnum.Currencies),
          itemMapping: {} as ItemMappingPerBillingEntity,
          key: 'default',
        },
        {
          item: createMockItem(MappingTypeEnum.Currencies),
          itemMapping: null as unknown as ItemMappingPerBillingEntity,
          key: 'default',
        },
      ]

      testCases.forEach(({ item, itemMapping, key }) => {
        // Test consistency with the original function
        const originalResult = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, key)
        const negatedResult = isItemMappingForKeyNotForCurrenciesMapping(item, itemMapping, key)

        expect(negatedResult).toBe(!originalResult)
      })
    })
  })
})
