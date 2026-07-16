import { renderHook } from '@testing-library/react'

import { StatusType } from '~/components/designSystem/Status'
import { IntegrationTypeEnum, MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import type { IntegrationItemData } from '../types'
import { useGetStatusDetails } from '../useGetStatusDetails'

// Mock the useInternationalization hook
const mockTranslate = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

describe('useGetStatusDetails', () => {
  beforeEach(() => {
    mockTranslate.mockClear()
    // Set up default return values for translate function
    mockTranslate.mockImplementation((key: string) => {
      const translations: Record<string, string> = {
        text_65281f686a80b400c8e2f6d1: 'Default',
        text_6630e3210c13c500cd398e9a: 'Undefined',
        text_17272714562192y06u5okvo4: 'Mapped',
      }

      return translations[key] || key
    })
  })

  const renderUseGetStatusDetails = () => {
    const customWrapper = ({ children }: { children: React.ReactNode }) =>
      AllTheProviders({ children })

    return renderHook(() => useGetStatusDetails(), {
      wrapper: customWrapper,
    })
  }

  const createMockItem = (overrides = {}): IntegrationItemData => ({
    id: 'item-1',
    icon: 'processing',
    label: 'Test Item',
    description: 'Test Description',
    mappingType: MappableTypeEnum.AddOn,
    integrationMappings: null,
    ...overrides,
  })

  const createMockMapping = (overrides = {}) => ({
    id: 'mapping-1',
    externalId: 'ext-123',
    externalName: 'External Name',
    externalAccountCode: 'ACC-123',
    mappableType: MappableTypeEnum.AddOn,
    billingEntityId: null,
    ...overrides,
  })

  const createMockCurrenciesItem = (): IntegrationItemData => ({
    id: 'currencies-item',
    icon: 'processing',
    label: 'Currencies',
    description: 'Currency mappings',
    mappingType: MappingTypeEnum.Currencies,
    integrationMappings: null,
  })

  describe('when itemMapping is undefined', () => {
    it('should return disabled status when columnId is not null', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'some-column-id',
        undefined,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.disabled,
        label: 'Default',
      })
      expect(mockTranslate).toHaveBeenCalledWith('text_65281f686a80b400c8e2f6d1')
    })

    it('should return warning status when columnId is null', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        null,
        undefined,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.warning,
        label: 'Undefined',
      })
      expect(mockTranslate).toHaveBeenCalledWith('text_6630e3210c13c500cd398e9a')
    })
  })

  describe('when itemMapping is provided', () => {
    it('should return success status with mapped label when externalName is empty', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const mockMapping = createMockMapping({ externalName: '' })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.success,
        label: 'Mapped',
      })
      expect(mockTranslate).toHaveBeenCalledWith('text_17272714562192y06u5okvo4')
    })

    it('should return success status with name only when externalId is undefined', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const mockMapping = createMockMapping({ externalId: undefined, externalName: 'Test Name' })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.success,
        label: 'Test Name',
      })
      expect(mockTranslate).not.toHaveBeenCalled()
    })

    it('should return success status with name only when externalId is empty string', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const mockMapping = createMockMapping({ externalId: '', externalName: 'Test Name' })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.success,
        label: 'Test Name',
      })
      expect(mockTranslate).not.toHaveBeenCalled()
    })

    it('should return success status with name and id when both are provided', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const mockMapping = createMockMapping({ externalId: 'test-id', externalName: 'Test Name' })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.success,
        label: 'Test Name (test-id)',
      })
      expect(mockTranslate).not.toHaveBeenCalled()
    })

    it('should handle falsy externalId values correctly', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()

      // Test with externalId as undefined explicitly
      const mappingWithUndefinedId = createMockMapping({
        externalId: undefined,
        externalName: 'Test Name',
      })
      const statusDetailsWithUndefinedId = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mappingWithUndefinedId,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetailsWithUndefinedId).toEqual({
        type: StatusType.success,
        label: 'Test Name',
      })

      // Test with externalId as 0 (falsy but should be included)
      const mappingWithZeroId = createMockMapping({
        externalId: '0',
        externalName: 'Test Name',
      })
      const statusDetailsWithZeroId = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mappingWithZeroId,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetailsWithZeroId).toEqual({
        type: StatusType.success,
        label: 'Test Name (0)',
      })
    })
  })

  describe('Netsuite currencies mapping scenarios', () => {
    it('should return warning status when currencies mapping is empty', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockCurrenciesItem()
      const mockMapping = createMockMapping({ currencies: [] })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.warning,
        label: 'Undefined',
      })
      expect(mockTranslate).toHaveBeenCalledWith('text_6630e3210c13c500cd398e9a')
    })

    it('should return warning status when currencies mapping is undefined', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockCurrenciesItem()
      const mockMapping = createMockMapping({ currencies: undefined })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.warning,
        label: 'Undefined',
      })
      expect(mockTranslate).toHaveBeenCalledWith('text_6630e3210c13c500cd398e9a')
    })

    it('should return success status when currencies mapping has items', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockCurrenciesItem()
      const mockMapping = createMockMapping({
        currencies: [
          { lagoCurrency: 'USD', externalCurrency: 'USD_EXTERNAL' },
          { lagoCurrency: 'EUR', externalCurrency: 'EUR_EXTERNAL' },
        ],
      })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.success,
        label: 'Mapped',
      })
      expect(mockTranslate).toHaveBeenCalledWith('text_17272714562192y06u5okvo4')
    })

    it('should work regardless of columnId value when currencies mapping exists', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockCurrenciesItem()
      const mockMapping = createMockMapping({
        currencies: [{ lagoCurrency: 'USD', externalCurrency: 'USD_EXTERNAL' }],
      })

      // Test with null columnId
      const statusDetailsWithNullColumn = result.current.getStatusDetails(
        mockItem,
        null,
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetailsWithNullColumn).toEqual({
        type: StatusType.success,
        label: 'Mapped',
      })

      // Test with string columnId
      const statusDetailsWithStringColumn = result.current.getStatusDetails(
        mockItem,
        'some-column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetailsWithStringColumn).toEqual({
        type: StatusType.success,
        label: 'Mapped',
      })
    })
  })

  describe('edge cases', () => {
    it('should handle empty externalName with undefined externalId', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const mockMapping = createMockMapping({ externalId: undefined, externalName: '' })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.success,
        label: 'Mapped',
      })
      expect(mockTranslate).toHaveBeenCalledWith('text_17272714562192y06u5okvo4')
    })

    it('should handle whitespace-only externalName', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const mockMapping = createMockMapping({ externalId: 'test-id', externalName: '   ' })
      const statusDetails = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetails).toEqual({
        type: StatusType.success,
        label: '    (test-id)',
      })
      expect(mockTranslate).not.toHaveBeenCalled()
    })

    it('should work regardless of columnId value when itemMapping is provided', () => {
      const { result } = renderUseGetStatusDetails()
      const mockItem = createMockItem()
      const mockMapping = createMockMapping({ externalId: 'test-id', externalName: 'Test Name' })

      // Test with null columnId
      const statusDetailsWithNullColumn = result.current.getStatusDetails(
        mockItem,
        null,
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetailsWithNullColumn.type).toBe(StatusType.success)
      expect(statusDetailsWithNullColumn.label).toBe('Test Name (test-id)')

      // Test with string columnId
      const statusDetailsWithStringColumn = result.current.getStatusDetails(
        mockItem,
        'column-id',
        mockMapping,
        IntegrationTypeEnum.Netsuite,
      )

      expect(statusDetailsWithStringColumn.type).toBe(StatusType.success)
      expect(statusDetailsWithStringColumn.label).toBe('Test Name (test-id)')
    })
  })
})
