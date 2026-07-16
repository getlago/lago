import type { AnyFormApi } from '@tanstack/react-form'
import { renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { CurrencyEnum } from '~/generated/graphql'

import { ChargeFormProvider, useChargeFormContext, usePropertyValues } from '../ChargeFormContext'

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((_store: unknown, selector: (state: unknown) => unknown) => {
    if (typeof _store === 'object' && _store !== null && 'getState' in _store) {
      return selector((_store as { getState: () => unknown }).getState())
    }

    return undefined
  }),
}))

describe('ChargeFormContext', () => {
  const mockForm = { id: 'mock-form' } as unknown as AnyFormApi

  describe('GIVEN useChargeFormContext is called within a ChargeFormProvider', () => {
    describe('WHEN the provider supplies all required values', () => {
      it('THEN should return the provided form', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFormProvider
            form={mockForm}
            propertyCursor="properties"
            currency={CurrencyEnum.Eur}
            chargePricingUnitShortName={undefined}
          >
            {children}
          </ChargeFormProvider>
        )

        const { result } = renderHook(() => useChargeFormContext(), { wrapper })

        expect(result.current.form).toBe(mockForm)
      })

      it('THEN should return the provided propertyCursor', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFormProvider
            form={mockForm}
            propertyCursor="filters.0.properties"
            currency={CurrencyEnum.Usd}
            chargePricingUnitShortName={undefined}
          >
            {children}
          </ChargeFormProvider>
        )

        const { result } = renderHook(() => useChargeFormContext(), { wrapper })

        expect(result.current.propertyCursor).toBe('filters.0.properties')
      })

      it('THEN should return the provided currency', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFormProvider
            form={mockForm}
            propertyCursor="properties"
            currency={CurrencyEnum.Gbp}
            chargePricingUnitShortName="GBP"
          >
            {children}
          </ChargeFormProvider>
        )

        const { result } = renderHook(() => useChargeFormContext(), { wrapper })

        expect(result.current.currency).toBe(CurrencyEnum.Gbp)
        expect(result.current.chargePricingUnitShortName).toBe('GBP')
      })
    })

    describe('WHEN disabled is provided', () => {
      it('THEN should include the disabled value', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFormProvider
            form={mockForm}
            propertyCursor="properties"
            currency={CurrencyEnum.Usd}
            chargePricingUnitShortName={undefined}
            disabled
          >
            {children}
          </ChargeFormProvider>
        )

        const { result } = renderHook(() => useChargeFormContext(), { wrapper })

        expect(result.current.disabled).toBe(true)
      })
    })
  })

  describe('GIVEN useChargeFormContext is called outside a ChargeFormProvider', () => {
    describe('WHEN there is no provider in the tree', () => {
      it('THEN should throw an error', () => {
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

        expect(() => {
          renderHook(() => useChargeFormContext())
        }).toThrow('useChargeFormContext must be used within a ChargeFormProvider')

        consoleSpy.mockRestore()
      })
    })
  })

  describe('GIVEN usePropertyValues is called', () => {
    describe('WHEN the propertyCursor is a simple key', () => {
      it('THEN should return the value at that key', () => {
        const mockFormWithStore = {
          store: {
            getState: () => ({
              values: {
                properties: { amount: '100', packageSize: '10' },
              },
            }),
          },
        } as unknown as AnyFormApi

        const { result } = renderHook(() => usePropertyValues(mockFormWithStore, 'properties'))

        expect(result.current).toEqual({ amount: '100', packageSize: '10' })
      })
    })

    describe('WHEN the propertyCursor is a nested dot-separated path', () => {
      it('THEN should traverse the path and return the nested value', () => {
        const mockFormWithStore = {
          store: {
            getState: () => ({
              values: {
                filters: [{ properties: { rate: '5' } }],
              },
            }),
          },
        } as unknown as AnyFormApi

        const { result } = renderHook(() =>
          usePropertyValues(mockFormWithStore, 'filters.0.properties'),
        )

        expect(result.current).toEqual({ rate: '5' })
      })
    })

    describe('WHEN the path does not exist in the values', () => {
      it('THEN should return undefined', () => {
        const mockFormWithStore = {
          store: {
            getState: () => ({
              values: {},
            }),
          },
        } as unknown as AnyFormApi

        const { result } = renderHook(() =>
          usePropertyValues(mockFormWithStore, 'nonexistent.path'),
        )

        expect(result.current).toBeUndefined()
      })
    })
  })
})
