import { CurrencyEnum, MappingTypeEnum } from '~/generated/graphql'
import {
  ItemMappingForCurrenciesMapping,
  ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common/types'

import { isItemMappingForKeyForCurrenciesMapping } from '../isItemMappingForKeyForCurrenciesMapping'

describe('isItemMappingForKeyForCurrenciesMapping', () => {
  const createMockItem = (mappingType: MappingTypeEnum) => ({
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

  describe('when item mappingType is Currencies', () => {
    const item = createMockItem(MappingTypeEnum.Currencies)

    it('returns true when itemMapping has valid default currencies mapping', () => {
      const itemMapping = createMockItemMapping(validCurrenciesMapping)

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns true when itemMapping has valid default with empty currencies array', () => {
      const itemMapping = createMockItemMapping({
        itemId: 'test-item-id',
        currencies: [],
      })

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
    })

    it('returns false when itemMapping is null', () => {
      const itemMapping = null as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns false when itemMapping is undefined', () => {
      const itemMapping = undefined as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns false when itemMapping does not have default property', () => {
      const itemMapping = {
        someOtherProperty: 'value',
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns false when itemMapping.default is null', () => {
      const itemMapping = createMockItemMapping(null)

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns false when itemMapping.default is not an object', () => {
      const itemMapping = {
        default: 'not-an-object',
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns false when itemMapping.default does not have currencies property', () => {
      const itemMapping = createMockItemMapping({
        itemId: 'test-item-id',
        someOtherProperty: 'value',
      })

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('returns true when itemMapping.default has currencies property even if null', () => {
      const itemMapping = createMockItemMapping({
        itemId: 'test-item-id',
        currencies: null as unknown as ItemMappingForCurrenciesMapping['currencies'],
      })

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
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
      it(`returns false when mappingType is ${mappingType} even with valid currencies mapping`, () => {
        const item = createMockItem(mappingType)
        const itemMapping = createMockItemMapping(validCurrenciesMapping)

        const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

        expect(result).toBe(false)
      })
    })
  })

  describe('type narrowing', () => {
    it('narrows the type correctly when returning true', () => {
      const item = createMockItem(MappingTypeEnum.Currencies)
      const itemMapping = createMockItemMapping(validCurrenciesMapping)

      if (isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')) {
        // TypeScript should now know that itemMapping.default is ItemMappingForCurrenciesMapping
        expect(itemMapping.default.currencies).toBeDefined()
        expect(Array.isArray(itemMapping.default.currencies)).toBe(true)
      } else {
        fail('Expected type guard to return true')
      }
    })
  })

  describe('edge cases', () => {
    it('handles empty object as itemMapping', () => {
      const item = createMockItem(MappingTypeEnum.Currencies)
      const itemMapping = {} as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('handles itemMapping with default as empty object', () => {
      const item = createMockItem(MappingTypeEnum.Currencies)
      const itemMapping = {
        default: {},
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('handles itemMapping with default as array (should return false)', () => {
      const item = createMockItem(MappingTypeEnum.Currencies)
      const itemMapping = {
        default: [],
      } as unknown as ItemMappingPerBillingEntity

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(false)
    })

    it('handles complex itemMapping with multiple properties', () => {
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

      const result = isItemMappingForKeyForCurrenciesMapping(item, itemMapping, 'default')

      expect(result).toBe(true)
      if (result) {
        expect(itemMapping.default.currencies).toEqual(validCurrenciesMapping.currencies)
      }
    })
  })
})
