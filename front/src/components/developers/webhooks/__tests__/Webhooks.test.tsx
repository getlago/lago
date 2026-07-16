import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  EventTypeEnum,
  GetOrganizationHmacDataQuery,
  GetWebhookListQuery,
  useGetOrganizationHmacDataQuery,
  useGetWebhookListQuery,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import { Webhooks } from '../Webhooks'

// Mock hooks
const mockClosePanel = jest.fn()
const mockSetMainRouterUrl = jest.fn()

jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({
    closePanel: mockClosePanel,
    setMainRouterUrl: mockSetMainRouterUrl,
  }),
}))

jest.mock('~/components/developers/webhooks/useDeleteWebhook', () => ({
  useDeleteWebhook: () => ({
    openDialog: jest.fn(),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => {
      if (key === 'text_1746190277237vdc9v07s2fe') return 'Add a webhook endpoint'
      return key
    },
  }),
}))

jest.mock('~/hooks/useWebhookEventTypes', () => ({
  useWebhookEventTypes: () => ({
    getEventDisplayInfo: () => ({ eventCount: 1 }),
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetWebhookListQuery: jest.fn(),
  useGetOrganizationHmacDataQuery: jest.fn(),
}))

// Mock data
const mockWebhookListData: GetWebhookListQuery = {
  webhookEndpoints: {
    collection: [
      {
        id: 'webhook-1',
        name: 'My Webhook',
        webhookUrl: 'https://example.com/webhook1',
        eventTypes: [EventTypeEnum.CustomerCreated],
      },
      {
        id: 'webhook-2',
        name: null,
        webhookUrl: 'https://example.com/webhook2',
        eventTypes: null,
      },
    ],
  },
}

const mockOrganizationHmacData: GetOrganizationHmacDataQuery = {
  organization: { id: 'org-1', hmacKey: 'test-hmac-key' },
}

const maxWebhooksListData: GetWebhookListQuery = {
  webhookEndpoints: {
    collection: Array.from({ length: 25 }, (_, i) => ({
      id: `webhook-${i + 1}`,
      name: null,
      webhookUrl: `https://example.com/webhook${i + 1}`,
      eventTypes: [EventTypeEnum.CustomerCreated],
    })),
  },
}

describe('Webhooks', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    jest.mocked(useGetWebhookListQuery).mockReturnValue({
      data: mockWebhookListData,
      loading: false,
    } as ReturnType<typeof useGetWebhookListQuery>)

    jest.mocked(useGetOrganizationHmacDataQuery).mockReturnValue({
      data: mockOrganizationHmacData,
      loading: false,
    } as ReturnType<typeof useGetOrganizationHmacDataQuery>)
  })

  describe('GIVEN webhooks data is loaded', () => {
    it('THEN should display webhook name when present, and URL otherwise', () => {
      render(<Webhooks />)

      expect(screen.getByText('My Webhook')).toBeInTheDocument()
      expect(screen.getByText('https://example.com/webhook1')).toBeInTheDocument()
      expect(screen.getByText('https://example.com/webhook2')).toBeInTheDocument()
    })
  })

  describe('GIVEN user clicks the add webhook button', () => {
    it('THEN should navigate to create route and close the panel', async () => {
      const user = userEvent.setup()

      render(<Webhooks />)

      await user.click(screen.getByRole('button', { name: /add a webhook endpoint/i }))

      expect(mockSetMainRouterUrl).toHaveBeenCalledWith('/webhook/create')
      expect(mockClosePanel).toHaveBeenCalled()
    })
  })

  describe('GIVEN webhook count is at the limit (25)', () => {
    beforeEach(() => {
      jest.mocked(useGetWebhookListQuery).mockReturnValue({
        data: maxWebhooksListData,
        loading: false,
      } as ReturnType<typeof useGetWebhookListQuery>)
    })

    it('THEN should disable the add webhook button', () => {
      render(<Webhooks />)

      expect(screen.getByRole('button', { name: /add a webhook endpoint/i })).toBeDisabled()
    })
  })
})
