import { renderHook } from '@testing-library/react'

import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { createMockPaymentMethod } from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { PaymentMethodList } from '~/hooks/customer/usePaymentMethodsList'

import { useDisplayedPaymentMethod } from '../useDisplayedPaymentMethod'

describe('useDisplayedPaymentMethod', () => {
  describe('WHEN selectedPaymentMethod has paymentMethodId', () => {
    it('THEN returns the specific payment method with isManual false and isInherited false', () => {
      const paymentMethods: PaymentMethodList = [
        createMockPaymentMethod({
          id: 'pm_001',
          isDefault: false,
        }),
        createMockPaymentMethod({
          id: 'pm_002',
          isDefault: true,
        }),
      ]

      const selectedPaymentMethod = {
        paymentMethodId: 'pm_001',
        paymentMethodType: PaymentMethodTypeEnum.Provider,
      }

      const { result } = renderHook(() =>
        useDisplayedPaymentMethod(selectedPaymentMethod, paymentMethods),
      )

      expect(result.current.paymentMethod).not.toBeNull()
      expect(result.current.paymentMethod?.id).toBe('pm_001')
      expect(result.current.isManual).toBe(false)
      expect(result.current.isInherited).toBe(false)
    })
  })

  describe('WHEN selectedPaymentMethod has paymentMethodType Manual', () => {
    it('THEN returns manual payment method with isManual true and isInherited false', () => {
      const paymentMethods: PaymentMethodList = [
        createMockPaymentMethod({
          id: 'pm_001',
          isDefault: true,
        }),
      ]

      const selectedPaymentMethod = {
        paymentMethodType: PaymentMethodTypeEnum.Manual,
      }

      const { result } = renderHook(() =>
        useDisplayedPaymentMethod(selectedPaymentMethod, paymentMethods),
      )

      expect(result.current.paymentMethod).toBeNull()
      expect(result.current.isManual).toBe(true)
      expect(result.current.isInherited).toBe(false)
    })
  })

  describe('WHEN selectedPaymentMethod is null or undefined', () => {
    it('THEN falls back to default payment method when available', () => {
      const paymentMethods: PaymentMethodList = [
        createMockPaymentMethod({
          id: 'pm_001',
          isDefault: false,
        }),
        createMockPaymentMethod({
          id: 'pm_002',
          isDefault: true,
        }),
      ]

      const { result } = renderHook(() => useDisplayedPaymentMethod(null, paymentMethods))

      expect(result.current.paymentMethod).not.toBeNull()
      expect(result.current.paymentMethod?.id).toBe('pm_002')
      expect(result.current.isManual).toBe(false)
      expect(result.current.isInherited).toBe(true)
    })

    it('THEN falls back to manual when no default payment method is available', () => {
      const paymentMethods: PaymentMethodList = [
        createMockPaymentMethod({
          id: 'pm_001',
          isDefault: false,
        }),
      ]

      const { result } = renderHook(() => useDisplayedPaymentMethod(null, paymentMethods))

      expect(result.current.paymentMethod).toBeNull()
      expect(result.current.isManual).toBe(true)
      expect(result.current.isInherited).toBe(true)
    })
  })
})
