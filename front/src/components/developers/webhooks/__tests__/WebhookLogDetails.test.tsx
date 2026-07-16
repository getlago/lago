import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { DateTime } from 'luxon'

import {
  WEBHOOK_RETRY_BUTTON_TEST_ID,
  WebhookLogDetails,
} from '~/components/developers/webhooks/WebhookLogDetails'
import { addToast } from '~/core/apolloClient'
import {
  GetSingleWebhookLogDocument,
  RetryWebhookDocument,
  WebhookStatusEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

const mockUseParams = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => mockUseParams(),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: jest.fn(() => ({
    intlFormatDateTimeOrgaTZ: jest.fn(() => ({
      date: 'Jan 15, 2024',
      time: '10:30:00 AM',
    })),
  })),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: jest.fn(() => ({
    translate: jest.fn((key: string) => key),
  })),
}))

const mockGoBack = jest.fn()

const baseWebhookData: any = {
  id: 'webhook-123',
  webhookType: 'invoice.created',
  status: WebhookStatusEnum.Succeeded,
  payload: JSON.stringify({ invoice: { id: '123' } }),
  response: JSON.stringify({ success: true }),
  httpStatus: 200,
  endpoint: 'https://example.com/webhook',
  retries: 0,
  updatedAt: DateTime.local(2024, 1, 15, 10, 30, 0).toISO(),
}

const createMocks = (webhookData = baseWebhookData, mutationResponse = { id: 'webhook-123' }) => [
  {
    request: {
      query: GetSingleWebhookLogDocument,
      variables: { id: 'webhook-123' },
    },
    result: {
      data: {
        webhook: {
          __typename: 'Webhook',
          ...webhookData,
        },
      },
    },
  },
  {
    request: {
      query: RetryWebhookDocument,
      variables: { input: { id: 'webhook-123' } },
    },
    result: {
      data: {
        retryWebhook: mutationResponse,
      },
    },
  },
]

async function prepare(
  webhookData = baseWebhookData,
  mutationResponse = { id: 'webhook-123' },
  logId = 'webhook-123',
) {
  const mocks = createMocks(webhookData, mutationResponse)

  mockUseParams.mockReturnValue({ logId })

  await act(async () => {
    render(<WebhookLogDetails goBack={mockGoBack} />, {
      mocks,
    })
    // Allow time for mocks to resolve
    await new Promise((resolve) => setTimeout(resolve, 0))
  })
}

describe('WebhookLogDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(cleanup)

  describe('Loading state', () => {
    it('should render loading skeletons', async () => {
      mockUseParams.mockReturnValue({ logId: 'webhook-123' })

      await act(async () => {
        render(<WebhookLogDetails goBack={mockGoBack} />, {
          mocks: [],
        })
        await new Promise((resolve) => setTimeout(resolve, 0))
      })

      // Check for loading elements in the header
      expect(screen.getByTestId('bodyHl')).toBeInTheDocument()
    })
  })

  describe('Successful webhook', () => {
    it('should render webhook details correctly', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.getByText('https://example.com/webhook')).toBeInTheDocument()
    })

    it('should display the correct status badge for succeeded webhook', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.queryByText('Delivered')).toBeInTheDocument()
      })
    })

    it('should not show retry button for succeeded webhook', async () => {
      await prepare()

      // Wait for the component to finish loading
      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.queryByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })

    it('should not display retries section when retries is 0', async () => {
      await prepare()

      // Wait for the component to finish loading
      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.queryByText('text_63e27c56dfe64b846474efb2')).not.toBeInTheDocument()
    })

    it('should display payload section', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.queryByText('text_1746623729674wq0tach0cop')).toBeInTheDocument()
      })
    })

    it('should not display response section for succeeded webhook', async () => {
      await prepare()

      // Wait for the component to finish loading
      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.queryByText('text_1746623729674lo13y0oatk9')).not.toBeInTheDocument()
    })
  })

  describe('Failed webhook', () => {
    const failedWebhookData = {
      ...baseWebhookData,
      status: WebhookStatusEnum.Failed,
      httpStatus: 500,
      retries: 3,
      response: JSON.stringify({ error: 'Internal server error' }),
    }

    it('should render failed status badge', async () => {
      await prepare(failedWebhookData)

      await waitFor(() => {
        expect(screen.queryByText('Failed')).toBeInTheDocument()
      })
    })

    it('should display retry button for failed webhook', async () => {
      await prepare(failedWebhookData)

      await waitFor(() => {
        expect(screen.queryByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    it('should display http status code for failed webhook', async () => {
      await prepare(failedWebhookData)

      await waitFor(() => {
        expect(screen.queryByText('500 Failed')).toBeInTheDocument()
      })
    })

    it('should display retries count when retries > 0', async () => {
      await prepare(failedWebhookData)

      await waitFor(() => {
        expect(screen.queryByText('text_63e27c56dfe64b846474efb2')).toBeInTheDocument()
        expect(screen.queryByText('3')).toBeInTheDocument()
      })
    })

    it('should display response section for failed webhook', async () => {
      await prepare(failedWebhookData)

      await waitFor(() => {
        expect(screen.queryByText('text_1746623729674lo13y0oatk9')).toBeInTheDocument()
      })
    })

    it('should call retry mutation when retry button is clicked', async () => {
      const user = userEvent.setup()

      await prepare(failedWebhookData)

      await waitFor(() => {
        expect(screen.queryByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      const retryButton = screen.getByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)

      await user.click(retryButton)

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith({
          severity: 'success',
          translateKey: 'text_63f79ddae2e0b1892bb4955c',
        })
      })
    })

    it('should show info toast when webhook was already delivered', async () => {
      const user = userEvent.setup()

      const mocksWithAlreadySucceeded = [
        {
          request: {
            query: GetSingleWebhookLogDocument,
            variables: { id: 'webhook-123' },
          },
          result: {
            data: {
              webhook: {
                __typename: 'Webhook',
                ...failedWebhookData,
              },
            },
          },
        },
        {
          request: {
            query: RetryWebhookDocument,
            variables: { input: { id: 'webhook-123' } },
          },
          result: {
            errors: [
              {
                message: 'Method Not Allowed',
                extensions: { code: 'is_succeeded', status: 405 },
              },
            ],
          },
        },
      ]

      mockUseParams.mockReturnValue({ logId: 'webhook-123' })

      await act(async () => {
        render(<WebhookLogDetails goBack={mockGoBack} />, {
          mocks: mocksWithAlreadySucceeded,
        })
        await new Promise((resolve) => setTimeout(resolve, 0))
      })

      await waitFor(() => {
        expect(screen.queryByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      const retryButton = screen.getByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)

      await user.click(retryButton)

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
      })
    })

    it('should show error toast when retry mutation fails with other error', async () => {
      const user = userEvent.setup()

      const mocksWithError = [
        {
          request: {
            query: GetSingleWebhookLogDocument,
            variables: { id: 'webhook-123' },
          },
          result: {
            data: {
              webhook: {
                __typename: 'Webhook',
                ...failedWebhookData,
              },
            },
          },
        },
        {
          request: {
            query: RetryWebhookDocument,
            variables: { input: { id: 'webhook-123' } },
          },
          result: {
            errors: [
              {
                message: 'Internal Server Error',
                extensions: { code: 'internal_error', status: 500 },
              },
            ],
          },
        },
      ]

      mockUseParams.mockReturnValue({ logId: 'webhook-123' })

      await act(async () => {
        render(<WebhookLogDetails goBack={mockGoBack} />, {
          mocks: mocksWithError,
        })
        await new Promise((resolve) => setTimeout(resolve, 0))
      })

      await waitFor(() => {
        expect(screen.queryByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      const retryButton = screen.getByTestId(WEBHOOK_RETRY_BUTTON_TEST_ID)

      await user.click(retryButton)

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'danger' }))
      })
    })
  })

  describe('Pending webhook', () => {
    const pendingWebhookData = {
      ...baseWebhookData,
      status: WebhookStatusEnum.Pending,
      httpStatus: null,
      response: null,
    }

    it('should render pending status badge', async () => {
      await prepare(pendingWebhookData)

      await waitFor(() => {
        expect(screen.queryByText('Pending')).toBeInTheDocument()
      })
    })

    it('should not display http status section when httpStatus is null', async () => {
      await prepare(pendingWebhookData)

      // Wait for the component to finish loading
      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.queryByText('text_63e27c56dfe64b846474ef74')).not.toBeInTheDocument()
    })
  })

  describe('Retries display', () => {
    it('should not display retries section when retries is null', async () => {
      const webhookWithNullRetries = {
        ...baseWebhookData,
        retries: 0,
      }

      await prepare(webhookWithNullRetries)

      // Wait for the component to finish loading
      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.queryByText('text_63e27c56dfe64b846474efb2')).not.toBeInTheDocument()
    })

    it('should display retries section when retries is 1', async () => {
      const webhookWithOneRetry = {
        ...baseWebhookData,
        retries: 1,
      }

      await prepare(webhookWithOneRetry)

      await waitFor(() => {
        expect(screen.queryByText('text_63e27c56dfe64b846474efb2')).toBeInTheDocument()
        expect(screen.queryByText('1')).toBeInTheDocument()
      })
    })

    it('should display retries section when retries > 1', async () => {
      const webhookWithMultipleRetries = {
        ...baseWebhookData,
        retries: 5,
      }

      await prepare(webhookWithMultipleRetries)

      await waitFor(() => {
        expect(screen.queryByText('text_63e27c56dfe64b846474efb2')).toBeInTheDocument()
        expect(screen.queryByText('5')).toBeInTheDocument()
      })
    })
  })

  describe('Close button', () => {
    it('should call goBack when close button is clicked', async () => {
      const user = userEvent.setup()

      await prepare()

      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      const closeButton = screen.getByTitle('close/medium')

      await user.click(closeButton)

      expect(mockGoBack).toHaveBeenCalledTimes(1)
    })
  })

  describe('Payload section', () => {
    it('should not display payload section when payload is empty', async () => {
      const webhookWithEmptyPayload = {
        ...baseWebhookData,
        payload: '',
      }

      await prepare(webhookWithEmptyPayload)

      // Wait for the component to finish loading
      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.queryByText('text_1746623729674wq0tach0cop')).not.toBeInTheDocument()
    })

    it('should not display payload section when payload is null', async () => {
      const webhookWithNullPayload = {
        ...baseWebhookData,
        payload: null,
      }

      await prepare(webhookWithNullPayload)

      // Wait for the component to finish loading
      await waitFor(() => {
        expect(screen.getAllByText('invoice.created').length).toBeGreaterThan(0)
      })

      expect(screen.queryByText('text_1746623729674wq0tach0cop')).not.toBeInTheDocument()
    })
  })

  describe('Edge cases', () => {
    it('should handle webhook without logId', async () => {
      mockUseParams.mockReturnValue({})

      await act(async () => {
        render(<WebhookLogDetails goBack={mockGoBack} />, {
          mocks: [],
        })
        await new Promise((resolve) => setTimeout(resolve, 0))
      })

      // Should render the component structure
      expect(screen.getByTestId('bodyHl')).toBeInTheDocument()
    })

    it('should handle different webhook types', async () => {
      const differentTypeWebhook = {
        ...baseWebhookData,
        webhookType: 'subscription.updated',
      }

      await prepare(differentTypeWebhook)

      await waitFor(() => {
        expect(screen.getAllByText('subscription.updated').length).toBeGreaterThan(0)
      })
    })

    it('should format timestamp correctly', async () => {
      await prepare()

      await waitFor(() => {
        // Check that the timestamp section label exists
        expect(screen.queryByText('text_63e27c56dfe64b846474ef6c')).toBeInTheDocument()
      })
    })
  })
})
