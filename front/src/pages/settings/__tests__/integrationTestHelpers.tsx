import { DocumentNode } from '@apollo/client'
import { act, render as rtlRender } from '@testing-library/react'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { ProviderTypeEnum } from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

export function createPaymentProviderListMock(
  document: DocumentNode,
  providerType: ProviderTypeEnum,
  typename: string,
  connections: Array<{ id: string; name: string; code: string }> = [
    { id: 'test-id-1', name: 'Test Connection', code: 'test-code' },
  ],
): TestMocksType {
  return [
    {
      request: {
        query: document,
        variables: { limit: 1000, type: providerType },
      },
      result: {
        data: {
          paymentProviders: {
            __typename: 'PaymentProviderCollection',
            collection: connections.map((c) => ({
              __typename: typename,
              ...c,
            })),
          },
        },
      },
    },
  ]
}

export function createPaymentProviderListLoadingMock(
  document: DocumentNode,
  providerType: ProviderTypeEnum,
): TestMocksType {
  return [
    {
      request: {
        query: document,
        variables: { limit: 1000, type: providerType },
      },
      delay: 100000000,
      result: {
        data: {
          paymentProviders: {
            __typename: 'PaymentProviderCollection',
            collection: [],
          },
        },
      },
    },
  ]
}

export function createIntegrationListMock(
  document: DocumentNode,
  integrationType: string,
  typename: string,
  connections: Array<{ id: string; name: string; code: string }> = [
    { id: 'test-id-1', name: 'Test Connection', code: 'test-code' },
  ],
): TestMocksType {
  return [
    {
      request: {
        query: document,
        variables: { limit: 1000, types: [integrationType] },
      },
      result: {
        data: {
          integrations: {
            __typename: 'IntegrationCollection',
            collection: connections.map((c) => ({
              __typename: typename,
              ...c,
            })),
          },
        },
      },
    },
  ]
}

export function createIntegrationListLoadingMock(
  document: DocumentNode,
  integrationType: string,
): TestMocksType {
  return [
    {
      request: {
        query: document,
        variables: { limit: 1000, types: [integrationType] },
      },
      delay: 100000000,
      result: {
        data: {
          integrations: {
            __typename: 'IntegrationCollection',
            collection: [],
          },
        },
      },
    },
  ]
}

export async function renderIntegrationPage(
  Component: React.ComponentType,
  options?: { mocks?: TestMocksType; useParams?: Record<string, string> },
) {
  const PageWithHeader = () => (
    <>
      <MainHeader />
      <Component />
    </>
  )

  let result: ReturnType<typeof rtlRender>

  await act(() => {
    result = rtlRender(<PageWithHeader />, {
      wrapper: ({ children }) => (
        <AllTheProviders
          mocks={options?.mocks}
          useParams={options?.useParams}
          forceTypenames={true}
        >
          {children}
        </AllTheProviders>
      ),
    })
  })

  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  return result!
}
