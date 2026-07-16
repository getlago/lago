import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { addToast } from '~/core/apolloClient'
import { CurrencyEnum, OrderTypeEnum, StatusEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import { useQuote } from '../hooks/useQuote'
import VoidQuote, {
  VOID_QUOTE_ALERT_TEST_ID,
  VOID_QUOTE_CANCEL_BUTTON_TEST_ID,
  VOID_QUOTE_CLOSE_BUTTON_TEST_ID,
  VOID_QUOTE_PREVIEW_TEST_ID,
  VOID_QUOTE_VOID_AND_GENERATE_BUTTON_TEST_ID,
  VOID_QUOTE_VOID_BUTTON_TEST_ID,
} from '../VoidQuote'

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

const mockHasPermissions = jest.fn()

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('../hooks/useQuote', () => ({
  useQuote: jest.fn(),
}))

const mockVoidQuote = jest.fn()
const mockCloneQuote = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useVoidQuoteVersionMutation: () => [mockVoidQuote],
  useCloneQuoteVersionMutation: () => [mockCloneQuote],
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

const mockUseQuote = useQuote as jest.MockedFunction<typeof useQuote>

const mockQuote = {
  id: 'quote-123',
  number: 'QT-2026-0042',
  images: {},
  orderType: OrderTypeEnum.SubscriptionCreation,
  createdAt: '2026-04-09T10:00:00Z',
  versions: [
    { id: 'version-123', status: StatusEnum.Draft, version: 2, createdAt: '2026-04-09T10:00:00Z' },
  ],
  currentVersion: {
    id: 'version-123',
    status: StatusEnum.Draft,
    version: 2,
    content: '<p>Quote body</p>',
    currency: null,
    startDate: null,
    endDate: null,
    billingItems: {},
    createdAt: '2026-04-09T10:00:00Z',
    mentionVariables: {},
  },
  customer: {
    id: 'customer-001',
    name: 'Acme',
    displayName: 'Acme',
    externalId: 'ext-acme-001',
    netPaymentTerm: null,
    billingConfiguration: { documentLocale: 'en' },
    currency: CurrencyEnum.Usd,
    billingEntity: {
      __typename: 'BillingEntity' as const,
      id: 'be-1',
      code: 'default',
      name: 'Default Entity',
      netPaymentTerm: 0,
    },
  },
}

describe('VoidQuote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedRichTextEditorProps = {}
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ quoteId: 'quote-123' })

    mockUseQuote.mockReturnValue({
      quote: mockQuote,
      loading: false,
      error: undefined,
      refetch: jest.fn(),
    })

    mockHasPermissions.mockReturnValue(true)
  })

  describe('GIVEN the page is rendered with a quote', () => {
    describe('WHEN in default state', () => {
      it('THEN should display the warning alert', () => {
        render(<VoidQuote />)

        expect(screen.getByTestId(VOID_QUOTE_ALERT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the void button', () => {
        render(<VoidQuote />)

        expect(screen.getByTestId(VOID_QUOTE_VOID_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the cancel button', () => {
        render(<VoidQuote />)

        expect(screen.getByTestId(VOID_QUOTE_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the close button', () => {
        render(<VoidQuote />)

        expect(screen.getByTestId(VOID_QUOTE_CLOSE_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN user has void and clone permissions', () => {
      it('THEN should display the void and generate new version button', () => {
        render(<VoidQuote />)

        expect(screen.getByTestId(VOID_QUOTE_VOID_AND_GENERATE_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN user does not have both void and clone permissions', () => {
      it('THEN should not display the void and generate new version button', () => {
        mockHasPermissions.mockReturnValue(false)

        render(<VoidQuote />)

        expect(
          screen.queryByTestId(VOID_QUOTE_VOID_AND_GENERATE_BUTTON_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the void action', () => {
    describe('WHEN the void button is clicked and mutation succeeds', () => {
      it('THEN should call voidQuote mutation with correct variables', async () => {
        mockVoidQuote.mockResolvedValueOnce({
          data: { voidQuoteVersion: { id: 'quote-123', status: StatusEnum.Voided } },
        })

        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_VOID_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockVoidQuote).toHaveBeenCalledWith({
            variables: {
              input: {
                id: 'version-123',
              },
            },
          })
        })
      })

      it('THEN should show success toast and navigate to quote details', async () => {
        mockVoidQuote.mockResolvedValueOnce({
          data: { voidQuoteVersion: { id: 'quote-123', status: StatusEnum.Voided } },
        })

        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_VOID_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
        })

        expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-123/overview')
      })
    })
  })

  describe('GIVEN the void and generate new version action', () => {
    describe('WHEN the button is clicked and both mutations succeed', () => {
      it('THEN should call voidQuote then cloneQuote and navigate to edit', async () => {
        mockVoidQuote.mockResolvedValueOnce({
          data: { voidQuoteVersion: { id: 'quote-123', status: StatusEnum.Voided } },
        })
        mockCloneQuote.mockResolvedValueOnce({
          data: { cloneQuoteVersion: { id: 'new-version-456', quote: { id: 'new-quote-456' } } },
        })

        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_VOID_AND_GENERATE_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockVoidQuote).toHaveBeenCalledWith({
            variables: {
              input: {
                id: 'version-123',
              },
            },
          })
        })

        await waitFor(() => {
          expect(mockCloneQuote).toHaveBeenCalledWith({
            variables: { input: { id: 'version-123' } },
          })
        })

        expect(testMockNavigateFn).toHaveBeenCalledWith(
          '/quote/new-quote-456/version/new-version-456/edit',
        )
      })
    })
  })

  describe('GIVEN the close action', () => {
    describe('WHEN the close button is clicked', () => {
      it('THEN should call goBack with quote details path', async () => {
        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_CLOSE_BUTTON_TEST_ID))

        expect(mockGoBack).toHaveBeenCalledWith('/quote/quote-123/overview')
      })
    })

    describe('WHEN the cancel button is clicked', () => {
      it('THEN should call goBack with quote details path', async () => {
        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_CANCEL_BUTTON_TEST_ID))

        expect(mockGoBack).toHaveBeenCalledWith('/quote/quote-123/overview')
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    describe('WHEN data is being fetched', () => {
      it('THEN should not display the alert or footer buttons', () => {
        mockUseQuote.mockReturnValue({
          quote: undefined,
          loading: true,
          error: undefined,
          refetch: jest.fn(),
        })

        render(<VoidQuote />)

        expect(screen.queryByTestId(VOID_QUOTE_ALERT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an error occurred', () => {
    describe('WHEN the error is displayed', () => {
      it('THEN should not show the void form', () => {
        mockUseQuote.mockReturnValue({
          quote: undefined,
          loading: false,
          error: new Error('Something went wrong') as never,
          refetch: jest.fn(),
        })

        render(<VoidQuote />)

        expect(screen.queryByTestId(VOID_QUOTE_VOID_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no quoteId param', () => {
    beforeEach(() => {
      const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

      useParamsMock.mockReturnValue({})
    })

    describe('WHEN the void button is clicked', () => {
      it('THEN should not call voidQuote mutation', async () => {
        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_VOID_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockVoidQuote).not.toHaveBeenCalled()
        })
      })
    })

    describe('WHEN the close button is clicked', () => {
      it('THEN should not call goBack', async () => {
        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_CLOSE_BUTTON_TEST_ID))

        expect(mockGoBack).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the void mutation returns no data', () => {
    describe('WHEN the void button is clicked', () => {
      it('THEN should not show success toast or navigate', async () => {
        mockVoidQuote.mockResolvedValueOnce({ data: { voidQuoteVersion: null } })

        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_VOID_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockVoidQuote).toHaveBeenCalled()
        })

        expect(addToast).not.toHaveBeenCalled()
        expect(testMockNavigateFn).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the void and generate action with partial failure', () => {
    describe('WHEN void succeeds but clone returns no data', () => {
      it('THEN should not navigate to edit page', async () => {
        mockVoidQuote.mockResolvedValueOnce({
          data: { voidQuoteVersion: { id: 'quote-123', status: StatusEnum.Voided } },
        })
        mockCloneQuote.mockResolvedValueOnce({ data: { cloneQuoteVersion: null } })

        const user = userEvent.setup()

        render(<VoidQuote />)

        await user.click(screen.getByTestId(VOID_QUOTE_VOID_AND_GENERATE_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockCloneQuote).toHaveBeenCalled()
        })

        expect(testMockNavigateFn).not.toHaveBeenCalledWith(expect.stringContaining('/edit'))
      })
    })
  })

  describe('GIVEN a quote with content', () => {
    it('THEN renders the side RTE preview', () => {
      render(<VoidQuote />)

      const preview = screen.getByTestId(VOID_QUOTE_PREVIEW_TEST_ID)

      expect(preview).toBeInTheDocument()
      expect(within(preview).getByTestId('rich-text-editor')).toBeInTheDocument()
      expect(capturedRichTextEditorProps.mode).toBe('preview')
    })
  })

  describe('GIVEN a quote without content', () => {
    it('THEN renders the empty placeholder instead of the editor', () => {
      mockUseQuote.mockReturnValue({
        quote: { ...mockQuote, currentVersion: { ...mockQuote.currentVersion, content: '' } },
        loading: false,
        error: undefined,
      } as unknown as ReturnType<typeof useQuote>)

      render(<VoidQuote />)

      const preview = screen.getByTestId(VOID_QUOTE_PREVIEW_TEST_ID)

      expect(within(preview).queryByTestId('rich-text-editor')).not.toBeInTheDocument()
    })
  })
})
