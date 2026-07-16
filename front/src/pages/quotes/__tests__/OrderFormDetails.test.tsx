import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { buildPreviewEntities } from '~/core/serializers/serializeQuoteBillingItems'
import { OrderFormStatusEnum, OrderTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { useOrderFormDetails } from '../hooks/useOrderFormDetails'
import OrderFormDetails, {
  ORDER_FORM_DETAILS_ATTACHMENTS_TEST_ID,
  ORDER_FORM_DETAILS_CLOSE_BUTTON_TEST_ID,
  ORDER_FORM_DETAILS_DESCRIPTION_TEST_ID,
  ORDER_FORM_DETAILS_ERROR_TEST_ID,
  ORDER_FORM_DETAILS_PREVIEW_TEST_ID,
} from '../OrderFormDetails'

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

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({
      date: new Date(date).toLocaleDateString('en-US'),
    }),
  }),
}))

jest.mock('~/components/designSystem/RichTextEditor/RichTextEditor', () => ({
  __esModule: true,
  default: (props: Record<string, unknown>) => (
    <div data-test="rich-text-editor-preview">{props.content as string}</div>
  ),
}))

jest.mock('../hooks/useOrderFormDetails', () => ({
  useOrderFormDetails: jest.fn(),
}))

jest.mock('~/core/serializers/serializeQuoteBillingItems', () => ({
  buildPreviewEntities: jest.fn(),
}))

const mockUseOrderFormDetails = useOrderFormDetails as jest.MockedFunction<
  typeof useOrderFormDetails
>
const mockedBuildPreviewEntities = buildPreviewEntities as jest.MockedFunction<
  typeof buildPreviewEntities
>

const baseOrderForm = {
  id: 'of-1',
  number: 'OF-2026-0001',
  status: OrderFormStatusEnum.Signed,
  expiresAt: '2026-06-20T00:00:00Z',
  signedDocumentUrl: 'https://files.example.com/of-1.pdf' as string | null,
  customer: {
    id: 'customer-001',
    displayName: 'Acme Corp',
    currency: null,
    billingConfiguration: { documentLocale: null },
  },
  quote: {
    id: 'quote-1',
    number: 'QUO-001',
    images: {},
    orderType: OrderTypeEnum.SubscriptionCreation,
    currentVersion: {
      id: 'qv-1',
      version: 2,
      content: '<p>Signed content</p>',
      billingItems: null,
      mentionVariables: {},
    },
  },
}

const renderPage = (orderForm = baseOrderForm) => {
  mockUseOrderFormDetails.mockReturnValue({ orderForm, loading: false, error: undefined })

  return render(<OrderFormDetails />, { useParams: { orderFormId: orderForm.id } })
}

describe('OrderFormDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockedBuildPreviewEntities.mockReturnValue({})
  })

  describe('GIVEN a signed order form with a signed document', () => {
    it('THEN shows order form information, the attachment link, and the preview', () => {
      renderPage()

      expect(screen.getByTestId(ORDER_FORM_DETAILS_DESCRIPTION_TEST_ID)).toBeInTheDocument()
      expect(screen.getByText('Acme Corp')).toBeInTheDocument()
      expect(screen.getByText('OF-2026-0001')).toBeInTheDocument()
      expect(screen.getByText('QUO-001 - v2')).toBeInTheDocument()
      expect(screen.getByTestId(ORDER_FORM_DETAILS_ATTACHMENTS_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(ORDER_FORM_DETAILS_PREVIEW_TEST_ID)).toHaveTextContent(
        'Signed content',
      )
    })
  })

  describe('GIVEN an order form without a signed document', () => {
    it('THEN hides the attachments section', () => {
      renderPage({ ...baseOrderForm, signedDocumentUrl: null })

      expect(screen.queryByTestId(ORDER_FORM_DETAILS_ATTACHMENTS_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('WHEN the close button is clicked', () => {
    it('THEN goes back to the order forms tab', async () => {
      const user = userEvent.setup()

      renderPage()

      await user.click(screen.getByTestId(ORDER_FORM_DETAILS_CLOSE_BUTTON_TEST_ID))

      expect(mockGoBack).toHaveBeenCalledWith('/quotes/order-forms')
    })
  })

  describe('GIVEN the query errors', () => {
    it('THEN shows the error placeholder instead of the page', () => {
      mockUseOrderFormDetails.mockReturnValue({
        orderForm: undefined,
        loading: false,
        error: new Error('boom'),
      })

      render(<OrderFormDetails />, { useParams: { orderFormId: 'of-1' } })

      expect(screen.getByTestId(ORDER_FORM_DETAILS_ERROR_TEST_ID)).toBeInTheDocument()
      expect(screen.queryByTestId(ORDER_FORM_DETAILS_DESCRIPTION_TEST_ID)).not.toBeInTheDocument()
      expect(screen.queryByTestId(ORDER_FORM_DETAILS_CLOSE_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('GIVEN the page is loading', () => {
    it('THEN shows the close button but not the order form information yet', () => {
      mockUseOrderFormDetails.mockReturnValue({
        orderForm: undefined,
        loading: true,
        error: undefined,
      })

      render(<OrderFormDetails />, { useParams: { orderFormId: 'of-1' } })

      expect(screen.getByTestId(ORDER_FORM_DETAILS_CLOSE_BUTTON_TEST_ID)).toBeInTheDocument()
      expect(screen.queryByTestId(ORDER_FORM_DETAILS_DESCRIPTION_TEST_ID)).not.toBeInTheDocument()
    })
  })
})
