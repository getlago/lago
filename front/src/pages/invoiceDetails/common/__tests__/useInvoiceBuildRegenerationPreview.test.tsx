import { renderHook } from '@testing-library/react'

import { useGetInvoiceBuildRegenerationPreviewQuery } from '~/generated/graphql'

import { useInvoiceBuildRegenerationPreview } from '../useInvoiceBuildRegenerationPreview'

jest.mock('~/generated/graphql', () => {
  const actual = jest.requireActual('~/generated/graphql')

  return {
    ...actual,
    useGetInvoiceBuildRegenerationPreviewQuery: jest.fn(),
  }
})

const mockUseGetInvoiceBuildRegenerationPreviewQuery =
  useGetInvoiceBuildRegenerationPreviewQuery as jest.Mock

const renderUseInvoiceBuildRegenerationPreview = (invoiceId?: string) => {
  return renderHook(() => useInvoiceBuildRegenerationPreview(invoiceId))
}

describe('useInvoiceBuildRegenerationPreview', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    mockUseGetInvoiceBuildRegenerationPreviewQuery.mockReturnValue({
      data: undefined,
      error: undefined,
      loading: false,
    })
  })

  describe('initial state', () => {
    it('returns all expected properties', () => {
      const { result } = renderUseInvoiceBuildRegenerationPreview('invoice-id')

      expect(result.current).toHaveProperty('data')
      expect(result.current).toHaveProperty('error')
      expect(result.current).toHaveProperty('invoiceBuildRegenerationPreview')
      expect(result.current).toHaveProperty('loading')
    })

    it('has loading initially set to false', () => {
      const { result } = renderUseInvoiceBuildRegenerationPreview('invoice-id')

      expect(result.current.loading).toBe(false)
    })
  })

  describe('query options', () => {
    it('queries the invoice build regeneration preview with the provided invoice id', () => {
      renderUseInvoiceBuildRegenerationPreview('invoice-id')

      expect(mockUseGetInvoiceBuildRegenerationPreviewQuery).toHaveBeenCalledWith({
        variables: { id: 'invoice-id' },
        skip: false,
        fetchPolicy: 'cache-and-network',
        notifyOnNetworkStatusChange: true,
      })
    })

    it('skips the query when no invoice id is provided', () => {
      renderUseInvoiceBuildRegenerationPreview()

      expect(mockUseGetInvoiceBuildRegenerationPreviewQuery).toHaveBeenCalledWith({
        variables: { id: undefined },
        skip: true,
        fetchPolicy: 'cache-and-network',
        notifyOnNetworkStatusChange: true,
      })
    })
  })

  describe('return type', () => {
    it('returns the correct shape', () => {
      const { result } = renderUseInvoiceBuildRegenerationPreview('invoice-id')

      expect(Object.keys(result.current)).toEqual([
        'data',
        'error',
        'invoiceBuildRegenerationPreview',
        'loading',
      ])
    })

    it('returns the invoice build regeneration preview from the query data', () => {
      const invoiceBuildRegenerationPreview = { id: 'invoice-id' }

      mockUseGetInvoiceBuildRegenerationPreviewQuery.mockReturnValue({
        data: { invoiceBuildRegenerationPreview },
        error: undefined,
        loading: false,
      })

      const { result } = renderUseInvoiceBuildRegenerationPreview('invoice-id')

      expect(result.current.invoiceBuildRegenerationPreview).toBe(invoiceBuildRegenerationPreview)
    })
  })
})
