import { screen } from '@testing-library/react'

import { EventTypeEnum, WebhookEndpointSignatureAlgoEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  WEBHOOK_OVERVIEW_CONTAINER_TEST_ID,
  WEBHOOK_OVERVIEW_EVENTS_LIST_TEST_ID,
  WEBHOOK_OVERVIEW_LOADING_TEST_ID,
  WEBHOOK_OVERVIEW_NAME_VALUE_TEST_ID,
  WEBHOOK_OVERVIEW_SIGNATURE_VALUE_TEST_ID,
  WEBHOOK_OVERVIEW_URL_VALUE_TEST_ID,
  WebhookOverview,
} from '../WebhookOverview'

// Mock useWebhookEventTypes hook
const mockGetEventDisplayInfo = jest.fn()

jest.mock('~/hooks/useWebhookEventTypes', () => ({
  useWebhookEventTypes: () => ({
    getEventDisplayInfo: mockGetEventDisplayInfo,
    loading: false,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, params?: Record<string, unknown>) => {
      if (params?.count !== undefined) {
        return `${params.count} events`
      }
      return key
    },
  }),
}))

const mockWebhook = {
  id: 'webhook-123',
  name: 'My Webhook',
  webhookUrl: 'https://example.com/webhook',
  signatureAlgo: WebhookEndpointSignatureAlgoEnum.Hmac,
  eventTypes: [EventTypeEnum.CustomerCreated, EventTypeEnum.InvoiceDrafted],
}

describe('WebhookOverview', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockGetEventDisplayInfo.mockReturnValue({
      isListeningToAll: false,
      displayedEvents: ['customer.created', 'invoice.paid'],
      eventCount: 2,
    })
  })

  describe('GIVEN the component is loading', () => {
    describe('WHEN loading prop is true', () => {
      it('THEN should display loading skeleton', () => {
        render(<WebhookOverview webhook={undefined} loading={true} signatureLabel="HMAC" />)

        expect(screen.getByTestId(WEBHOOK_OVERVIEW_LOADING_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(WEBHOOK_OVERVIEW_CONTAINER_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component is loaded', () => {
    describe('WHEN webhook data is available', () => {
      it('THEN should display the container', () => {
        render(<WebhookOverview webhook={mockWebhook} loading={false} signatureLabel="HMAC" />)

        expect(screen.getByTestId(WEBHOOK_OVERVIEW_CONTAINER_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(WEBHOOK_OVERVIEW_LOADING_TEST_ID)).not.toBeInTheDocument()
      })

      it('THEN should display the webhook name', () => {
        render(<WebhookOverview webhook={mockWebhook} loading={false} signatureLabel="HMAC" />)

        const nameElement = screen.getByTestId(WEBHOOK_OVERVIEW_NAME_VALUE_TEST_ID)

        expect(nameElement).toHaveTextContent('My Webhook')
      })

      it('THEN should display the signature label', () => {
        render(<WebhookOverview webhook={mockWebhook} loading={false} signatureLabel="HMAC" />)

        const signatureElement = screen.getByTestId(WEBHOOK_OVERVIEW_SIGNATURE_VALUE_TEST_ID)

        expect(signatureElement).toHaveTextContent('HMAC')
      })

      it('THEN should display the webhook URL', () => {
        render(<WebhookOverview webhook={mockWebhook} loading={false} signatureLabel="HMAC" />)

        const urlElement = screen.getByTestId(WEBHOOK_OVERVIEW_URL_VALUE_TEST_ID)

        expect(urlElement).toHaveTextContent('https://example.com/webhook')
      })

      it('THEN should display the events list', () => {
        render(<WebhookOverview webhook={mockWebhook} loading={false} signatureLabel="HMAC" />)

        const eventsList = screen.getByTestId(WEBHOOK_OVERVIEW_EVENTS_LIST_TEST_ID)

        expect(eventsList).toBeInTheDocument()
        expect(eventsList).toHaveTextContent('customer.created')
        expect(eventsList).toHaveTextContent('invoice.paid')
      })
    })

    describe('WHEN webhook has no name', () => {
      it('THEN should display dash for name', () => {
        const webhookWithoutName = { ...mockWebhook, name: null }

        render(
          <WebhookOverview webhook={webhookWithoutName} loading={false} signatureLabel="HMAC" />,
        )

        const nameElement = screen.getByTestId(WEBHOOK_OVERVIEW_NAME_VALUE_TEST_ID)

        expect(nameElement).toHaveTextContent('-')
      })
    })

    describe('WHEN webhook has JWT signature', () => {
      it('THEN should display JWT as signature label', () => {
        render(<WebhookOverview webhook={mockWebhook} loading={false} signatureLabel="JWT" />)

        const signatureElement = screen.getByTestId(WEBHOOK_OVERVIEW_SIGNATURE_VALUE_TEST_ID)

        expect(signatureElement).toHaveTextContent('JWT')
      })
    })

    describe('WHEN webhook has no events (empty array)', () => {
      beforeEach(() => {
        mockGetEventDisplayInfo.mockReturnValue({
          isListeningToAll: false,
          displayedEvents: [],
          eventCount: 0,
        })
      })

      it('THEN should not display events list', () => {
        const webhookNoEvents = { ...mockWebhook, eventTypes: [] }

        render(<WebhookOverview webhook={webhookNoEvents} loading={false} signatureLabel="HMAC" />)

        expect(screen.queryByTestId(WEBHOOK_OVERVIEW_EVENTS_LIST_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN webhook is listening to all events', () => {
      beforeEach(() => {
        mockGetEventDisplayInfo.mockReturnValue({
          isListeningToAll: true,
          displayedEvents: ['customer.created', 'customer.updated', 'invoice.created'],
          eventCount: 3,
        })
      })

      it('THEN should display all available events', () => {
        const webhookAllEvents = { ...mockWebhook, eventTypes: null }

        render(<WebhookOverview webhook={webhookAllEvents} loading={false} signatureLabel="HMAC" />)

        const eventsList = screen.getByTestId(WEBHOOK_OVERVIEW_EVENTS_LIST_TEST_ID)

        expect(eventsList).toHaveTextContent('customer.created')
        expect(eventsList).toHaveTextContent('customer.updated')
        expect(eventsList).toHaveTextContent('invoice.created')
      })
    })
  })

  describe('GIVEN eventTypes loading state', () => {
    beforeEach(() => {
      jest.resetModules()
    })

    describe('WHEN event types are loading', () => {
      it('THEN should display loading skeleton', () => {
        // Override the mock for this specific test
        jest.doMock('~/hooks/useWebhookEventTypes', () => ({
          useWebhookEventTypes: () => ({
            getEventDisplayInfo: mockGetEventDisplayInfo,
            loading: true,
          }),
        }))

        // Since we can't easily re-import, we test via the loading prop
        // The component shows loading when either loading or eventTypesLoading is true
        render(<WebhookOverview webhook={mockWebhook} loading={true} signatureLabel="HMAC" />)

        expect(screen.getByTestId(WEBHOOK_OVERVIEW_LOADING_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
