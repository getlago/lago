import { render, screen, waitFor } from '@testing-library/react'

import { maskValue } from '~/core/formats/maskValue'
import { GetApiKeysDocument, GetOrganizationInfosForApiKeyDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { ApiKeys } from '../ApiKeys'

// Mock IntersectionObserver (used by InfiniteScroll, undefined in jsdom)
const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})

globalThis.IntersectionObserver = mockIntersectionObserver

const MOCK_ORG_ID = 'org-12345-abcde-67890'
const MOCK_API_KEY_ID = 'api-key-12345'
const MOCK_API_KEY_VALUE = '••••••••xyz'

// Mock hooks that require providers
jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({ closePanel: jest.fn() }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: () => true }),
}))

const mockOrganizationData = {
  request: {
    query: GetOrganizationInfosForApiKeyDocument,
  },
  result: {
    data: {
      organization: {
        __typename: 'Organization',
        id: MOCK_ORG_ID,
        name: 'Test Organization',
        createdAt: '2024-01-01T00:00:00Z',
      },
    },
  },
}

const mockApiKeysData = {
  request: {
    query: GetApiKeysDocument,
    variables: { page: 1, limit: 20 },
  },
  result: {
    data: {
      apiKeys: {
        __typename: 'ApiKeyCollection',
        collection: [
          {
            __typename: 'ApiKey',
            id: MOCK_API_KEY_ID,
            name: 'Test API Key',
            value: MOCK_API_KEY_VALUE,
            createdAt: '2024-01-01T00:00:00Z',
            expiresAt: null,
            lastUsedAt: null,
          },
        ],
        metadata: {
          __typename: 'CollectionMetadata',
          currentPage: 1,
          totalPages: 1,
          totalCount: 1,
        },
      },
    },
  },
}

const renderComponent = () => {
  return render(<ApiKeys />, {
    wrapper: ({ children }) =>
      AllTheProviders({
        children,
        mocks: [mockOrganizationData, mockApiKeysData],
        forceTypenames: true,
      }),
  })
}

describe('ApiKeys', () => {
  it('should show masked organization ID by default', async () => {
    renderComponent()

    const maskedId = maskValue(MOCK_ORG_ID, { dotsCount: 8, visibleChars: 3 })

    await waitFor(() => {
      expect(screen.getByText(maskedId)).toBeInTheDocument()
    })
  })

  it('should display API key value in table', async () => {
    renderComponent()

    await waitFor(() => {
      expect(screen.getByText(MOCK_API_KEY_VALUE)).toBeInTheDocument()
    })
  })
})
