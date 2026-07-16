import { renderHook } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { useEditCreditNote } from '../useEditCreditNote'

const renderUseEditCreditNote = () => {
  return renderHook(() => useEditCreditNote(), {
    wrapper: ({ children }) => <AllTheProviders>{children}</AllTheProviders>,
  })
}

describe('useEditCreditNote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('initial state', () => {
    it('returns updateCreditNote function', () => {
      const { result } = renderUseEditCreditNote()

      expect(result.current).toHaveProperty('updateCreditNote')
      expect(typeof result.current.updateCreditNote).toBe('function')
    })

    it('returns isUpdatingCreditNote boolean', () => {
      const { result } = renderUseEditCreditNote()

      expect(result.current).toHaveProperty('isUpdatingCreditNote')
      expect(typeof result.current.isUpdatingCreditNote).toBe('boolean')
    })

    it('has isUpdatingCreditNote initially set to false', () => {
      const { result } = renderUseEditCreditNote()

      expect(result.current.isUpdatingCreditNote).toBe(false)
    })
  })

  describe('return type', () => {
    it('returns the correct shape', () => {
      const { result } = renderUseEditCreditNote()

      const returnValue = result.current

      expect(Object.keys(returnValue)).toEqual(['updateCreditNote', 'isUpdatingCreditNote'])
    })
  })
})
