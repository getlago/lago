import { renderHook, waitFor } from '@testing-library/react'

import {
  BillingEntityDocumentNumberingEnum,
  CurrencyEnum,
  GetBillingEntitiesDocument,
} from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { useBillingEntitiesOptions } from '../useBillingEntitiesOptions'

const buildEntity = (overrides: Record<string, unknown>) => ({
  __typename: 'BillingEntity' as const,
  id: 'entity-id',
  code: 'entity-code',
  name: 'Entity name',
  documentNumbering: BillingEntityDocumentNumberingEnum.PerCustomer,
  documentNumberPrefix: 'INV',
  logoUrl: null,
  legalName: null,
  legalNumber: null,
  taxIdentificationNumber: null,
  email: null,
  addressLine1: null,
  addressLine2: null,
  zipcode: null,
  city: null,
  state: null,
  country: null,
  emailSettings: [],
  timezone: null,
  isDefault: false,
  defaultCurrency: CurrencyEnum.Usd,
  euTaxManagement: false,
  einvoicing: false,
  selectedInvoiceCustomSections: [],
  appliedDunningCampaign: null,
  ...overrides,
})

const billingEntitiesMock = (entities: ReturnType<typeof buildEntity>[]): TestMocksType => [
  {
    request: { query: GetBillingEntitiesDocument },
    result: {
      data: {
        billingEntities: {
          __typename: 'BillingEntityCollection',
          collection: entities,
        },
      },
    },
  },
]

const createWrapper = (mocks: TestMocksType) => {
  return ({ children }: { children: React.ReactNode }) => AllTheProviders({ children, mocks })
}

describe('useBillingEntitiesOptions', () => {
  describe('GIVEN the org has multiple billing entities', () => {
    const mocks = billingEntitiesMock([
      buildEntity({ id: '1', code: 'us', name: 'Acme US', isDefault: true }),
      buildEntity({ id: '2', code: 'eu', name: 'Acme EU', isDefault: false }),
    ])

    it('THEN returns options with the default entity sorted first', async () => {
      const { result } = renderHook(() => useBillingEntitiesOptions(), {
        wrapper: createWrapper(mocks),
      })

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
      })

      expect(result.current.options).toHaveLength(2)
      expect(result.current.options[0].value).toBe('us')
      expect(result.current.options[0].isDefault).toBe(true)
      expect(result.current.options[0].label).toContain('Acme US')
      expect(result.current.options[1].value).toBe('eu')
      expect(result.current.defaultEntityCode).toBe('us')
      expect(result.current.hasMultipleEntities).toBe(true)
    })

    it('THEN prepends an inherit sentinel option when includeInheritOption is true', async () => {
      const { result } = renderHook(
        () =>
          useBillingEntitiesOptions({
            includeInheritOption: true,
            inheritLabel: 'Use customer default',
          }),
        { wrapper: createWrapper(mocks) },
      )

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
      })

      expect(result.current.options).toHaveLength(3)
      expect(result.current.options[0]).toEqual({
        id: '',
        value: '',
        label: 'Use customer default',
        isDefault: false,
        euTaxManagement: false,
      })
      expect(result.current.options[1].value).toBe('us')
    })
  })

  describe('GIVEN the org has a single billing entity', () => {
    const mocks = billingEntitiesMock([
      buildEntity({ id: '1', code: 'only', name: 'Only entity', isDefault: true }),
    ])

    it('THEN reports hasMultipleEntities = false', async () => {
      const { result } = renderHook(() => useBillingEntitiesOptions(), {
        wrapper: createWrapper(mocks),
      })

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
      })

      expect(result.current.hasMultipleEntities).toBe(false)
      expect(result.current.options).toHaveLength(1)
    })
  })

  describe('GIVEN skip is true', () => {
    it('THEN does NOT fetch and returns an empty list', () => {
      const { result } = renderHook(() => useBillingEntitiesOptions({ skip: true }), {
        wrapper: createWrapper([]),
      })

      expect(result.current.isLoading).toBe(false)
      expect(result.current.options).toEqual([])
      expect(result.current.defaultEntityCode).toBeUndefined()
      expect(result.current.hasMultipleEntities).toBe(false)
    })
  })
})
