import NiceModal from '@ebay/nice-modal-react'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  CENTRALIZED_DIALOG_TEST_ID,
} from '~/components/dialogs/const'
import { addToast } from '~/core/apolloClient'
import { buildPreviewEntities } from '~/core/serializers/serializeQuoteBillingItems'
import { CurrencyEnum, OrderTypeEnum, StatusEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import ApproveQuote, {
  APPROVE_QUOTE_ALERT_TEST_ID,
  APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID,
  APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID,
  APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID,
  APPROVE_QUOTE_PREVIEW_TEST_ID,
} from '../ApproveQuote'
import { useApproveQuote } from '../hooks/useApproveQuote'
import { useQuote } from '../hooks/useQuote'

NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const renderPage = () =>
  render(
    <NiceModal.Provider>
      <ApproveQuote />
    </NiceModal.Provider>,
  )

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

let capturedRichTextEditorProps: Record<string, unknown> = {}

jest.mock('~/components/designSystem/RichTextEditor/RichTextEditor', () => ({
  __esModule: true,
  default: (props: Record<string, unknown>) => {
    capturedRichTextEditorProps = props

    return <div data-test="rich-text-editor-preview">{props.content as string}</div>
  },
}))

jest.mock('../hooks/useQuote', () => ({
  useQuote: jest.fn(),
}))

const mockApproveQuote = jest.fn()

jest.mock('../hooks/useApproveQuote', () => ({
  useApproveQuote: jest.fn(),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({ date }),
  }),
}))

jest.mock('~/core/serializers/serializeQuoteBillingItems', () => ({
  buildPreviewEntities: jest.fn(),
}))

const mockUseQuote = useQuote as jest.MockedFunction<typeof useQuote>
const mockUseApproveQuote = useApproveQuote as jest.MockedFunction<typeof useApproveQuote>
const mockedBuildPreviewEntities = buildPreviewEntities as jest.MockedFunction<
  typeof buildPreviewEntities
>

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
    content: null,
    currency: null,
    startDate: null,
    endDate: null,
    billingItems: null,
    createdAt: '2026-04-09T10:00:00Z',
    mentionVariables: {},
  },
  customer: {
    id: 'customer-001',
    name: 'Acme Corp',
    displayName: 'Acme Corp',
    externalId: 'ext-acme-001',
    currency: null,
    netPaymentTerm: null,
    billingConfiguration: {
      documentLocale: null,
    },
    billingEntity: {
      __typename: 'BillingEntity' as const,
      id: 'be-1',
      code: 'default',
      name: 'Default Entity',
      netPaymentTerm: 0,
    },
  },
}

describe('ApproveQuote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedRichTextEditorProps = {}
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ quoteId: 'quote-123', versionId: 'version-123' })

    mockUseQuote.mockReturnValue({
      quote: mockQuote,
      loading: false,
      error: undefined,
      refetch: jest.fn(),
    })

    mockUseApproveQuote.mockReturnValue({
      goToApproveQuote: jest.fn(),
      approveQuote: mockApproveQuote.mockResolvedValue({
        data: { approveQuoteVersion: { id: 'version-123', status: StatusEnum.Approved } },
      }),
    })
  })

  describe('GIVEN the page is rendered with a quote', () => {
    describe('WHEN in default state', () => {
      it.each([
        ['alert', APPROVE_QUOTE_ALERT_TEST_ID],
        ['approve button', APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID],
        ['cancel button', APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID],
        ['close button', APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID],
        ['preview section', APPROVE_QUOTE_PREVIEW_TEST_ID],
      ])('THEN should display the %s', (_, testId) => {
        renderPage()

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })

      it('THEN should display the quote number', () => {
        renderPage()

        expect(screen.getByText('QT-2026-0042')).toBeInTheDocument()
      })

      it('THEN should display the customer name', () => {
        renderPage()

        expect(screen.getByText('Acme Corp')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the quote has content', () => {
    describe('WHEN content is present', () => {
      it('THEN should render the rich text editor preview', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: { ...mockQuote.currentVersion, content: '<p>Quote content here</p>' },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        const preview = screen.getByTestId(APPROVE_QUOTE_PREVIEW_TEST_ID)

        expect(preview).toHaveTextContent('Quote content here')
      })
    })

    describe('WHEN content is null', () => {
      it('THEN should show the no content fallback', () => {
        renderPage()

        const preview = screen.getByTestId(APPROVE_QUOTE_PREVIEW_TEST_ID)

        expect(preview).toBeInTheDocument()
        expect(preview.querySelector('[data-test="rich-text-editor-preview"]')).toBeNull()
      })
    })
  })

  describe('GIVEN the approve action', () => {
    describe('WHEN the approve button is clicked and approveQuote succeeds', () => {
      it('THEN should call approveQuote, show success toast, and navigate to order forms tab', async () => {
        const user = userEvent.setup()

        renderPage()

        await user.click(screen.getByTestId(APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockApproveQuote).toHaveBeenCalled()
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
        expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-123/order-forms')
      })
    })
  })

  describe('GIVEN the close action', () => {
    it.each([
      ['close button', APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID],
      ['cancel button', APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID],
    ])(
      'WHEN the %s is clicked THEN should call goBack with quote details path',
      async (_, testId) => {
        const user = userEvent.setup()

        renderPage()

        await user.click(screen.getByTestId(testId))

        expect(mockGoBack).toHaveBeenCalledWith('/quote/quote-123/overview')
      },
    )
  })

  describe('GIVEN the page is loading', () => {
    beforeEach(() => {
      mockUseQuote.mockReturnValue({
        quote: undefined,
        loading: true,
        error: undefined,
        refetch: jest.fn(),
      })
    })

    describe('WHEN data is being fetched', () => {
      it('THEN should not display the alert or RTE content', () => {
        renderPage()

        expect(screen.queryByTestId(APPROVE_QUOTE_ALERT_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId('rich-text-editor-preview')).not.toBeInTheDocument()
      })

      it('THEN should still display the header close button but not the footer buttons', () => {
        renderPage()

        expect(screen.getByTestId(APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an error occurred', () => {
    beforeEach(() => {
      mockUseQuote.mockReturnValue({
        quote: undefined,
        loading: false,
        error: new Error('Something went wrong') as never,
        refetch: jest.fn(),
      })
    })

    describe('WHEN the error is displayed', () => {
      it('THEN should not show the approve page content', () => {
        renderPage()

        expect(screen.queryByTestId(APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(APPROVE_QUOTE_ALERT_TEST_ID)).not.toBeInTheDocument()
      })

      it('THEN should display the error placeholder with a reload button', () => {
        renderPage()

        expect(screen.getByRole('button')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the quote is null after loading', () => {
    describe('WHEN no quote data is returned', () => {
      it('THEN should render the content area with empty order type value', () => {
        mockUseQuote.mockReturnValue({
          quote: undefined,
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(screen.getByTestId(APPROVE_QUOTE_ALERT_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(APPROVE_QUOTE_PREVIEW_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no quoteId param', () => {
    beforeEach(() => {
      const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

      useParamsMock.mockReturnValue({})
    })

    describe('WHEN the approve button is clicked', () => {
      it('THEN should not call approveQuote mutation', async () => {
        const user = userEvent.setup()

        renderPage()

        await user.click(screen.getByTestId(APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockApproveQuote).not.toHaveBeenCalled()
        })
      })
    })

    describe('WHEN the close button is clicked', () => {
      it('THEN should not call goBack', async () => {
        const user = userEvent.setup()

        renderPage()

        await user.click(screen.getByTestId(APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID))

        expect(mockGoBack).not.toHaveBeenCalled()
      })
    })
  })

  it('sends expiresAt at end-of-day when a valid-until date is set', async () => {
    const user = userEvent.setup()

    renderPage()

    await user.type(screen.getByPlaceholderText('text_62cd78ea9bff25e3391b2437'), '12/25/2030')

    await user.click(screen.getByTestId(APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(mockApproveQuote).toHaveBeenCalledWith({
        variables: {
          input: expect.objectContaining({
            id: 'version-123',
            expiresAt: expect.stringContaining('T23:59:59.999'),
          }),
        },
      })
    })
  })

  describe('GIVEN approveQuote returns a falsy value', () => {
    beforeEach(() => {
      mockUseApproveQuote.mockReturnValue({
        goToApproveQuote: jest.fn(),
        approveQuote: mockApproveQuote.mockResolvedValue({
          data: { approveQuoteVersion: null },
        }),
      })
    })

    describe('WHEN the approve button is clicked', () => {
      it('THEN should not show success toast or navigate', async () => {
        const user = userEvent.setup()

        renderPage()

        await user.click(screen.getByTestId(APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockApproveQuote).toHaveBeenCalled()
        })

        expect(addToast).not.toHaveBeenCalled()
        expect(testMockNavigateFn).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the quote has billing items for preview', () => {
    describe('WHEN billingItems and content are present', () => {
      it('THEN should pass deserialized entities to RichTextEditor', () => {
        const mockEntities = {
          'addon-1': {
            entityId: 'addon-1',
            entityType: 'addOn' as const,
            name: 'Setup Fee',
            code: 'setup',
          },
        }

        mockedBuildPreviewEntities.mockReturnValue(mockEntities)

        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: {
              ...mockQuote.currentVersion,
              content: '<p>Test content</p>',
              billingItems: { addons: [{ type: 'addon', id: 'addon-1' }] },
            },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(mockedBuildPreviewEntities).toHaveBeenCalled()
        expect(capturedRichTextEditorProps.entities).toEqual(mockEntities)
      })
    })

    describe('WHEN billingItems is null', () => {
      it('THEN should pass empty entities to RichTextEditor', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: {
              ...mockQuote.currentVersion,
              content: '<p>Content</p>',
              billingItems: null,
            },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(mockedBuildPreviewEntities).not.toHaveBeenCalled()
        expect(capturedRichTextEditorProps.entities).toEqual({})
      })
    })
  })

  describe('GIVEN the customer has a document locale', () => {
    describe('WHEN documentLocale is set to fr', () => {
      it('THEN should pass customerLocale to RichTextEditor', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: {
              ...mockQuote.currentVersion,
              content: '<p>Content</p>',
            },
            customer: {
              ...mockQuote.customer,
              billingConfiguration: { documentLocale: 'fr' },
            },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(capturedRichTextEditorProps.customerLocale).toBe('fr')
      })
    })

    describe('WHEN documentLocale is null', () => {
      it('THEN should default customerLocale to en', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: {
              ...mockQuote.currentVersion,
              content: '<p>Content</p>',
            },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(capturedRichTextEditorProps.customerLocale).toBe('en')
      })
    })
  })

  describe('GIVEN the customer has a currency', () => {
    describe('WHEN currency is set', () => {
      it('THEN should pass customerCurrency to RichTextEditor', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: {
              ...mockQuote.currentVersion,
              content: '<p>Content</p>',
            },
            customer: {
              ...mockQuote.customer,
              currency: CurrencyEnum.Eur,
            },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(capturedRichTextEditorProps.customerCurrency).toBe(CurrencyEnum.Eur)
      })
    })

    describe('WHEN currency is null', () => {
      it('THEN should pass undefined customerCurrency to RichTextEditor', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: {
              ...mockQuote.currentVersion,
              content: '<p>Content</p>',
            },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(capturedRichTextEditorProps.customerCurrency).toBeUndefined()
      })
    })
  })

  describe('GIVEN the RichTextEditor isCompact prop', () => {
    describe('WHEN content is present', () => {
      it('THEN should pass isCompact as true', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            currentVersion: {
              ...mockQuote.currentVersion,
              content: '<p>Content</p>',
            },
          },
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        renderPage()

        expect(capturedRichTextEditorProps.isCompact).toBe(true)
      })
    })
  })

  describe('unsaved-changes guard', () => {
    const typeDate = async (user: ReturnType<typeof userEvent.setup>) => {
      await user.type(screen.getByPlaceholderText('text_62cd78ea9bff25e3391b2437'), '12/25/2030')
    }

    it('navigates back immediately when closing a pristine form', async () => {
      const user = userEvent.setup()

      renderPage()

      await user.click(screen.getByTestId(APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID))

      expect(screen.queryByTestId(CENTRALIZED_DIALOG_TEST_ID)).not.toBeInTheDocument()
      expect(mockGoBack).toHaveBeenCalled()
    })

    it('opens the warning dialog instead of navigating when the form is dirty', async () => {
      const user = userEvent.setup()

      renderPage()

      await typeDate(user)
      await user.click(screen.getByTestId(APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID))

      expect(await screen.findByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
      expect(mockGoBack).not.toHaveBeenCalled()
    })

    it('navigates back when confirming the warning dialog', async () => {
      const user = userEvent.setup()

      renderPage()

      await typeDate(user)
      await user.click(screen.getByTestId(APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID))
      await user.click(await screen.findByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(mockGoBack).toHaveBeenCalled()
      })
    })

    it('stays on the page when cancelling the warning dialog', async () => {
      const user = userEvent.setup()

      renderPage()

      await typeDate(user)
      await user.click(screen.getByTestId(APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID))
      await user.click(await screen.findByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID))

      expect(mockGoBack).not.toHaveBeenCalled()
    })
  })
})
