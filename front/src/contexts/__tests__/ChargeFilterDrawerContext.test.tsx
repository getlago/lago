import { renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { ChargeModelEnum, CurrencyEnum } from '~/generated/graphql'

import {
  ChargeFilterDrawerProvider,
  useChargeFilterDrawerContext,
} from '../ChargeFilterDrawerContext'

describe('ChargeFilterDrawerContext', () => {
  describe('GIVEN useChargeFilterDrawerContext is called within a ChargeFilterDrawerProvider', () => {
    describe('WHEN the provider supplies all required values', () => {
      it('THEN should return the provided chargeModel', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFilterDrawerProvider
            chargeModel={ChargeModelEnum.Standard}
            chargeType="fixed"
            currency={CurrencyEnum.Eur}
            chargePricingUnitShortName={undefined}
            isEdition={false}
          >
            {children}
          </ChargeFilterDrawerProvider>
        )

        const { result } = renderHook(() => useChargeFilterDrawerContext(), { wrapper })

        expect(result.current.chargeModel).toBe(ChargeModelEnum.Standard)
      })

      it('THEN should return the provided chargeType', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFilterDrawerProvider
            chargeModel={ChargeModelEnum.Graduated}
            chargeType="usage"
            currency={CurrencyEnum.Usd}
            chargePricingUnitShortName={undefined}
            isEdition={false}
          >
            {children}
          </ChargeFilterDrawerProvider>
        )

        const { result } = renderHook(() => useChargeFilterDrawerContext(), { wrapper })

        expect(result.current.chargeType).toBe('usage')
      })

      it('THEN should return the provided currency', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFilterDrawerProvider
            chargeModel={ChargeModelEnum.Package}
            chargeType="fixed"
            currency={CurrencyEnum.Gbp}
            chargePricingUnitShortName="GBP"
            isEdition={true}
          >
            {children}
          </ChargeFilterDrawerProvider>
        )

        const { result } = renderHook(() => useChargeFilterDrawerContext(), { wrapper })

        expect(result.current.currency).toBe(CurrencyEnum.Gbp)
        expect(result.current.chargePricingUnitShortName).toBe('GBP')
      })

      it('THEN should return the provided isEdition value', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFilterDrawerProvider
            chargeModel={ChargeModelEnum.Volume}
            chargeType="usage"
            currency={CurrencyEnum.Usd}
            chargePricingUnitShortName={undefined}
            isEdition={true}
          >
            {children}
          </ChargeFilterDrawerProvider>
        )

        const { result } = renderHook(() => useChargeFilterDrawerContext(), { wrapper })

        expect(result.current.isEdition).toBe(true)
      })
    })

    describe('WHEN chargePricingUnitShortName is undefined', () => {
      it('THEN should return undefined for chargePricingUnitShortName', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <ChargeFilterDrawerProvider
            chargeModel={ChargeModelEnum.Standard}
            chargeType="fixed"
            currency={CurrencyEnum.Eur}
            chargePricingUnitShortName={undefined}
            isEdition={false}
          >
            {children}
          </ChargeFilterDrawerProvider>
        )

        const { result } = renderHook(() => useChargeFilterDrawerContext(), { wrapper })

        expect(result.current.chargePricingUnitShortName).toBeUndefined()
      })
    })
  })

  describe('GIVEN useChargeFilterDrawerContext is called outside a ChargeFilterDrawerProvider', () => {
    describe('WHEN there is no provider in the tree', () => {
      it('THEN should throw an error', () => {
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

        expect(() => {
          renderHook(() => useChargeFilterDrawerContext())
        }).toThrow('useChargeFilterDrawerContext must be used within a ChargeFilterDrawerProvider')

        consoleSpy.mockRestore()
      })
    })
  })
})
