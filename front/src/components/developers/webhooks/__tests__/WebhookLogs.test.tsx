import { render as rtlRender, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useGetWebhookLogLazyQuery } from '~/generated/graphql'
import { AllTheProviders, testMockNavigateFn } from '~/test-utils'

import {
  WEBHOOK_LOGS_CONTAINER_TEST_ID,
  WEBHOOK_LOGS_RELOAD_BUTTON_TEST_ID,
  WEBHOOK_LOGS_SEARCH_INPUT_TEST_ID,
  WebhookLogs,
} from '../WebhookLogs'

// Mock hooks and dependencies
const mockGetWebhookLogs = jest.fn()
const mockDebouncedSearch = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: () => ({
    debouncedSearch: mockDebouncedSearch,
    isLoading: false,
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetWebhookLogLazyQuery: jest.fn(),
}))

jest.mock('~/core/utils/getCurrentBreakpoint', () => ({
  getCurrentBreakpoint: () => 'md',
}))

jest.mock('~/components/designSystem/Filters', () => ({
  Filters: {
    Provider: ({ children }: { children: React.ReactNode }) => (
      <div data-test="filters-provider-mock">{children}</div>
    ),
    Component: () => <div data-test="filters-component-mock" />,
  },
  formatFiltersForWebhookLogsQuery: () => ({}),
  WebhookLogsAvailableFilters: [],
}))

jest.mock('~/components/developers/webhooks/WebhookLogDetails', () => ({
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  WebhookLogDetails: ({ goBack }: { goBack: () => void }) => (
    <div data-test="webhook-log-details-mock">Log Details</div>
  ),
}))

jest.mock('~/components/developers/webhooks/WebhookLogTable', () => ({
  WebhookLogTable: () => <div data-test="webhook-log-table-mock">Log Table</div>,
}))

const mockWebhookLogsData = {
  webhooks: {
    metadata: { currentPage: 1, totalPages: 1 },
    collection: [
      {
        id: 'log-1',
        status: 'succeeded',
        webhookType: 'customer.created',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
        endpoint: 'https://example.com/webhook',
      },
      {
        id: 'log-2',
        status: 'failed',
        webhookType: 'invoice.paid',
        createdAt: '2024-01-02T00:00:00Z',
        updatedAt: '2024-01-02T00:00:00Z',
        endpoint: 'https://example.com/webhook',
      },
    ],
  },
}

const renderWithParams = (
  ui: React.ReactElement,
  params: Record<string, string> = { webhookId: 'webhook-123' },
) => {
  return rtlRender(ui, {
    wrapper: ({ children }) => <AllTheProviders useParams={params}>{children}</AllTheProviders>,
  })
}

describe('WebhookLogs', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    mockGetWebhookLogs.mockResolvedValue({ data: mockWebhookLogsData })

    jest.mocked(useGetWebhookLogLazyQuery).mockReturnValue([
      mockGetWebhookLogs,
      {
        data: mockWebhookLogsData,
        loading: false,
        called: true,
      } as unknown as ReturnType<typeof useGetWebhookLogLazyQuery>[1],
    ])
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should display the container', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />)

        expect(screen.getByTestId(WEBHOOK_LOGS_CONTAINER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the search input', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />)

        expect(screen.getByTestId(WEBHOOK_LOGS_SEARCH_INPUT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the reload button', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />)

        expect(screen.getByTestId(WEBHOOK_LOGS_RELOAD_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the webhook log table', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />)

        expect(screen.getByTestId('webhook-log-table-mock')).toBeInTheDocument()
      })

      it('THEN should display the filters', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />)

        expect(screen.getByTestId('filters-component-mock')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no logId in params and data has logs', () => {
    describe('WHEN the component renders', () => {
      it('THEN should not display log details (no logId)', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />, { webhookId: 'webhook-123' })

        expect(screen.queryByTestId('webhook-log-details-mock')).not.toBeInTheDocument()
      })

      it('THEN should navigate to the first log', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />, { webhookId: 'webhook-123' })

        expect(testMockNavigateFn).toHaveBeenCalledWith(
          expect.objectContaining({
            pathname: expect.stringContaining('log-1'),
          }),
          expect.objectContaining({ replace: true }),
        )
      })
    })
  })

  describe('GIVEN a logId is present in params', () => {
    describe('WHEN data has logs', () => {
      it('THEN should display log details', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />, {
          webhookId: 'webhook-123',
          logId: 'log-1',
        })

        expect(screen.getByTestId('webhook-log-details-mock')).toBeInTheDocument()
      })
    })

    describe('WHEN data has no logs', () => {
      beforeEach(() => {
        jest.mocked(useGetWebhookLogLazyQuery).mockReturnValue([
          mockGetWebhookLogs,
          {
            data: { webhooks: { metadata: { currentPage: 1, totalPages: 0 }, collection: [] } },
            loading: false,
            called: true,
          } as unknown as ReturnType<typeof useGetWebhookLogLazyQuery>[1],
        ])
      })

      it('THEN should not display log details', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />, {
          webhookId: 'webhook-123',
          logId: 'log-1',
        })

        expect(screen.queryByTestId('webhook-log-details-mock')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN user clicks the reload button', () => {
    describe('WHEN the button is clicked', () => {
      it('THEN should trigger a refetch', async () => {
        const user = userEvent.setup()

        renderWithParams(<WebhookLogs webhookId="webhook-123" />)

        const reloadButton = screen.getByTestId(WEBHOOK_LOGS_RELOAD_BUTTON_TEST_ID)

        await user.click(reloadButton)

        await waitFor(() => {
          expect(mockGetWebhookLogs).toHaveBeenCalledWith(
            expect.objectContaining({
              fetchPolicy: 'network-only',
            }),
          )
        })
      })
    })
  })

  describe('GIVEN data is loading', () => {
    beforeEach(() => {
      jest.mocked(useGetWebhookLogLazyQuery).mockReturnValue([
        mockGetWebhookLogs,
        {
          data: undefined,
          loading: true,
          called: true,
        } as unknown as ReturnType<typeof useGetWebhookLogLazyQuery>[1],
      ])
    })

    describe('WHEN the query is in progress', () => {
      it('THEN should still display the container', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />)

        expect(screen.getByTestId(WEBHOOK_LOGS_CONTAINER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should not display log details', () => {
        renderWithParams(<WebhookLogs webhookId="webhook-123" />, {
          webhookId: 'webhook-123',
          logId: 'log-1',
        })

        expect(screen.queryByTestId('webhook-log-details-mock')).not.toBeInTheDocument()
      })
    })
  })
})
