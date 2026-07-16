import { renderHook } from '@testing-library/react'
import { isValidElement, ReactElement } from 'react'

import { CustomerAccountTypeEnum, CustomerDetailsFragment } from '~/generated/graphql'

import { useCustomerDetailsHeaderEntity } from '../useCustomerDetailsHeaderEntity'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const createMockCustomer = (
  overrides: Partial<CustomerDetailsFragment> = {},
): CustomerDetailsFragment =>
  ({
    id: 'cust-1',
    displayName: 'Test Customer',
    externalId: 'ext-1',
    accountType: CustomerAccountTypeEnum.Customer,
    ...overrides,
  }) as unknown as CustomerDetailsFragment

describe('useCustomerDetailsHeaderEntity', () => {
  describe('GIVEN a customer is provided', () => {
    describe('WHEN the customer has a display name', () => {
      it('THEN should return the entity config with the display name as viewName', () => {
        const customer = createMockCustomer({ displayName: 'Acme Corp' })

        const { result } = renderHook(() => useCustomerDetailsHeaderEntity({ customer }))

        expect(result.current).toEqual(
          expect.objectContaining({
            viewName: 'Acme Corp',
          }),
        )
        // metadata is now a click-to-copy element wrapping the externalId
        expect(isValidElement(result.current?.metadata)).toBe(true)
        expect((result.current?.metadata as ReactElement).props.children).toBe('ext-1')
      })
    })

    describe('WHEN the customer has no display name', () => {
      it('THEN should return a fallback translation key as viewName', () => {
        const customer = createMockCustomer({ displayName: '' })

        const { result } = renderHook(() => useCustomerDetailsHeaderEntity({ customer }))

        expect(result.current).toEqual(
          expect.objectContaining({
            viewName: expect.any(String),
          }),
        )
        expect(isValidElement(result.current?.metadata)).toBe(true)
        expect((result.current?.metadata as ReactElement).props.children).toBe('ext-1')
      })
    })

    describe('WHEN the customer is a partner', () => {
      it('THEN should include a badge in the config', () => {
        const customer = createMockCustomer({ accountType: CustomerAccountTypeEnum.Partner })

        const { result } = renderHook(() => useCustomerDetailsHeaderEntity({ customer }))

        expect(result.current?.badges).toBeDefined()
        expect(result.current?.badges).toHaveLength(1)
      })
    })

    describe('WHEN the customer is not a partner', () => {
      it('THEN should not include badges', () => {
        const customer = createMockCustomer({ accountType: CustomerAccountTypeEnum.Customer })

        const { result } = renderHook(() => useCustomerDetailsHeaderEntity({ customer }))

        expect(result.current?.badges).toBeUndefined()
      })
    })
  })

  describe('GIVEN no customer is provided', () => {
    describe('WHEN customer is undefined', () => {
      it('THEN should return undefined', () => {
        const { result } = renderHook(() => useCustomerDetailsHeaderEntity({ customer: undefined }))

        expect(result.current).toBeUndefined()
      })
    })

    describe('WHEN customer is null', () => {
      it('THEN should return undefined', () => {
        const { result } = renderHook(() => useCustomerDetailsHeaderEntity({ customer: null }))

        expect(result.current).toBeUndefined()
      })
    })
  })
})
