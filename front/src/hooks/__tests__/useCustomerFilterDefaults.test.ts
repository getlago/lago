import { renderHook } from '@testing-library/react'

import {
  AvailableFiltersEnum,
  filterDataInlineSeparator,
} from '~/components/designSystem/Filters/types'
import { CurrencyEnum, FeatureFlagEnum } from '~/generated/graphql'

import type { BillingEntityOption } from '../useBillingEntitiesOptions'
import { useCustomerFilterDefaults } from '../useCustomerFilterDefaults'

const mockUseBillingEntitiesOptions = jest.fn<{ options: BillingEntityOption[] }, []>()
const mockHasFeatureFlag = jest.fn<boolean, [FeatureFlagEnum]>()
const mockOrganization = { defaultCurrency: 'EUR' }

jest.mock('~/hooks/useBillingEntitiesOptions', () => ({
  useBillingEntitiesOptions: () => mockUseBillingEntitiesOptions(),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: mockOrganization,
    hasFeatureFlag: mockHasFeatureFlag,
  }),
}))

const DEFAULT_ENTITY: BillingEntityOption = {
  id: 'entity-1',
  value: 'acme-us',
  label: 'Acme US (default)',
  name: 'Acme US',
  isDefault: true,
  euTaxManagement: false,
}

const SECONDARY_ENTITY: BillingEntityOption = {
  id: 'entity-2',
  value: 'acme-eu',
  label: 'Acme EU',
  name: 'Acme EU',
  isDefault: false,
  euTaxManagement: false,
}

beforeEach(() => {
  jest.clearAllMocks()
  mockUseBillingEntitiesOptions.mockReturnValue({ options: [DEFAULT_ENTITY, SECONDARY_ENTITY] })
  mockHasFeatureFlag.mockReturnValue(false)
})

describe('useCustomerFilterDefaults', () => {
  describe('GIVEN no feature flags are enabled', () => {
    describe('WHEN called with both currency and entity in include', () => {
      it('THEN should return null', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'test',
            include: ['currency', 'entity'],
          }),
        )

        expect(result.current).toBeNull()
      })
    })
  })

  describe('GIVEN only MultiCurrency flag is enabled', () => {
    beforeEach(() => {
      mockHasFeatureFlag.mockImplementation((flag) => flag === FeatureFlagEnum.MultiCurrency)
    })

    describe('WHEN called with currency in include', () => {
      it('THEN should return currency filter in availableFilters', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'analytics',
            include: ['currency'],
          }),
        )

        expect(result.current).toEqual({
          filtersNamePrefix: 'analytics',
          availableFilters: [AvailableFiltersEnum.currency],
        })
      })
    })

    describe('WHEN called with entity only in include', () => {
      it('THEN should return null because entity flag is off', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'test',
            include: ['entity'],
          }),
        )

        expect(result.current).toBeNull()
      })
    })
  })

  describe('GIVEN only MultiEntityBilling flag is enabled and a default entity exists', () => {
    beforeEach(() => {
      mockHasFeatureFlag.mockImplementation((flag) => flag === FeatureFlagEnum.MultiEntityBilling)
    })

    describe('WHEN called with entity in include', () => {
      it('THEN should return billingEntityId filter in availableFilters', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'invoices',
            include: ['entity'],
          }),
        )

        expect(result.current).toEqual({
          filtersNamePrefix: 'invoices',
          availableFilters: [AvailableFiltersEnum.billingEntityId],
        })
      })
    })
  })

  describe('GIVEN MultiEntityBilling flag is enabled but no default entity exists', () => {
    beforeEach(() => {
      mockHasFeatureFlag.mockImplementation((flag) => flag === FeatureFlagEnum.MultiEntityBilling)
      mockUseBillingEntitiesOptions.mockReturnValue({ options: [] })
    })

    describe('WHEN called with entity in include', () => {
      it('THEN should return null', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'test',
            include: ['entity'],
          }),
        )

        expect(result.current).toBeNull()
      })
    })
  })

  describe('GIVEN both MultiCurrency and MultiEntityBilling flags are enabled', () => {
    beforeEach(() => {
      mockHasFeatureFlag.mockReturnValue(true)
    })

    describe('WHEN called with both currency and entity in include', () => {
      it('THEN should return both filters in availableFilters', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'analytics',
            include: ['currency', 'entity'],
          }),
        )

        expect(result.current).toEqual({
          filtersNamePrefix: 'analytics',
          availableFilters: [AvailableFiltersEnum.currency, AvailableFiltersEnum.billingEntityId],
        })
      })
    })

    describe('WHEN called with withDefaults=true and no customerCurrency', () => {
      it('THEN should return staticFilters with org defaultCurrency and default entity', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'analytics',
            include: ['currency', 'entity'],
            withDefaults: true,
          }),
        )

        expect(result.current).toEqual({
          filtersNamePrefix: 'analytics',
          availableFilters: [AvailableFiltersEnum.currency, AvailableFiltersEnum.billingEntityId],
          staticFilters: {
            [AvailableFiltersEnum.currency]: CurrencyEnum.Eur,
            [AvailableFiltersEnum.billingEntityId]: `${DEFAULT_ENTITY.id}${filterDataInlineSeparator}${DEFAULT_ENTITY.name}`,
          },
        })
      })
    })

    describe('WHEN called with withDefaults=true and a customerCurrency', () => {
      it('THEN should use customerCurrency instead of org default', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            customerCurrency: CurrencyEnum.Gbp,
            filtersNamePrefix: 'analytics',
            include: ['currency', 'entity'],
            withDefaults: true,
          }),
        )

        expect(result.current?.staticFilters?.[AvailableFiltersEnum.currency]).toBe(
          CurrencyEnum.Gbp,
        )
      })
    })
  })

  describe('GIVEN withDefaults and entity whose name is null', () => {
    beforeEach(() => {
      mockHasFeatureFlag.mockReturnValue(true)
      mockUseBillingEntitiesOptions.mockReturnValue({
        options: [{ ...DEFAULT_ENTITY, name: null }],
      })
    })

    describe('WHEN called with withDefaults=true', () => {
      it('THEN should fall back to entity value in the separator string', () => {
        const { result } = renderHook(() =>
          useCustomerFilterDefaults({
            filtersNamePrefix: 'test',
            include: ['entity'],
            withDefaults: true,
          }),
        )

        expect(result.current?.staticFilters?.[AvailableFiltersEnum.billingEntityId]).toBe(
          `${DEFAULT_ENTITY.id}${filterDataInlineSeparator}${DEFAULT_ENTITY.value}`,
        )
      })
    })
  })

  describe('GIVEN include filters are selectively requested', () => {
    it.each([
      {
        scenario: 'only currency requested, both flags on',
        include: ['currency'] as const,
        flags: [FeatureFlagEnum.MultiCurrency, FeatureFlagEnum.MultiEntityBilling],
        expected: [AvailableFiltersEnum.currency],
      },
      {
        scenario: 'only entity requested, both flags on',
        include: ['entity'] as const,
        flags: [FeatureFlagEnum.MultiCurrency, FeatureFlagEnum.MultiEntityBilling],
        expected: [AvailableFiltersEnum.billingEntityId],
      },
    ])('THEN should only include $scenario', ({ include, flags, expected }) => {
      mockHasFeatureFlag.mockImplementation((flag) => flags.includes(flag))

      const { result } = renderHook(() =>
        useCustomerFilterDefaults({
          filtersNamePrefix: 'test',
          include: [...include],
        }),
      )

      expect(result.current?.availableFilters).toEqual(expected)
    })
  })
})
