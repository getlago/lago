import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { buildPreviewEntities } from '~/core/serializers/serializeQuoteBillingItems'
import { OrderTypeEnum, StatusEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import { useQuotePreviewVersion } from '../hooks/useQuotePreviewVersion'
import QuoteVersionPreview, {
  QUOTE_VERSION_PREVIEW_CARD_TEST_ID,
  QUOTE_VERSION_PREVIEW_CLOSE_BUTTON_TEST_ID,
  QUOTE_VERSION_PREVIEW_DESCRIPTION_TEST_ID,
} from '../QuoteVersionPreview'

const mockGoBack = jest.fn()

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({ goBack: mockGoBack }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, vars?: Record<string, unknown>) =>
      vars ? `${key}:${JSON.stringify(vars)}` : key,
  }),
}))

jest.mock('~/components/designSystem/RichTextEditor/RichTextEditor', () => ({
  __esModule: true,
  default: (props: Record<string, unknown>) => (
    <div data-test="rich-text-editor-preview">{props.content as string}</div>
  ),
}))

jest.mock('../hooks/useQuotePreviewVersion', () => ({
  useQuotePreviewVersion: jest.fn(),
}))

jest.mock('~/core/serializers/serializeQuoteBillingItems', () => ({
  buildPreviewEntities: jest.fn(),
}))

const mockUseQuotePreviewVersion = useQuotePreviewVersion as jest.MockedFunction<
  typeof useQuotePreviewVersion
>
const mockedBuildPreviewEntities = buildPreviewEntities as jest.MockedFunction<
  typeof buildPreviewEntities
>

const approvedVersion = {
  id: 'version-v1',
  status: StatusEnum.Approved,
  version: 1,
  content: '<p>Approved content</p>',
  billingItems: null,
  mentionVariables: {},
}

const draftVersion = {
  id: 'version-v2',
  status: StatusEnum.Draft,
  version: 2,
  content: null,
  billingItems: null,
  mentionVariables: {},
}

const mockQuote = {
  id: 'quote-123',
  number: 'QT-2026-0042',
  images: {},
  orderType: OrderTypeEnum.SubscriptionCreation,
  customer: {
    id: 'customer-001',
    displayName: 'Acme Corp',
    currency: null,
    billingConfiguration: { documentLocale: null },
  },
  versions: [draftVersion, approvedVersion],
}

const renderPage = (params: { quoteId: string; versionId: string }) =>
  render(<QuoteVersionPreview />, { useParams: params })

describe('QuoteVersionPreview', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockedBuildPreviewEntities.mockReturnValue({})
    mockUseQuotePreviewVersion.mockReturnValue({
      quote: mockQuote,
      loading: false,
      error: undefined,
    })
  })

  describe('GIVEN a non-draft version is targeted', () => {
    describe('WHEN the page renders', () => {
      it('THEN should show the description, info, and preview of that version', () => {
        renderPage({ quoteId: 'quote-123', versionId: 'version-v1' })

        expect(screen.getByTestId(QUOTE_VERSION_PREVIEW_DESCRIPTION_TEST_ID)).toBeInTheDocument()
        expect(screen.getByText('Acme Corp')).toBeInTheDocument()
        expect(screen.getByTestId(QUOTE_VERSION_PREVIEW_CARD_TEST_ID)).toHaveTextContent(
          'Approved content',
        )
      })
    })

    describe('WHEN the close button is clicked', () => {
      it('THEN should goBack to the quote details overview tab', async () => {
        const user = userEvent.setup()

        renderPage({ quoteId: 'quote-123', versionId: 'version-v1' })

        await user.click(screen.getByTestId(QUOTE_VERSION_PREVIEW_CLOSE_BUTTON_TEST_ID))

        expect(mockGoBack).toHaveBeenCalledWith('/quote/quote-123/overview')
      })
    })
  })

  describe('GIVEN the targeted version is a Draft', () => {
    describe('WHEN the page renders', () => {
      it('THEN should redirect to the edit route', () => {
        renderPage({ quoteId: 'quote-123', versionId: 'version-v2' })

        expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-123/version/version-v2/edit')
      })
    })
  })

  describe('GIVEN the targeted version does not exist', () => {
    describe('WHEN the page renders', () => {
      it('THEN should redirect to the quote details overview tab', () => {
        renderPage({ quoteId: 'quote-123', versionId: 'does-not-exist' })

        expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-123/overview')
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    describe('WHEN data is being fetched', () => {
      it('THEN should not render the preview content', () => {
        mockUseQuotePreviewVersion.mockReturnValue({
          quote: undefined,
          loading: true,
          error: undefined,
        })

        renderPage({ quoteId: 'quote-123', versionId: 'version-v1' })

        expect(screen.queryByTestId('rich-text-editor-preview')).not.toBeInTheDocument()
        expect(screen.getByTestId(QUOTE_VERSION_PREVIEW_CLOSE_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
