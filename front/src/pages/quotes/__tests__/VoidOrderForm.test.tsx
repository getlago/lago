import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { addToast } from '~/core/apolloClient'
import { CurrencyEnum, OrderFormStatusEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import VoidOrderForm, {
  VOID_ORDER_FORM_ALERT_TEST_ID,
  VOID_ORDER_FORM_CANCEL_BUTTON_TEST_ID,
  VOID_ORDER_FORM_CLOSE_BUTTON_TEST_ID,
  VOID_ORDER_FORM_PREVIEW_TEST_ID,
  VOID_ORDER_FORM_VOID_BUTTON_TEST_ID,
} from '../VoidOrderForm'

const mockGoBack = jest.fn()

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    goBack: mockGoBack,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, vars?: Record<string, unknown>) => {
      if (vars) return `${key}:${JSON.stringify(vars)}`
      return key
    },
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({
      date: new Date(date).toLocaleDateString('en-US'),
    }),
  }),
}))

const mockVoidOrderForm = jest.fn()
const mockUseGetOrderFormForVoidQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetOrderFormForVoidQuery: (...args: unknown[]) => mockUseGetOrderFormForVoidQuery(...args),
  useVoidOrderFormMutation: () => [mockVoidOrderForm],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

let capturedRichTextEditorProps: Record<string, unknown> = {}

jest.mock('~/components/designSystem/RichTextEditor/RichTextEditor', () => ({
  __esModule: true,
  default: (props: Record<string, unknown>) => {
    capturedRichTextEditorProps = props
    return <div data-test="rich-text-editor" />
  },
}))

jest.mock('~/core/serializers/serializeQuoteBillingItems', () => ({
  buildPreviewEntities: jest.fn(() => ({})),
}))

const mockOrderForm = {
  id: 'order-form-123',
  number: 'OF-2026-0001',
  status: OrderFormStatusEnum.Generated,
  createdAt: '2026-04-09T10:00:00Z',
  customer: {
    id: 'customer-001',
    name: 'Acme Corp',
    billingConfiguration: { documentLocale: 'en' },
    currency: CurrencyEnum.Usd,
  },
  quote: {
    id: 'quote-456',
    number: 'QT-2026-0042',
    currentVersion: {
      version: 2,
      content: '<p>Order form body</p>',
      billingItems: {},
    },
  },
}

describe('VoidOrderForm', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedRichTextEditorProps = {}
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ orderFormId: 'order-form-123' })

    mockUseGetOrderFormForVoidQuery.mockReturnValue({
      data: { orderForm: mockOrderForm },
      loading: false,
      error: undefined,
    })
  })

  describe('GIVEN the page is rendered with an order form', () => {
    describe('WHEN in default state', () => {
      it('THEN should display the warning alert', () => {
        render(<VoidOrderForm />)

        expect(screen.getByTestId(VOID_ORDER_FORM_ALERT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the void button', () => {
        render(<VoidOrderForm />)

        expect(screen.getByTestId(VOID_ORDER_FORM_VOID_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the cancel button', () => {
        render(<VoidOrderForm />)

        expect(screen.getByTestId(VOID_ORDER_FORM_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the close button', () => {
        render(<VoidOrderForm />)

        expect(screen.getByTestId(VOID_ORDER_FORM_CLOSE_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the close action', () => {
    describe('WHEN the close button is clicked', () => {
      it('THEN should call goBack with order forms list fallback', async () => {
        const user = userEvent.setup()

        render(<VoidOrderForm />)

        await user.click(screen.getByTestId(VOID_ORDER_FORM_CLOSE_BUTTON_TEST_ID))

        expect(mockGoBack).toHaveBeenCalledWith('/quotes/order-forms')
      })
    })

    describe('WHEN the cancel button is clicked', () => {
      it('THEN should call goBack with order forms list fallback', async () => {
        const user = userEvent.setup()

        render(<VoidOrderForm />)

        await user.click(screen.getByTestId(VOID_ORDER_FORM_CANCEL_BUTTON_TEST_ID))

        expect(mockGoBack).toHaveBeenCalledWith('/quotes/order-forms')
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    describe('WHEN data is being fetched', () => {
      it('THEN should not display the alert', () => {
        mockUseGetOrderFormForVoidQuery.mockReturnValue({
          data: undefined,
          loading: true,
          error: undefined,
        })

        render(<VoidOrderForm />)

        expect(screen.queryByTestId(VOID_ORDER_FORM_ALERT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an error occurred', () => {
    describe('WHEN the error is displayed', () => {
      it('THEN should not show the void form', () => {
        mockUseGetOrderFormForVoidQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: new Error('Something went wrong'),
        })

        render(<VoidOrderForm />)

        expect(screen.queryByTestId(VOID_ORDER_FORM_VOID_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the void action', () => {
    describe('WHEN the void button is clicked', () => {
      it('THEN should call the void mutation with the order form id', async () => {
        mockVoidOrderForm.mockResolvedValueOnce({
          data: { voidOrderForm: { id: 'order-form-123', status: OrderFormStatusEnum.Voided } },
        })

        const user = userEvent.setup()

        render(<VoidOrderForm />)

        await user.click(screen.getByTestId(VOID_ORDER_FORM_VOID_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockVoidOrderForm).toHaveBeenCalledWith({
            variables: {
              input: {
                id: 'order-form-123',
              },
            },
          })
        })
      })

      it('THEN should show a success toast and navigate to the quote order forms tab', async () => {
        mockVoidOrderForm.mockResolvedValueOnce({
          data: { voidOrderForm: { id: 'order-form-123', status: OrderFormStatusEnum.Voided } },
        })

        const user = userEvent.setup()

        render(<VoidOrderForm />)

        await user.click(screen.getByTestId(VOID_ORDER_FORM_VOID_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
        })

        expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-456/order-forms')
      })
    })
  })

  describe('GIVEN an order form whose quote has content', () => {
    it('THEN renders the side RTE preview', () => {
      render(<VoidOrderForm />)

      const preview = screen.getByTestId(VOID_ORDER_FORM_PREVIEW_TEST_ID)

      expect(within(preview).getByTestId('rich-text-editor')).toBeInTheDocument()
      expect(capturedRichTextEditorProps.mode).toBe('preview')
    })
  })

  describe('GIVEN an order form whose quote has no content', () => {
    it('THEN renders the empty placeholder instead of the editor', () => {
      mockUseGetOrderFormForVoidQuery.mockReturnValue({
        data: {
          orderForm: {
            ...mockOrderForm,
            quote: {
              ...mockOrderForm.quote,
              currentVersion: { ...mockOrderForm.quote.currentVersion, content: '' },
            },
          },
        },
        loading: false,
        error: undefined,
      })

      render(<VoidOrderForm />)

      const preview = screen.getByTestId(VOID_ORDER_FORM_PREVIEW_TEST_ID)

      expect(within(preview).queryByTestId('rich-text-editor')).not.toBeInTheDocument()
    })
  })
})
