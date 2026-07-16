import { GraphQLFormattedError } from 'graphql'

import { IntegrationTypeEnum, MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'

import { getParametersFromProvider } from '../getParametersFromProvider'
import { handleIntegrationMappingCreateUpdateDelete } from '../handleIntegrationMappingCreateUpdateDelete'
import type {
  BillingEntityForIntegrationMapping,
  CreateUpdateDeleteFunctions,
  ItemMappingForMappable,
  ItemMappingForNonTaxMapping,
  ItemMappingForTaxMapping,
} from '../types'

// Mock the getParametersFromProvider function
jest.mock('../getParametersFromProvider', () => ({
  getParametersFromProvider: jest.fn(),
}))

const mockGetParametersFromProvider = getParametersFromProvider as jest.MockedFunction<
  typeof getParametersFromProvider
>

describe('handleIntegrationMappingCreateUpdateDelete', () => {
  const mockIntegrationId = 'integration-123'
  const mockBillingEntity: BillingEntityForIntegrationMapping = {
    id: 'billing-entity-123',
    key: 'default',
    name: 'Default Entity',
  }

  const mockCreateCollectionMapping = jest.fn()
  const mockCreateMapping = jest.fn()
  const mockDeleteCollectionMapping = jest.fn()
  const mockDeleteMapping = jest.fn()
  const mockUpdateCollectionMapping = jest.fn()
  const mockUpdateMapping = jest.fn()

  const mockFunctions: CreateUpdateDeleteFunctions = {
    createCollectionMapping: mockCreateCollectionMapping,
    createMapping: mockCreateMapping,
    deleteCollectionMapping: mockDeleteCollectionMapping,
    deleteMapping: mockDeleteMapping,
    updateCollectionMapping: mockUpdateCollectionMapping,
    updateMapping: mockUpdateMapping,
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Invalid input values', () => {
    it('should return failure when getParametersFromProvider fails', async () => {
      mockGetParametersFromProvider.mockReturnValue({
        success: false,
        parameters: undefined,
      })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        { externalId: 'test' },
        undefined,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({
        success: false,
        reasons: ['Invalid input values'],
      })
    })
  })

  describe('No action needed scenarios', () => {
    it('should return success when no initial data and no input values', async () => {
      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
          externalAccountCode: undefined,
        },
      })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {},
        undefined,
        MappingTypeEnum.Account,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: true })
    })

    it('should return success when initial data only contains lagoBillableId and lagoMappableName and no input values', async () => {
      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
          externalAccountCode: undefined,
        },
      })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {},
        {
          lagoMappableId: 'mappable-123',
          lagoMappableName: 'Test Mappable',
          itemId: null,
          itemExternalId: null,
        },
        MappingTypeEnum.Account,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: true })
    })

    it('should return success when no initial data and empty values for mappable', async () => {
      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
        },
      })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {},
        undefined,
        MappableTypeEnum.AddOn,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Avalara,
      )

      expect(result).toEqual({ success: true })
    })
  })

  describe('Create scenarios', () => {
    it('should create collection mapping for tax mapping with Netsuite', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
        taxCode: null,
        taxNexus: null,
        taxType: null,
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
      })

      mockCreateCollectionMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(mockCreateCollectionMapping).toHaveBeenCalledWith({
        variables: {
          input: {
            integrationId: mockIntegrationId,
            mappingType: MappingTypeEnum.Tax,
            billingEntityId: mockBillingEntity.id,
            externalId: 'ext-123',
            externalName: 'External Name',
            externalAccountCode: 'ACC-123',
            taxCode: 'TAX-001',
            taxNexus: 'US',
            taxType: 'SALES',
          },
        },
      })
      expect(result).toEqual({ success: true })
    })

    it('should create mapping for mappable type', async () => {
      const mockInitialMapping: ItemMappingForMappable = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
        lagoMappableId: 'mappable-123',
        lagoMappableName: 'Test Mappable',
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
        },
      })

      mockCreateMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
        },
        mockInitialMapping,
        MappableTypeEnum.AddOn,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Avalara,
      )

      expect(mockCreateMapping).toHaveBeenCalledWith({
        variables: {
          input: {
            integrationId: mockIntegrationId,
            mappableType: MappableTypeEnum.AddOn,
            mappableId: 'mappable-123',
            billingEntityId: mockBillingEntity.id,
            externalId: 'ext-123',
            externalName: 'External Name',
          },
        },
      })
      expect(result).toEqual({ success: true })
    })

    it('should create without billing entity ID when billing entity has no ID', async () => {
      const mockBillingEntityWithoutId: BillingEntityForIntegrationMapping = {
        id: null,
        key: 'default',
        name: 'Default Entity',
      }

      const mockInitialMapping: ItemMappingForNonTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
        },
      })

      mockCreateCollectionMapping.mockResolvedValue({ errors: null })

      await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
        },
        mockInitialMapping,
        MappingTypeEnum.Account,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntityWithoutId,
        IntegrationTypeEnum.Netsuite,
      )

      expect(mockCreateCollectionMapping).toHaveBeenCalledWith({
        variables: {
          input: {
            integrationId: mockIntegrationId,
            mappingType: MappingTypeEnum.Account,
            externalId: 'ext-123',
            externalName: 'External Name',
            externalAccountCode: 'ACC-123',
          },
        },
      })
    })

    it('should return error when create fails', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
        taxCode: null,
        taxNexus: null,
        taxType: null,
      }

      const mockErrors: GraphQLFormattedError[] = [
        { message: 'Create failed', path: ['createMapping'] },
      ]

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
      })

      mockCreateCollectionMapping.mockResolvedValue({ errors: mockErrors })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: false, errors: mockErrors })
    })
  })

  describe('Update scenarios', () => {
    it('should update collection mapping when values changed', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: 'mapping-123',
        itemExternalId: 'old-ext-123',
        itemExternalName: 'Old External Name',
        itemExternalCode: 'OLD-ACC-123',
        taxCode: 'OLD-TAX-001',
        taxNexus: 'OLD-US',
        taxType: 'OLD-SALES',
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
          externalAccountCode: 'NEW-ACC-123',
          taxCode: 'NEW-TAX-001',
          taxNexus: 'NEW-US',
          taxType: 'NEW-SALES',
        },
      })

      mockUpdateCollectionMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
          externalAccountCode: 'NEW-ACC-123',
          taxCode: 'NEW-TAX-001',
          taxNexus: 'NEW-US',
          taxType: 'NEW-SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(mockUpdateCollectionMapping).toHaveBeenCalledWith({
        variables: {
          input: {
            id: 'mapping-123',
            integrationId: mockIntegrationId,
            mappingType: MappingTypeEnum.Tax,
            externalId: 'new-ext-123',
            externalName: 'New External Name',
            externalAccountCode: 'NEW-ACC-123',
            taxCode: 'NEW-TAX-001',
            taxNexus: 'NEW-US',
            taxType: 'NEW-SALES',
          },
        },
      })
      expect(result).toEqual({ success: true })
    })

    it('should update mapping for mappable type', async () => {
      const mockInitialMapping: ItemMappingForMappable = {
        itemId: 'mapping-123',
        itemExternalId: 'old-ext-123',
        itemExternalName: 'Old External Name',
        itemExternalCode: 'OLD-ACC-123',
        lagoMappableId: 'mappable-123',
        lagoMappableName: 'Test Mappable',
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
        },
      })

      mockUpdateMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
        },
        mockInitialMapping,
        MappableTypeEnum.BillableMetric,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Anrok,
      )

      expect(mockUpdateMapping).toHaveBeenCalledWith({
        variables: {
          input: {
            id: 'mapping-123',
            integrationId: mockIntegrationId,
            mappableType: MappableTypeEnum.BillableMetric,
            mappableId: 'mappable-123',
            externalId: 'new-ext-123',
            externalName: 'New External Name',
          },
        },
      })
      expect(result).toEqual({ success: true })
    })

    it('should skip update when values are the same', async () => {
      const mockInitialMapping: ItemMappingForNonTaxMapping = {
        itemId: 'mapping-123',
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
        },
      })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
        },
        mockInitialMapping,
        MappingTypeEnum.Account,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Xero,
      )

      expect(mockUpdateCollectionMapping).not.toHaveBeenCalled()
      expect(mockUpdateMapping).not.toHaveBeenCalled()
      expect(result).toEqual({ success: true })
    })

    it('should return error when no initial mapping ID found for update', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: null, // No ID but has initial data
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
        taxCode: 'TAX-001',
        taxNexus: 'US',
        taxType: 'SALES',
      }

      const mockErrors: GraphQLFormattedError[] = [
        { message: 'Create failed', path: ['createMapping'] },
      ]

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
          externalAccountCode: 'NEW-ACC-123',
          taxCode: 'NEW-TAX-001',
          taxNexus: 'NEW-US',
          taxType: 'NEW-SALES',
        },
      })

      mockCreateCollectionMapping.mockResolvedValue({ errors: mockErrors })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
          externalAccountCode: 'NEW-ACC-123',
          taxCode: 'NEW-TAX-001',
          taxNexus: 'NEW-US',
          taxType: 'NEW-SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      // This should try to create since itemId is null but has values
      expect(result).toEqual({ success: false, errors: mockErrors })
    })

    it('should return error when update fails', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: 'mapping-123',
        itemExternalId: 'old-ext-123',
        itemExternalName: 'Old External Name',
        itemExternalCode: 'OLD-ACC-123',
        taxCode: 'OLD-TAX-001',
        taxNexus: 'OLD-US',
        taxType: 'OLD-SALES',
      }

      const mockErrors: GraphQLFormattedError[] = [
        { message: 'Update failed', path: ['updateMapping'] },
      ]

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
          externalAccountCode: 'NEW-ACC-123',
          taxCode: 'NEW-TAX-001',
          taxNexus: 'NEW-US',
          taxType: 'NEW-SALES',
        },
      })

      mockUpdateCollectionMapping.mockResolvedValue({ errors: mockErrors })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'new-ext-123',
          externalName: 'New External Name',
          externalAccountCode: 'NEW-ACC-123',
          taxCode: 'NEW-TAX-001',
          taxNexus: 'NEW-US',
          taxType: 'NEW-SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: false, errors: mockErrors })
    })
  })

  describe('Delete scenarios', () => {
    it('should delete collection mapping when no values provided', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: 'mapping-123',
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
        taxCode: 'TAX-001',
        taxNexus: 'US',
        taxType: 'SALES',
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
          externalAccountCode: undefined,
          taxCode: undefined,
          taxNexus: undefined,
          taxType: undefined,
        },
      })

      mockDeleteCollectionMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {},
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(mockDeleteCollectionMapping).toHaveBeenCalledWith({
        variables: {
          input: {
            id: 'mapping-123',
          },
        },
      })
      expect(result).toEqual({ success: true })
    })

    it('should delete mapping for mappable type', async () => {
      const mockInitialMapping: ItemMappingForMappable = {
        itemId: 'mapping-123',
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
        lagoMappableId: 'mappable-123',
        lagoMappableName: 'Test Mappable',
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
        },
      })

      mockDeleteMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {},
        mockInitialMapping,
        MappableTypeEnum.AddOn,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Avalara,
      )

      expect(mockDeleteMapping).toHaveBeenCalledWith({
        variables: {
          input: {
            id: 'mapping-123',
          },
        },
      })
      expect(result).toEqual({ success: true })
    })

    it('should return error when cannot determine action with initial data but no clear operation', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: null, // No ID but has initial data. This shouldn't happen in real case but we test the edge case
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
        taxCode: 'TAX-001',
        taxNexus: 'US',
        taxType: 'SALES',
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
          externalAccountCode: undefined,
          taxCode: undefined,
          taxNexus: undefined,
          taxType: undefined,
        },
      })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {},
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({
        success: false,
        reasons: ['Could not determine action to perform'],
      })
    })

    it('should return error when delete fails', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: 'mapping-123',
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
        taxCode: 'TAX-001',
        taxNexus: 'US',
        taxType: 'SALES',
      }

      const mockErrors: GraphQLFormattedError[] = [
        { message: 'Delete failed', path: ['deleteMapping'] },
      ]

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: undefined,
          externalName: undefined,
          externalAccountCode: undefined,
          taxCode: undefined,
          taxNexus: undefined,
          taxType: undefined,
        },
      })

      mockDeleteCollectionMapping.mockResolvedValue({ errors: mockErrors })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {},
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: false, errors: mockErrors })
    })
  })

  describe('Edge cases', () => {
    it('should handle Netsuite tax mapping validation correctly', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
        taxCode: null,
        taxNexus: null,
        taxType: null,
      }

      // For Netsuite tax mapping, all tax fields are required
      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
      })

      mockCreateCollectionMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: true })
    })

    it('should handle Netsuite non-tax mapping validation correctly', async () => {
      const mockInitialMapping: ItemMappingForNonTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
      }

      // For Netsuite non-tax mapping, only external fields are required
      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: undefined,
          taxNexus: undefined,
          taxType: undefined,
        },
      })

      mockCreateCollectionMapping.mockResolvedValue({ errors: null })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
        },
        mockInitialMapping,
        MappingTypeEnum.Account,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: true })
    })

    it('should update when some parameters differ from initial mapping', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: 'mapping-123',
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
        taxCode: 'TAX-001',
        taxNexus: 'US',
        taxType: 'SALES',
      }

      const mockErrors: GraphQLFormattedError[] = [
        { message: 'Update failed', path: ['updateMapping'] },
      ]

      // This should trigger the update case because taxCode differs
      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123', // Same values
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-002', // Different tax code
          taxNexus: 'US',
          taxType: 'SALES',
        },
      })

      mockUpdateCollectionMapping.mockResolvedValue({ errors: mockErrors })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-002',
          taxNexus: 'US',
          taxType: 'SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({
        success: false,
        errors: mockErrors,
      })
    })

    it('should delete when input has insufficient values for the provider type', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: 'mapping-123', // Has ID
        itemExternalId: 'ext-123',
        itemExternalName: 'External Name',
        itemExternalCode: 'ACC-123',
        taxCode: 'TAX-001',
        taxNexus: 'US',
        taxType: 'SALES',
      }

      const mockErrors: GraphQLFormattedError[] = [
        { message: 'Delete failed', path: ['deleteMapping'] },
      ]

      // Return parameters that don't have enough values for Netsuite tax mapping
      // This will be considered a delete operation
      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123', // Some values present
          externalName: undefined, // But missing required fields for tax mapping
          externalAccountCode: undefined,
          taxCode: undefined,
          taxNexus: undefined,
          taxType: undefined,
        },
      })

      mockDeleteCollectionMapping.mockResolvedValue({ errors: mockErrors })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({
        success: false,
        errors: mockErrors,
      })
    })

    it('should handle errors array with length 0 as success', async () => {
      const mockInitialMapping: ItemMappingForTaxMapping = {
        itemId: null,
        itemExternalId: null,
        itemExternalName: undefined,
        itemExternalCode: undefined,
        taxCode: null,
        taxNexus: null,
        taxType: null,
      }

      mockGetParametersFromProvider.mockReturnValue({
        success: true,
        parameters: {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
      })

      // Return empty errors array (should be treated as success)
      mockCreateCollectionMapping.mockResolvedValue({ errors: [] })

      const result = await handleIntegrationMappingCreateUpdateDelete(
        {
          externalId: 'ext-123',
          externalName: 'External Name',
          externalAccountCode: 'ACC-123',
          taxCode: 'TAX-001',
          taxNexus: 'US',
          taxType: 'SALES',
        },
        mockInitialMapping,
        MappingTypeEnum.Tax,
        mockIntegrationId,
        mockFunctions,
        mockBillingEntity,
        IntegrationTypeEnum.Netsuite,
      )

      expect(result).toEqual({ success: true })
    })
  })
})
