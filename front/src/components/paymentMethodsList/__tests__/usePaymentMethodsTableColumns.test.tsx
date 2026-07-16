import { renderHook } from '@testing-library/react'

import { usePaymentMethodsTableColumns } from '../usePaymentMethodsTableColumns'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('usePaymentMethodsTableColumns', () => {
  const mockSetPaymentMethodAsDefault = jest.fn().mockResolvedValue(undefined)
  const mockOnDeletePaymentMethod = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('WHEN generating table columns', () => {
    it('THEN returns columns and actionColumn', () => {
      const { result } = renderHook(() =>
        usePaymentMethodsTableColumns({
          setPaymentMethodAsDefault: mockSetPaymentMethodAsDefault,
          onDeletePaymentMethod: mockOnDeletePaymentMethod,
        }),
      )

      expect(result.current.columns).toBeDefined()
      expect(result.current.actionColumn).toBeDefined()
    })
  })
})
