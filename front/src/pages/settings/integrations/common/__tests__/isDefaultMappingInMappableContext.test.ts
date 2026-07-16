import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import type { AnrokIntegrationMapItemDrawerProps } from '~/pages/settings/integrations/AnrokIntegrationMapItemDrawer'
import type { NetsuiteIntegrationMapItemDrawerProps } from '~/pages/settings/integrations/NetsuiteIntegrationMapItemDrawer'

import { isDefaultMappingInMappableContext } from '../isDefaultMappingInMappableContext'

describe('isDefaultMappingInMappableContext', () => {
  describe('returns false', () => {
    it('should return false when dataToTest is undefined', () => {
      expect(isDefaultMappingInMappableContext(undefined)).toBe(false)
    })

    it('should return false when dataToTest is null', () => {
      // @ts-expect-error -- Testing null case
      expect(isDefaultMappingInMappableContext(null)).toBe(false)
    })

    it('should return false when itemMappings is undefined', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        // @ts-expect-error -- Testing undefined case
        itemMappings: undefined,
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(false)
    })

    it('should return false when itemMappings.default is undefined', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {},
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(false)
    })

    it('should return false when itemMappings.default exists but is null', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          // @ts-expect-error -- Testing null case
          default: null,
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(false)
    })

    it('should return false when lagoMappableId is missing from default mapping', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            itemExternalName: 'External Name',
            lagoMappableName: 'Mappable Name',
            // lagoMappableId is missing
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(false)
    })

    it('should return false when lagoMappableName is missing from default mapping', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            itemExternalName: 'External Name',
            lagoMappableId: 'mappable-1',
            // lagoMappableName is missing
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(false)
    })

    it('should return false when both lagoMappableId and lagoMappableName are missing', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            itemExternalName: 'External Name',
            // Both lagoMappableId and lagoMappableName are missing
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(false)
    })

    it('should return false when default mapping is not an ItemMappingForMappable (missing required fields)', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            // This is more like ItemMappingForTaxMapping or ItemMappingForNonTaxMapping
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            itemExternalName: 'External Name',
            taxCode: 'TAX001',
            taxNexus: 'US',
            taxType: 'SALES',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(false)
    })
  })

  describe('returns true', () => {
    it('should return true for valid NetsuiteIntegrationMapItemDrawerProps with default ItemMappingForMappable', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [{ id: 'entity-1', key: 'default', name: 'Default Entity' }],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            itemExternalName: 'External Name',
            lagoMappableId: 'mappable-1',
            lagoMappableName: 'Mappable Name',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(true)
    })

    it('should return true for valid AnrokIntegrationMapItemDrawerProps with default ItemMappingForMappable', () => {
      const data: AnrokIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.BillableMetric,
        integrationId: 'anrok-integration',
        billingEntities: [{ id: 'entity-1', key: 'default', name: 'Default Entity' }],
        itemMappings: {
          default: {
            itemId: 'item-2',
            itemExternalId: 'anrok-ext-2',
            itemExternalName: 'Anrok External Name',
            lagoMappableId: 'billable-metric-1',
            lagoMappableName: 'Revenue Metric',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(true)
    })

    it('should return true with minimal required fields in ItemMappingForMappable', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: null,
            itemExternalId: null,
            lagoMappableId: 'mappable-1',
            lagoMappableName: 'Mappable Name',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(true)
    })

    it('should return true when default mapping has additional fields beyond ItemMappingForMappable', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            itemExternalName: 'External Name',
            itemExternalCode: 'EXT-CODE-001',
            lagoMappableId: 'mappable-1',
            lagoMappableName: 'Mappable Name',
            // Additional fields that might be present
            taxCode: 'TAX001',
            taxNexus: 'US',
            taxType: 'SALES',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(true)
    })

    it('should return true with different MappableTypeEnum values', () => {
      const addOnData: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'addon-1',
            itemExternalId: 'ext-addon-1',
            lagoMappableId: 'addon-mappable-1',
            lagoMappableName: 'Test Add-on',
          },
        },
      }

      const billableMetricData: AnrokIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.BillableMetric,
        integrationId: 'anrok-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'metric-1',
            itemExternalId: 'ext-metric-1',
            lagoMappableId: 'metric-mappable-1',
            lagoMappableName: 'Usage Metric',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(addOnData)).toBe(true)
      expect(isDefaultMappingInMappableContext(billableMetricData)).toBe(true)
    })

    it('should return true with different MappingTypeEnum values', () => {
      const taxData: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappingTypeEnum.Tax,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'addon-1',
            itemExternalId: 'ext-addon-1',
            lagoMappableId: 'addon-mappable-1',
            lagoMappableName: 'Test Add-on',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(taxData)).toBe(true)
    })

    it('should return true when itemMappings has additional keys beyond default', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            lagoMappableId: 'mappable-1',
            lagoMappableName: 'Mappable Name',
          },
          'entity-1': {
            itemId: 'item-2',
            itemExternalId: 'ext-2',
            itemExternalName: 'Other Entity Name',
          },
          'entity-2': {
            itemId: 'item-3',
            itemExternalId: 'ext-3',
            taxCode: 'TAX002',
          },
        },
      }

      expect(isDefaultMappingInMappableContext(data)).toBe(true)
    })
  })

  describe('type narrowing', () => {
    it('should properly narrow the type when returning true', () => {
      const data: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'test-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            lagoMappableId: 'mappable-1',
            lagoMappableName: 'Mappable Name',
          },
        },
      }

      if (isDefaultMappingInMappableContext(data)) {
        // Type should be narrowed to include the default ItemMappingForMappable
        expect(data.itemMappings.default.lagoMappableId).toBe('mappable-1')
        expect(data.itemMappings.default.lagoMappableName).toBe('Mappable Name')
      }
    })

    it('should work with union types', () => {
      const netsuiteData: NetsuiteIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.AddOn,
        integrationId: 'netsuite-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-1',
            itemExternalId: 'ext-1',
            lagoMappableId: 'mappable-1',
            lagoMappableName: 'Netsuite Mappable',
          },
        },
      }

      const anrokData: AnrokIntegrationMapItemDrawerProps = {
        type: MappableTypeEnum.BillableMetric,
        integrationId: 'anrok-integration',
        billingEntities: [],
        itemMappings: {
          default: {
            itemId: 'item-2',
            itemExternalId: 'ext-2',
            lagoMappableId: 'mappable-2',
            lagoMappableName: 'Anrok Mappable',
          },
        },
      }

      const testData: (
        NetsuiteIntegrationMapItemDrawerProps | AnrokIntegrationMapItemDrawerProps | undefined
      )[] = [netsuiteData, anrokData, undefined]

      testData.forEach((data) => {
        if (isDefaultMappingInMappableContext(data)) {
          // Type should be properly narrowed for both union members
          expect(typeof data.itemMappings.default.lagoMappableId).toBe('string')
          expect(typeof data.itemMappings.default.lagoMappableName).toBe('string')
        }
      })
    })
  })
})
