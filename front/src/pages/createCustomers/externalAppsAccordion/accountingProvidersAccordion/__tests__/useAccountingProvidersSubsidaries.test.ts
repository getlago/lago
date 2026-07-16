import { wait } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'

import {
  SubsidiariesListForExternalAppsAccordionDocument,
  SubsidiariesListForExternalAppsAccordionQuery,
} from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useAccountingProvidersSubsidaries } from '../useAccountingProvidersSubsidaries'

const mockSubsidiariesData: SubsidiariesListForExternalAppsAccordionQuery = {
  __typename: 'Query',
  integrationSubsidiaries: {
    __typename: 'SubsidiaryCollection',
    collection: [
      {
        __typename: 'Subsidiary',
        externalId: 'subsidiary-1',
        externalName: 'Subsidiary One',
      },
      {
        __typename: 'Subsidiary',
        externalId: 'subsidiary-2',
        externalName: 'Subsidiary Two',
      },
      {
        __typename: 'Subsidiary',
        externalId: 'subsidiary-3',
        externalName: null,
      },
    ],
  },
}

const mockEmptySubsidiariesData: SubsidiariesListForExternalAppsAccordionQuery = {
  __typename: 'Query',
  integrationSubsidiaries: {
    __typename: 'SubsidiaryCollection',
    collection: [],
  },
}

type PrepareType = {
  mockData?: Record<string, unknown>
  error?: boolean
  delay?: number
  networkError?: boolean
}

async function prepare({
  mockData,
  error = false,
  delay = 0,
  networkError = false,
  integrationId = '1',
}: PrepareType & { integrationId?: string } = {}) {
  const mocks = integrationId
    ? [
        {
          request: {
            query: SubsidiariesListForExternalAppsAccordionDocument,
            variables: { integrationId },
          },
          result: error
            ? {
                errors: [{ message: 'GraphQL error occurred' }],
              }
            : {
                data: mockData || mockSubsidiariesData,
              },
          delay,
          ...(networkError && { error: new Error('Network error') }),
        },
      ]
    : [] // No mocks when integrationId is undefined to ensure query is skipped

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const { result } = renderHook(() => useAccountingProvidersSubsidaries(integrationId), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('useAccountingProvidersSubsidaries', () => {
  describe('when query succeeds with data', () => {
    it('should return subsidiaries data', async () => {
      const { result } = await prepare()

      // Initially loading
      expect(result.current.subsidiariesData).toBeUndefined()

      // Wait for the query to resolve
      await waitFor(() => {
        expect(result.current.subsidiariesData).toBeDefined()
      })

      // After loading completes
      expect(result.current.subsidiariesData?.integrationSubsidiaries?.collection).toHaveLength(3)

      const collection = result.current.subsidiariesData?.integrationSubsidiaries?.collection

      expect(collection?.[0]).toEqual({
        __typename: 'Subsidiary',
        externalId: 'subsidiary-1',
        externalName: 'Subsidiary One',
      })
      expect(collection?.[1]).toEqual({
        __typename: 'Subsidiary',
        externalId: 'subsidiary-2',
        externalName: 'Subsidiary Two',
      })
      expect(collection?.[2]).toEqual({
        __typename: 'Subsidiary',
        externalId: 'subsidiary-3',
        externalName: null,
      })
    })

    it('should return empty data when no subsidiaries exist', async () => {
      const { result } = await prepare({ mockData: mockEmptySubsidiariesData })

      await waitFor(() => {
        expect(result.current.subsidiariesData).toBeDefined()
      })

      expect(result.current.subsidiariesData?.integrationSubsidiaries?.collection).toHaveLength(0)
    })

    it('should skip query when integrationId is not provided', async () => {
      // Test with completely separate mocks to avoid cache contamination
      const emptyMocks: never[] = []

      const customWrapper = ({ children }: { children: React.ReactNode }) =>
        AllTheProviders({
          children,
          mocks: emptyMocks,
          forceTypenames: true,
        })

      const { result } = renderHook(() => useAccountingProvidersSubsidaries(undefined), {
        wrapper: customWrapper,
      })

      // Should remain undefined since query is skipped
      expect(result.current.subsidiariesData).toBeUndefined()

      // Wait a bit to ensure query doesn't execute
      await act(() => wait(100))

      expect(result.current.subsidiariesData).toBeUndefined()
    })
  })

  describe('when query fails', () => {
    it('should handle GraphQL errors gracefully', async () => {
      const { result } = await prepare({ error: true })

      // Initially should be undefined
      expect(result.current.subsidiariesData).toBeUndefined()

      // Even after error, subsidiariesData should remain undefined
      await waitFor(() => {
        // The hook should handle the error gracefully and return undefined data
        expect(result.current.subsidiariesData).toBeUndefined()
      })
    })

    it('should handle network errors gracefully', async () => {
      const { result } = await prepare({ networkError: true })

      // Initially should be undefined
      expect(result.current.subsidiariesData).toBeUndefined()

      // Even after network error, subsidiariesData should remain undefined
      await waitFor(() => {
        expect(result.current.subsidiariesData).toBeUndefined()
      })
    })
  })
})
