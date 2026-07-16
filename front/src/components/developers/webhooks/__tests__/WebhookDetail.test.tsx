import { render as rtlRender, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { WEBHOOKS_ROUTE } from '~/components/developers/devtoolsRoutes'
import { EventTypeEnum, WebhookEndpointSignatureAlgoEnum } from '~/generated/graphql'
import { useWebhookEndpoint } from '~/hooks/useWebhookEndpoint'
import { AllTheProviders, testMockNavigateFn } from '~/test-utils'

import {
  WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID,
  WEBHOOK_DETAIL_BACK_BUTTON_TEST_ID,
  WEBHOOK_DETAIL_DELETE_BUTTON_TEST_ID,
  WEBHOOK_DETAIL_EDIT_BUTTON_TEST_ID,
  WEBHOOK_DETAIL_SUBTITLE_TEST_ID,
  WEBHOOK_DETAIL_TITLE_TEST_ID,
  WebhookDetail,
} from '../WebhookDetail'

// Mock hooks
const mockClosePanel = jest.fn()
const mockSetMainRouterUrl = jest.fn()
const mockOpenDeleteDialog = jest.fn()
const mockRefetch = jest.fn()

jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({
    closePanel: mockClosePanel,
    setMainRouterUrl: mockSetMainRouterUrl,
  }),
}))

jest.mock('../useDeleteWebhook', () => ({
  useDeleteWebhook: () => ({
    openDialog: mockOpenDeleteDialog,
  }),
}))

jest.mock('~/hooks/useWebhookEndpoint', () => ({
  useWebhookEndpoint: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

// Mock child components to simplify testing
jest.mock('../WebhookOverview', () => ({
  WebhookOverview: () => <div data-test="webhook-overview-mock">Overview</div>,
}))

jest.mock('../WebhookLogs', () => ({
  WebhookLogs: () => <div data-test="webhook-logs-mock">Logs</div>,
}))

const mockWebhookData = {
  id: 'webhook-123',
  name: 'My Webhook',
  webhookUrl: 'https://example.com/webhook',
  signatureAlgo: WebhookEndpointSignatureAlgoEnum.Hmac,
  eventTypes: [EventTypeEnum.CustomerCreated],
}

// Custom render that passes useParams to AllTheProviders
const renderWithParams = (ui: React.ReactElement, params = { webhookId: 'webhook-123' }) => {
  return rtlRender(ui, {
    wrapper: ({ children }) => <AllTheProviders useParams={params}>{children}</AllTheProviders>,
  })
}

describe('WebhookDetail', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    // Default mock return value
    jest.mocked(useWebhookEndpoint).mockReturnValue({
      webhook: mockWebhookData,
      loading: false,
      refetch: mockRefetch,
    })
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN webhook data is loaded', () => {
      it('THEN should display the back button', () => {
        renderWithParams(<WebhookDetail />)

        expect(screen.getByTestId(WEBHOOK_DETAIL_BACK_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the webhook title', () => {
        renderWithParams(<WebhookDetail />)

        const title = screen.getByTestId(WEBHOOK_DETAIL_TITLE_TEST_ID)

        expect(title).toHaveTextContent('My Webhook')
      })

      it('THEN should display the webhook URL as subtitle when name exists', () => {
        renderWithParams(<WebhookDetail />)

        const subtitle = screen.getByTestId(WEBHOOK_DETAIL_SUBTITLE_TEST_ID)

        expect(subtitle).toHaveTextContent('https://example.com/webhook')
      })

      it('THEN should display the actions button', () => {
        renderWithParams(<WebhookDetail />)

        expect(screen.getByTestId(WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN webhook has no name', () => {
      beforeEach(() => {
        jest.mocked(useWebhookEndpoint).mockReturnValue({
          webhook: { ...mockWebhookData, name: null },
          loading: false,
          refetch: mockRefetch,
        })
      })

      it('THEN should display webhook URL as title', () => {
        renderWithParams(<WebhookDetail />)

        const title = screen.getByTestId(WEBHOOK_DETAIL_TITLE_TEST_ID)

        expect(title).toHaveTextContent('https://example.com/webhook')
      })

      it('THEN should not display subtitle', () => {
        renderWithParams(<WebhookDetail />)

        expect(screen.queryByTestId(WEBHOOK_DETAIL_SUBTITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN user clicks the back button', () => {
    describe('WHEN the button is clicked', () => {
      it('THEN should navigate to webhooks route', async () => {
        const user = userEvent.setup()

        renderWithParams(<WebhookDetail />)

        const backButton = screen.getByTestId(WEBHOOK_DETAIL_BACK_BUTTON_TEST_ID)

        await user.click(backButton)

        expect(testMockNavigateFn).toHaveBeenCalledWith(WEBHOOKS_ROUTE)
      })
    })
  })

  describe('GIVEN user opens the actions menu', () => {
    describe('WHEN user clicks the actions button', () => {
      it('THEN should display edit and delete options', async () => {
        const user = userEvent.setup()

        renderWithParams(<WebhookDetail />)

        const actionsButton = screen.getByTestId(WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID)

        await user.click(actionsButton)

        await waitFor(() => {
          expect(screen.getByTestId(WEBHOOK_DETAIL_EDIT_BUTTON_TEST_ID)).toBeInTheDocument()
          expect(screen.getByTestId(WEBHOOK_DETAIL_DELETE_BUTTON_TEST_ID)).toBeInTheDocument()
        })
      })
    })

    describe('WHEN user clicks the edit button', () => {
      it('THEN should set main router URL and close panel', async () => {
        const user = userEvent.setup()

        renderWithParams(<WebhookDetail />)

        const actionsButton = screen.getByTestId(WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID)

        await user.click(actionsButton)

        await waitFor(() => {
          expect(screen.getByTestId(WEBHOOK_DETAIL_EDIT_BUTTON_TEST_ID)).toBeInTheDocument()
        })

        const editButton = screen.getByTestId(WEBHOOK_DETAIL_EDIT_BUTTON_TEST_ID)

        await user.click(editButton)

        expect(mockSetMainRouterUrl).toHaveBeenCalled()
        expect(mockClosePanel).toHaveBeenCalled()
      })
    })

    describe('WHEN user clicks the delete button', () => {
      it('THEN should open delete dialog with correct webhook ID', async () => {
        const user = userEvent.setup()

        renderWithParams(<WebhookDetail />)

        const actionsButton = screen.getByTestId(WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID)

        await user.click(actionsButton)

        await waitFor(() => {
          expect(screen.getByTestId(WEBHOOK_DETAIL_DELETE_BUTTON_TEST_ID)).toBeInTheDocument()
        })

        const deleteButton = screen.getByTestId(WEBHOOK_DETAIL_DELETE_BUTTON_TEST_ID)

        await user.click(deleteButton)

        expect(mockOpenDeleteDialog).toHaveBeenCalledWith('webhook-123', expect.any(Object))
      })
    })
  })

  describe('GIVEN loading state', () => {
    beforeEach(() => {
      jest.mocked(useWebhookEndpoint).mockReturnValue({
        webhook: undefined,
        loading: true,
        refetch: mockRefetch,
      })
    })

    describe('WHEN data is loading', () => {
      it('THEN should not display title', () => {
        renderWithParams(<WebhookDetail />)

        expect(screen.queryByTestId(WEBHOOK_DETAIL_TITLE_TEST_ID)).not.toBeInTheDocument()
      })

      it('THEN should still display actions button', () => {
        renderWithParams(<WebhookDetail />)

        expect(screen.getByTestId(WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN webhook has JWT signature', () => {
    beforeEach(() => {
      jest.mocked(useWebhookEndpoint).mockReturnValue({
        webhook: { ...mockWebhookData, signatureAlgo: WebhookEndpointSignatureAlgoEnum.Jwt },
        loading: false,
        refetch: mockRefetch,
      })
    })

    describe('WHEN component renders', () => {
      it('THEN should render without error', () => {
        renderWithParams(<WebhookDetail />)

        expect(screen.getByTestId(WEBHOOK_DETAIL_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
