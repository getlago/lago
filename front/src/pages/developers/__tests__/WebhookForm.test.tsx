import { act, render as rtlRender, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { EventTypeEnum, WebhookEndpointSignatureAlgoEnum } from '~/generated/graphql'
import { useWebhookEndpoint } from '~/hooks/useWebhookEndpoint'
import { AllTheProviders } from '~/test-utils'

import WebhookForm, {
  WEBHOOK_FORM_CANCEL_BUTTON_TEST_ID,
  WEBHOOK_FORM_CLOSE_BUTTON_TEST_ID,
  WEBHOOK_FORM_NAME_INPUT_TEST_ID,
  WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID,
  WEBHOOK_FORM_URL_INPUT_TEST_ID,
} from '../WebhookForm'

// Mock hooks
const mockGoBack = jest.fn()
const mockOpenPanel = jest.fn()
const mockClosePanel = jest.fn()
let mockPanelOpen = false

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    goBack: mockGoBack,
  }),
}))

jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({
    panelOpen: mockPanelOpen,
    openPanel: mockOpenPanel,
    closePanel: mockClosePanel,
  }),
}))

const mockWebhookEndpointData = {
  id: 'webhook-123',
  name: 'My Webhook',
  webhookUrl: 'https://example.com/webhook',
  signatureAlgo: WebhookEndpointSignatureAlgoEnum.Hmac,
  eventTypes: [EventTypeEnum.CustomerCreated],
}

jest.mock('~/hooks/useWebhookEndpoint', () => ({
  useWebhookEndpoint: jest.fn(() => ({
    webhook: undefined,
    loading: false,
  })),
}))

jest.mock('~/hooks/useWebhookEventTypes', () => ({
  useWebhookEventTypes: () => ({
    defaultEventFormValues: {
      customer_created: false,
      invoice_created: false,
    },
    groups: [
      {
        id: 'CUSTOMERS',
        label: 'Customers',
        items: [
          { id: 'customer_created', label: 'customer.created', sublabel: 'Customer created' },
        ],
      },
      {
        id: 'INVOICES',
        label: 'Invoices',
        items: [{ id: 'invoice_created', label: 'invoice.created', sublabel: 'Invoice created' }],
      },
    ],
    loading: false,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

// Mock mutations
const mockCreateWebhook = jest.fn()
const mockUpdateWebhook = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useCreateWebhookEndpointMutation: () => [mockCreateWebhook],
  useUpdateWebhookEndpointMutation: () => [mockUpdateWebhook],
  WebhookEndpointSignatureAlgoEnum: {
    Hmac: 'hmac',
    Jwt: 'jwt',
  },
  LagoApiError: {
    UnprocessableEntity: 'unprocessable_entity',
  },
}))

const mockAddToast = jest.fn()
const mockHasDefinedGQLError = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (args: unknown) => mockAddToast(args),
  hasDefinedGQLError: (errorType: string, errors: unknown) =>
    mockHasDefinedGQLError(errorType, errors),
}))

// Mock child component
jest.mock('../webhookForm/WebhookEventsForm', () => ({
  __esModule: true,
  default: () => <div data-test="webhook-events-form-mock">Events Form</div>,
}))

// Custom render that passes useParams to AllTheProviders
const renderWithParams = (ui: React.ReactElement, params: { webhookId?: string } = {}) => {
  return rtlRender(ui, {
    wrapper: ({ children }) => <AllTheProviders useParams={params}>{children}</AllTheProviders>,
  })
}

describe('WebhookForm', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockPanelOpen = false
    mockHasDefinedGQLError.mockReturnValue(false)
  })

  describe('GIVEN the form is in create mode', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the close button', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        expect(screen.getByTestId(WEBHOOK_FORM_CLOSE_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the cancel button', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        expect(screen.getByTestId(WEBHOOK_FORM_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the submit button', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        expect(screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the events form section', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        expect(screen.getByTestId('webhook-events-form-mock')).toBeInTheDocument()
      })
    })

    describe('WHEN user clicks the close button', () => {
      it('THEN should call goBack and openPanel', async () => {
        const user = userEvent.setup()

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        const closeButton = screen.getByTestId(WEBHOOK_FORM_CLOSE_BUTTON_TEST_ID)

        await user.click(closeButton)

        expect(mockGoBack).toHaveBeenCalled()
        expect(mockOpenPanel).toHaveBeenCalled()
      })
    })

    describe('WHEN user clicks the cancel button', () => {
      it('THEN should call goBack and openPanel', async () => {
        const user = userEvent.setup()

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        const cancelButton = screen.getByTestId(WEBHOOK_FORM_CANCEL_BUTTON_TEST_ID)

        await user.click(cancelButton)

        expect(mockGoBack).toHaveBeenCalled()
        expect(mockOpenPanel).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the form is in edit mode', () => {
    beforeEach(() => {
      jest.mocked(useWebhookEndpoint).mockReturnValue({
        webhook: mockWebhookEndpointData,
        loading: false,
        refetch: jest.fn(),
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the form buttons', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />, { webhookId: 'webhook-123' })
        })

        expect(screen.getByTestId(WEBHOOK_FORM_CLOSE_BUTTON_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(WEBHOOK_FORM_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the form is loading', () => {
    beforeEach(() => {
      jest.mocked(useWebhookEndpoint).mockReturnValue({
        webhook: undefined,
        loading: true,
        refetch: jest.fn(),
      })
    })

    describe('WHEN webhook data is loading', () => {
      it('THEN should not display the close button (skeleton shown instead)', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        // During loading, the header shows a skeleton instead of the close button
        expect(screen.queryByTestId(WEBHOOK_FORM_CLOSE_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the developer panel is open', () => {
    beforeEach(() => {
      mockPanelOpen = true
      jest.mocked(useWebhookEndpoint).mockReturnValue({
        webhook: undefined,
        loading: false,
        refetch: jest.fn(),
      })
    })

    describe('WHEN the component mounts', () => {
      it('THEN should close the developer panel', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        expect(mockClosePanel).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the form is in create mode', () => {
    beforeEach(() => {
      jest.mocked(useWebhookEndpoint).mockReturnValue({
        webhook: undefined,
        loading: false,
        refetch: jest.fn(),
      })
    })

    describe('WHEN user fills the form and submits successfully', () => {
      it('THEN should call createWebhook mutation and show success toast', async () => {
        const user = userEvent.setup()

        mockCreateWebhook.mockResolvedValue({
          data: { createWebhookEndpoint: { id: 'new-webhook' } },
          errors: undefined,
        })

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        // Fill in the URL field (required)
        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        await user.type(urlInput, 'https://example.com/webhook')

        // Submit the form
        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockCreateWebhook).toHaveBeenCalledWith({
            variables: {
              input: expect.objectContaining({
                webhookUrl: 'https://example.com/webhook',
                signatureAlgo: WebhookEndpointSignatureAlgoEnum.Hmac,
              }),
            },
          })
        })

        expect(mockAddToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN mutation returns UrlIsInvalid error', () => {
      it('THEN should not show success toast', async () => {
        const user = userEvent.setup()

        mockCreateWebhook.mockResolvedValue({
          data: null,
          errors: [{ message: 'UrlIsInvalid' }],
        })
        mockHasDefinedGQLError.mockImplementation(
          (errorType: string) => errorType === 'UrlIsInvalid',
        )

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        await user.type(urlInput, 'invalid-url')

        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockCreateWebhook).toHaveBeenCalled()
        })

        // Should not show success toast on error
        expect(mockAddToast).not.toHaveBeenCalledWith(
          expect.objectContaining({ severity: 'success' }),
        )
      })
    })

    describe('WHEN mutation returns ValueAlreadyExist error', () => {
      it('THEN should not show success toast', async () => {
        const user = userEvent.setup()

        mockCreateWebhook.mockResolvedValue({
          data: null,
          errors: [{ message: 'ValueAlreadyExist' }],
        })
        mockHasDefinedGQLError.mockImplementation(
          (errorType: string) => errorType === 'ValueAlreadyExist',
        )

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        await user.type(urlInput, 'https://example.com/existing-webhook')

        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockCreateWebhook).toHaveBeenCalled()
        })

        // Should not show success toast on error
        expect(mockAddToast).not.toHaveBeenCalledWith(
          expect.objectContaining({ severity: 'success' }),
        )
      })
    })

    describe('WHEN mutation returns generic error', () => {
      it('THEN should show danger toast', async () => {
        const user = userEvent.setup()

        mockCreateWebhook.mockResolvedValue({ data: null, errors: [{ message: 'Unknown error' }] })

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        await user.type(urlInput, 'https://example.com/webhook')

        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'danger' }))
        })
      })
    })

    describe('WHEN user selects JWT signature algorithm', () => {
      it('THEN should submit with JWT algorithm', async () => {
        const user = userEvent.setup()

        mockCreateWebhook.mockResolvedValue({
          data: { createWebhookEndpoint: { id: 'new-webhook' } },
          errors: undefined,
        })

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        // Fill in the URL
        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        await user.type(urlInput, 'https://example.com/webhook')

        // Select JWT radio button by finding the radio input with value="jwt"
        const jwtRadioInput = document.querySelector(
          'input[type="radio"][value="jwt"]',
        ) as HTMLInputElement

        await user.click(jwtRadioInput)

        // Submit
        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockCreateWebhook).toHaveBeenCalledWith({
            variables: {
              input: expect.objectContaining({
                signatureAlgo: WebhookEndpointSignatureAlgoEnum.Jwt,
              }),
            },
          })
        })
      })
    })

    describe('WHEN user fills in the name field', () => {
      it('THEN should submit with the name', async () => {
        const user = userEvent.setup()

        mockCreateWebhook.mockResolvedValue({
          data: { createWebhookEndpoint: { id: 'new-webhook' } },
          errors: undefined,
        })

        await act(async () => {
          renderWithParams(<WebhookForm />)
        })

        // Fill in name
        const nameInputContainer = screen.getByTestId(WEBHOOK_FORM_NAME_INPUT_TEST_ID)
        const nameInput = nameInputContainer.querySelector('input') as HTMLInputElement

        await user.type(nameInput, 'My Custom Webhook')

        // Fill in URL
        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        await user.type(urlInput, 'https://example.com/webhook')

        // Submit
        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockCreateWebhook).toHaveBeenCalledWith({
            variables: {
              input: expect.objectContaining({
                name: 'My Custom Webhook',
              }),
            },
          })
        })
      })
    })
  })

  describe('GIVEN the form is in edit mode with existing webhook data', () => {
    beforeEach(() => {
      jest.mocked(useWebhookEndpoint).mockReturnValue({
        webhook: mockWebhookEndpointData,
        loading: false,
        refetch: jest.fn(),
      })
    })

    describe('WHEN user updates the webhook and submits', () => {
      it('THEN should call updateWebhook mutation with the webhook ID', async () => {
        const user = userEvent.setup()

        mockUpdateWebhook.mockResolvedValue({
          data: { updateWebhookEndpoint: { id: 'webhook-123' } },
          errors: undefined,
        })

        await act(async () => {
          renderWithParams(<WebhookForm />, { webhookId: 'webhook-123' })
        })

        // Update the URL field
        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        await user.clear(urlInput)
        await user.type(urlInput, 'https://updated.com/webhook')

        // Submit
        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockUpdateWebhook).toHaveBeenCalledWith({
            variables: {
              input: expect.objectContaining({
                id: 'webhook-123',
                webhookUrl: 'https://updated.com/webhook',
              }),
            },
          })
        })
      })
    })

    describe('WHEN update mutation succeeds', () => {
      it('THEN should show success toast and close the form', async () => {
        const user = userEvent.setup()

        mockUpdateWebhook.mockResolvedValue({
          data: { updateWebhookEndpoint: { id: 'webhook-123' } },
          errors: undefined,
        })

        await act(async () => {
          renderWithParams(<WebhookForm />, { webhookId: 'webhook-123' })
        })

        const submitButton = screen.getByTestId(WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalledWith(
            expect.objectContaining({ severity: 'success' }),
          )
        })

        expect(mockGoBack).toHaveBeenCalled()
        expect(mockOpenPanel).toHaveBeenCalled()
      })
    })

    describe('WHEN the form renders with pre-populated data', () => {
      it('THEN should display the existing webhook name in the input', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />, { webhookId: 'webhook-123' })
        })

        const nameInputContainer = screen.getByTestId(WEBHOOK_FORM_NAME_INPUT_TEST_ID)
        const nameInput = nameInputContainer.querySelector('input') as HTMLInputElement

        expect(nameInput).toHaveValue('My Webhook')
      })

      it('THEN should display the existing webhook URL in the input', async () => {
        await act(async () => {
          renderWithParams(<WebhookForm />, { webhookId: 'webhook-123' })
        })

        const urlInputContainer = screen.getByTestId(WEBHOOK_FORM_URL_INPUT_TEST_ID)
        const urlInput = urlInputContainer.querySelector('input') as HTMLInputElement

        expect(urlInput).toHaveValue('https://example.com/webhook')
      })
    })
  })
})
