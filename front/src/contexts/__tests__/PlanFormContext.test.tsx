import { renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { CurrencyEnum, PlanInterval } from '~/generated/graphql'

import { PlanFormProvider, usePlanFormContext } from '../PlanFormContext'

describe('PlanFormContext', () => {
  describe('GIVEN usePlanFormContext is called within a PlanFormProvider', () => {
    describe('WHEN the provider supplies currency and interval', () => {
      it('THEN should return the provided currency', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <PlanFormProvider currency={CurrencyEnum.Eur} interval={PlanInterval.Yearly}>
            {children}
          </PlanFormProvider>
        )

        const { result } = renderHook(() => usePlanFormContext(), { wrapper })

        expect(result.current.currency).toBe(CurrencyEnum.Eur)
      })

      it('THEN should return the provided interval', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <PlanFormProvider currency={CurrencyEnum.Usd} interval={PlanInterval.Monthly}>
            {children}
          </PlanFormProvider>
        )

        const { result } = renderHook(() => usePlanFormContext(), { wrapper })

        expect(result.current.interval).toBe(PlanInterval.Monthly)
      })
    })

    describe('WHEN provider values change', () => {
      it('THEN should reflect the new values', () => {
        const wrapper = ({ children }: { children: ReactNode }) => (
          <PlanFormProvider currency={CurrencyEnum.Gbp} interval={PlanInterval.Quarterly}>
            {children}
          </PlanFormProvider>
        )

        const { result } = renderHook(() => usePlanFormContext(), { wrapper })

        expect(result.current.currency).toBe(CurrencyEnum.Gbp)
        expect(result.current.interval).toBe(PlanInterval.Quarterly)
      })
    })
  })

  describe('GIVEN usePlanFormContext is called outside a PlanFormProvider', () => {
    describe('WHEN there is no provider in the tree', () => {
      it('THEN should throw an error', () => {
        // Suppress console.error for the expected error
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

        expect(() => {
          renderHook(() => usePlanFormContext())
        }).toThrow('usePlanFormContext must be used within a PlanFormProvider')

        consoleSpy.mockRestore()
      })
    })
  })
})
