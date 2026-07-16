import { fireEvent, screen } from '@testing-library/react'

import {
  CurrencyEnum,
  OrderTypeEnum,
  QuoteDetailItemFragment,
  StatusEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import EditQuoteAside, {
  EDIT_QUOTE_ASIDE_APPROVE_TEST_ID,
  EDIT_QUOTE_ASIDE_BILLING_ENTITY_INPUT_TEST_ID,
  EDIT_QUOTE_ASIDE_CURRENCY_INPUT_TEST_ID,
  EDIT_QUOTE_ASIDE_CUSTOMER_INPUT_TEST_ID,
  EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID,
  EDIT_QUOTE_ASIDE_END_DATE_TEST_ID,
  EDIT_QUOTE_ASIDE_PAYMENT_TERM_TEST_ID,
  EDIT_QUOTE_ASIDE_QUOTE_TYPE_COMBOBOX_TEST_ID,
  EDIT_QUOTE_ASIDE_START_DATE_TEST_ID,
  EDIT_QUOTE_ASIDE_SUBSCRIPTION_INPUT_TEST_ID,
} from '../EditQuoteAside'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, params?: Record<string, unknown>) => {
      if (key === 'text_64c7a89b6c67eb6c98898125') return '0 days (at issuing date)'
      if (key === 'text_64c7a89b6c67eb6c9889815f' && params?.days)
        return `${params.days} day${Number(params.days) !== 1 ? 's' : ''}`
      if (key === 'text_17818008544903clzyy4ziu1' && params?.quoteNumberWithVersion)
        return `Quote #${params.quoteNumberWithVersion}`

      return key
    },
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
}))

jest.mock('~/pages/quotes/hooks/useUpdateQuote', () => ({
  useUpdateQuote: () => ({
    updateQuoteVersion: jest.fn(),
    isUpdatingQuoteVersion: false,
    updateQuote: jest.fn(),
    isUpdatingQuote: false,
  }),
}))

const mockDownload = jest.fn().mockResolvedValue(undefined)
const mockGoToApproveQuote = jest.fn()
const mockHasPermissions = jest.fn().mockReturnValue(true)

jest.mock('~/pages/quotes/common/QuotePdfProvider', () => ({
  useDownloadQuotePdf: () => ({ download: mockDownload }),
}))

jest.mock('~/pages/quotes/hooks/useApproveQuote', () => ({
  useApproveQuote: () => ({ goToApproveQuote: mockGoToApproveQuote }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

const mockQuote: QuoteDetailItemFragment = {
  __typename: 'Quote',
  id: 'quote-1',
  number: 'Q-001',
  images: {},
  orderType: OrderTypeEnum.SubscriptionCreation,
  createdAt: '2026-01-01',
  versions: [
    {
      __typename: 'QuoteVersion',
      id: 'version-1',
      status: StatusEnum.Draft,
      version: 1,
      createdAt: '2026-01-01',
    },
  ],
  customer: {
    __typename: 'Customer',
    id: 'customer-1',
    displayName: 'Acme Corp',
    externalId: 'ext-cust-1',
    netPaymentTerm: 30,
    billingEntity: {
      __typename: 'BillingEntity',
      id: 'be-1',
      code: 'default',
      name: 'Default Entity',
      netPaymentTerm: 60,
    },
  },
  owners: [],
  subscription: null,
  currentVersion: {
    __typename: 'QuoteVersion',
    id: 'version-1',
    status: StatusEnum.Draft,
    version: 1,
    content: 'Some content',
    currency: null,
    startDate: null,
    endDate: null,
    billingItems: null,
    createdAt: '2026-01-01',
    mentionVariables: {},
  },
}

describe('EditQuoteAside', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
  })

  describe('GIVEN a quote is provided', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the quote type field', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_QUOTE_TYPE_COMBOBOX_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the customer field', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_CUSTOMER_INPUT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the billing entity field', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(
          screen.getByTestId(EDIT_QUOTE_ASIDE_BILLING_ENTITY_INPUT_TEST_ID),
        ).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with no billing entity', () => {
    describe('WHEN the component renders', () => {
      it('THEN should NOT render the billing entity field', () => {
        const quoteWithoutBillingEntity = {
          ...mockQuote,
          customer: { ...mockQuote.customer, billingEntity: null },
        } as unknown as QuoteDetailItemFragment

        render(<EditQuoteAside quote={quoteWithoutBillingEntity} />)

        expect(
          screen.queryByTestId(EDIT_QUOTE_ASIDE_BILLING_ENTITY_INPUT_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with no subscription', () => {
    describe('WHEN the component renders', () => {
      it('THEN should NOT render the subscription field', () => {
        render(<EditQuoteAside quote={{ ...mockQuote, subscription: null }} />)

        expect(
          screen.queryByTestId(EDIT_QUOTE_ASIDE_SUBSCRIPTION_INPUT_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with a subscription', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the subscription field', () => {
        const quoteWithSubscription = {
          ...mockQuote,
          subscription: {
            __typename: 'Subscription' as const,
            id: 'sub-1',
            name: 'My Subscription',
            externalId: 'ext-sub-1',
            subscriptionAt: '2026-03-15T00:00:00Z',
            plan: {
              __typename: 'Plan' as const,
              id: 'plan-1',
              name: 'Premium Plan',
            },
          },
        }

        render(<EditQuoteAside quote={quoteWithSubscription} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_SUBSCRIPTION_INPUT_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no quote is provided', () => {
    describe('WHEN the component renders', () => {
      it('THEN should not render any fields', () => {
        render(<EditQuoteAside quote={undefined} />)

        expect(
          screen.queryByTestId(EDIT_QUOTE_ASIDE_QUOTE_TYPE_COMBOBOX_TEST_ID),
        ).not.toBeInTheDocument()
        expect(
          screen.queryByTestId(EDIT_QUOTE_ASIDE_CUSTOMER_INPUT_TEST_ID),
        ).not.toBeInTheDocument()
        expect(
          screen.queryByTestId(EDIT_QUOTE_ASIDE_BILLING_ENTITY_INPUT_TEST_ID),
        ).not.toBeInTheDocument()
        expect(
          screen.queryByTestId(EDIT_QUOTE_ASIDE_SUBSCRIPTION_INPUT_TEST_ID),
        ).not.toBeInTheDocument()
        expect(
          screen.queryByTestId(EDIT_QUOTE_ASIDE_CURRENCY_INPUT_TEST_ID),
        ).not.toBeInTheDocument()
        expect(screen.queryByTestId(EDIT_QUOTE_ASIDE_START_DATE_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(EDIT_QUOTE_ASIDE_END_DATE_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(EDIT_QUOTE_ASIDE_PAYMENT_TERM_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with customer currency', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the currency field', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_CURRENCY_INPUT_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a subscription quote with dates and payment term', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the start date field', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_START_DATE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the end date field', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_END_DATE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the payment term field', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_PAYMENT_TERM_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a one-off quote', () => {
    const oneOffQuote = {
      ...mockQuote,
      orderType: OrderTypeEnum.OneOff,
    }

    describe('WHEN the component renders', () => {
      it('THEN should NOT render the start date field', () => {
        render(<EditQuoteAside quote={oneOffQuote} />)

        expect(screen.queryByTestId(EDIT_QUOTE_ASIDE_START_DATE_TEST_ID)).not.toBeInTheDocument()
      })

      it('THEN should NOT render the end date field', () => {
        render(<EditQuoteAside quote={oneOffQuote} />)

        expect(screen.queryByTestId(EDIT_QUOTE_ASIDE_END_DATE_TEST_ID)).not.toBeInTheDocument()
      })

      it('THEN should still render the payment term field', () => {
        render(<EditQuoteAside quote={oneOffQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_PAYMENT_TERM_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with netPaymentTerm of 0', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display "0 days (at issuing date)"', () => {
        const quoteWithZeroTerm = {
          ...mockQuote,
          customer: { ...mockQuote.customer, netPaymentTerm: 0 },
        }

        render(<EditQuoteAside quote={quoteWithZeroTerm} />)

        expect(screen.getByDisplayValue('0 days (at issuing date)')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with null customer netPaymentTerm', () => {
    describe('WHEN the billing entity has a netPaymentTerm', () => {
      it('THEN should fall back to billing entity netPaymentTerm', () => {
        const quoteWithNullCustomerTerm = {
          ...mockQuote,
          customer: { ...mockQuote.customer, netPaymentTerm: null },
        }

        render(<EditQuoteAside quote={quoteWithNullCustomerTerm} />)

        expect(screen.getByDisplayValue('60 days')).toBeInTheDocument()
      })
    })

    describe('WHEN the billing entity also has no netPaymentTerm', () => {
      it('THEN should display "-"', () => {
        const quoteWithNoTerm = {
          ...mockQuote,
          customer: {
            ...mockQuote.customer,
            netPaymentTerm: null,
            billingEntity: {
              ...mockQuote.customer.billingEntity,
              netPaymentTerm: null,
            },
          },
        } as unknown as QuoteDetailItemFragment

        render(<EditQuoteAside quote={quoteWithNoTerm} />)

        expect(screen.getByDisplayValue('-')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with netPaymentTerm of 1', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display "1 day" (singular)', () => {
        const quoteWithOneDayTerm = {
          ...mockQuote,
          customer: { ...mockQuote.customer, netPaymentTerm: 1 },
        }

        render(<EditQuoteAside quote={quoteWithOneDayTerm} />)

        expect(screen.getByDisplayValue('1 day')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote where customer has no currency but currentVersion does', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the currency field using currentVersion currency', () => {
        const quoteWithVersionCurrency = {
          ...mockQuote,
          customer: { ...mockQuote.customer, currency: null },
          currentVersion: { ...mockQuote.currentVersion, currency: CurrencyEnum.Eur },
        }

        render(<EditQuoteAside quote={quoteWithVersionCurrency} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_CURRENCY_INPUT_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote where customer has a currency set', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the currency field using customer currency', () => {
        const quoteWithCustomerCurrency = {
          ...mockQuote,
          customer: { ...mockQuote.customer, currency: CurrencyEnum.Eur },
        }

        render(<EditQuoteAside quote={quoteWithCustomerCurrency} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_CURRENCY_INPUT_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a quote with a subscription that has a plan', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the subscription label as "planName - externalId"', () => {
        const quoteWithSubscription = {
          ...mockQuote,
          subscription: {
            __typename: 'Subscription' as const,
            id: 'sub-1',
            name: 'My Subscription',
            externalId: 'ext-sub-1',
            subscriptionAt: '2026-03-15T00:00:00Z',
            plan: {
              __typename: 'Plan' as const,
              id: 'plan-1',
              name: 'Premium Plan',
            },
          },
        }

        render(<EditQuoteAside quote={quoteWithSubscription} />)

        expect(screen.getByDisplayValue('Premium Plan - ext-sub-1')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a subscription amendment quote', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the start date field', () => {
        const amendmentQuote = {
          ...mockQuote,
          orderType: OrderTypeEnum.SubscriptionAmendment,
        }

        render(<EditQuoteAside quote={amendmentQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_START_DATE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the end date field', () => {
        const amendmentQuote = {
          ...mockQuote,
          orderType: OrderTypeEnum.SubscriptionAmendment,
        }

        render(<EditQuoteAside quote={amendmentQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_END_DATE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the footer actions', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the Download PDF button', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should still render the Download PDF button without the quotesApprove permission', () => {
        mockHasPermissions.mockReturnValue(false)
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the Approve button when the user has the quotesApprove permission', () => {
        mockHasPermissions.mockReturnValue(true)
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_APPROVE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should NOT render the Approve button without the quotesApprove permission', () => {
        mockHasPermissions.mockReturnValue(false)
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.queryByTestId(EDIT_QUOTE_ASIDE_APPROVE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the Download PDF button is clicked', () => {
      it('THEN should trigger a PDF download', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        fireEvent.click(screen.getByTestId(EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID))

        expect(mockDownload).toHaveBeenCalledTimes(1)
      })

      it('THEN should build the PDF header from the quote number and version', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        fireEvent.click(screen.getByTestId(EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID))

        expect(mockDownload).toHaveBeenCalledWith(
          expect.objectContaining({
            header: expect.objectContaining({
              documentNumber: 'Q-001',
              rows: ['Quote #Q-001 - v1'],
            }),
          }),
        )
      })
    })

    describe('WHEN the Approve button is clicked', () => {
      it('THEN should navigate to the approve quote page', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        fireEvent.click(screen.getByTestId(EDIT_QUOTE_ASIDE_APPROVE_TEST_ID))

        expect(mockGoToApproveQuote).toHaveBeenCalledWith('quote-1', 'version-1')
      })
    })

    describe('WHEN the quote is saving', () => {
      it('THEN should disable both action buttons and show loading spinners', () => {
        render(<EditQuoteAside quote={mockQuote} isSaving />)

        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID)).toBeDisabled()
        expect(screen.getByTestId(EDIT_QUOTE_ASIDE_APPROVE_TEST_ID)).toBeDisabled()
        expect(screen.getAllByTestId(/processing/)).toHaveLength(2)
      })

      it('THEN should not trigger a PDF download while saving', () => {
        render(<EditQuoteAside quote={mockQuote} isSaving />)

        fireEvent.click(screen.getByTestId(EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID))

        expect(mockDownload).not.toHaveBeenCalled()
      })

      it('THEN should not navigate to approve while saving', () => {
        render(<EditQuoteAside quote={mockQuote} isSaving />)

        fireEvent.click(screen.getByTestId(EDIT_QUOTE_ASIDE_APPROVE_TEST_ID))

        expect(mockGoToApproveQuote).not.toHaveBeenCalled()
      })
    })

    describe('WHEN the quote is NOT saving', () => {
      it('THEN should not show any loading spinners', () => {
        render(<EditQuoteAside quote={mockQuote} />)

        expect(screen.queryAllByTestId(/processing/)).toHaveLength(0)
      })
    })
  })
})
