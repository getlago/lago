import { renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { useGetWebhookEndpointQuery } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useWebhookEndpoint } from '../useWebhookEndpoint'

const mockRefetch = jest.fn()

const mockWebhookData = {
  id: 'webhook-123',
  name: 'My Webhook',
  webhookUrl: 'https://example.com/webhook',
  signatureAlgo: 'hmac',
  eventTypes: ['customer.created', 'invoice.paid'],
}

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetWebhookEndpointQuery: jest.fn(),
}))

const TestWrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders>{children}</AllTheProviders>
)

TestWrapper.displayName = 'TestWrapper'

describe('useWebhookEndpoint', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    jest.mocked(useGetWebhookEndpointQuery).mockReturnValue({
      data: { webhookEndpoint: mockWebhookData },
      loading: false,
      refetch: mockRefetch,
    } as unknown as ReturnType<typeof useGetWebhookEndpointQuery>)
  })

  describe('GIVEN the hook is called with a valid id', () => {
    describe('WHEN data is loaded', () => {
      it('THEN should return webhook data', () => {
        const { result } = renderHook(() => useWebhookEndpoint({ id: 'webhook-123' }), {
          wrapper: TestWrapper,
        })

        expect(result.current.webhook).toEqual(mockWebhookData)
      })

      it('THEN should return loading as false', () => {
        const { result } = renderHook(() => useWebhookEndpoint({ id: 'webhook-123' }), {
          wrapper: TestWrapper,
        })

        expect(result.current.loading).toBe(false)
      })

      it('THEN should return a refetch function', () => {
        const { result } = renderHook(() => useWebhookEndpoint({ id: 'webhook-123' }), {
          wrapper: TestWrapper,
        })

        expect(result.current.refetch).toBeDefined()
      })

      it('THEN should call the query with correct variables', () => {
        renderHook(() => useWebhookEndpoint({ id: 'webhook-123' }), {
          wrapper: TestWrapper,
        })

        expect(useGetWebhookEndpointQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: { id: 'webhook-123' },
          }),
        )
      })
    })
  })

  describe('GIVEN the hook is called with skip set to true', () => {
    describe('WHEN skip is true', () => {
      it('THEN should skip the query', () => {
        renderHook(() => useWebhookEndpoint({ id: 'webhook-123', skip: true }), {
          wrapper: TestWrapper,
        })

        expect(useGetWebhookEndpointQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            skip: true,
          }),
        )
      })
    })
  })

  describe('GIVEN the hook is called with an empty id', () => {
    describe('WHEN id is an empty string', () => {
      it('THEN should skip the query', () => {
        renderHook(() => useWebhookEndpoint({ id: '' }), {
          wrapper: TestWrapper,
        })

        expect(useGetWebhookEndpointQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            skip: true,
          }),
        )
      })
    })
  })

  describe('GIVEN the hook is called with a fetchPolicy', () => {
    describe('WHEN fetchPolicy is provided', () => {
      it('THEN should pass fetchPolicy and nextFetchPolicy to the query', () => {
        renderHook(() => useWebhookEndpoint({ id: 'webhook-123', fetchPolicy: 'network-only' }), {
          wrapper: TestWrapper,
        })

        expect(useGetWebhookEndpointQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            fetchPolicy: 'network-only',
            nextFetchPolicy: 'network-only',
          }),
        )
      })
    })
  })

  describe('GIVEN the query is loading', () => {
    beforeEach(() => {
      jest.mocked(useGetWebhookEndpointQuery).mockReturnValue({
        data: undefined,
        loading: true,
        refetch: mockRefetch,
      } as unknown as ReturnType<typeof useGetWebhookEndpointQuery>)
    })

    describe('WHEN data is still loading', () => {
      it('THEN should return loading as true', () => {
        const { result } = renderHook(() => useWebhookEndpoint({ id: 'webhook-123' }), {
          wrapper: TestWrapper,
        })

        expect(result.current.loading).toBe(true)
      })

      it('THEN should return undefined webhook', () => {
        const { result } = renderHook(() => useWebhookEndpoint({ id: 'webhook-123' }), {
          wrapper: TestWrapper,
        })

        expect(result.current.webhook).toBeUndefined()
      })
    })
  })
})
