import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import { GetInvoiceCustomSectionsDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useInvoiceCustomSections, useInvoiceCustomSectionsLazy } from '../useInvoiceCustomSections'

const mockInvoiceCustomSectionsResponse = {
  invoiceCustomSections: {
    __typename: 'InvoiceCustomSectionCollection',
    collection: [
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-1',
        name: 'Section 1',
        code: 'SECTION_1',
      },
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-2',
        name: 'Section 2',
        code: 'SECTION_2',
      },
    ],
  },
}

async function prepare({ mock }: { mock?: Record<string, unknown> } = {}) {
  const mocks = [
    {
      request: {
        query: GetInvoiceCustomSectionsDocument,
        variables: {},
      },
      result: {
        data: mock || mockInvoiceCustomSectionsResponse,
      },
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const { result } = renderHook(() => useInvoiceCustomSections(), {
    wrapper: customWrapper,
  })

  return { result }
}

async function prepareLazy({ mock }: { mock?: Record<string, unknown> } = {}) {
  const mocks = [
    {
      request: {
        query: GetInvoiceCustomSectionsDocument,
        variables: {},
      },
      result: {
        data: mock || mockInvoiceCustomSectionsResponse,
      },
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const { result } = renderHook(() => useInvoiceCustomSectionsLazy(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('useInvoiceCustomSections', () => {
  describe('WHEN query succeeds', () => {
    it('THEN returns invoice custom sections list with the right length', async () => {
      const { result } = await prepare()

      await act(() => wait(0))
      expect(result.current.data).toHaveLength(2)
    })

    it('THEN returns empty array when data is null', async () => {
      const { result } = await prepare({
        mock: {
          invoiceCustomSections: null,
        },
      })

      await act(() => wait(0))
      expect(result.current.data).toEqual([])
    })

    it('THEN returns empty array when collection is empty', async () => {
      const { result } = await prepare({
        mock: {
          invoiceCustomSections: {
            __typename: 'InvoiceCustomSectionCollection',
            collection: [],
          },
        },
      })

      await act(() => wait(0))
      expect(result.current.data).toEqual([])
    })
  })
})

describe('useInvoiceCustomSectionsLazy', () => {
  describe('WHEN query is triggered and succeeds', () => {
    it('THEN returns invoice custom sections list with the right length', async () => {
      const { result } = await prepareLazy()

      act(() => {
        result.current.getInvoiceCustomSections()
      })

      await act(() => wait(0))
      expect(result.current.data).toHaveLength(2)
    })

    it('THEN returns empty array when data is null', async () => {
      const { result } = await prepareLazy({
        mock: {
          invoiceCustomSections: null,
        },
      })

      act(() => {
        result.current.getInvoiceCustomSections()
      })

      await act(() => wait(0))
      expect(result.current.data).toEqual([])
    })

    it('THEN returns empty array when collection is empty', async () => {
      const { result } = await prepareLazy({
        mock: {
          invoiceCustomSections: {
            __typename: 'InvoiceCustomSectionCollection',
            collection: [],
          },
        },
      })

      expect(result.current.data).toEqual([])

      act(() => {
        result.current.getInvoiceCustomSections()
      })

      await act(() => wait(0))
      expect(result.current.data).toEqual([])
    })
  })
})
